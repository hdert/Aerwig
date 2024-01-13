//! A library for taking in user equations and evaluating them.
//! Must be freed due to hashmap
//! TODO:
//! - Create tests for Tokenizer
//!     - Depends on whether the code ever changes, and whether
//!     the public method testing covers it.
//! - Find way to do performance testing
//! - Merge InfixEquation and PostfixEquation into one Equation struct
//!     - This needs to done to make the code less awkward for the next part
//!     - But does it?
//!     - This has allowed me to keep a stable ABI despite numerous backend changes
//!     - I don't think this is necessary, I can just keep copying data
//!     - Something else needs to be done to organize the code though
//! - Find way to do fuzzing
//!     - Fuzzing doesn't have to include input, but it needs to be both
//!     end-to-end, and unit based to also check function interaction.
//!     - Fuzzing should be 'smart' i.e. checking which code paths have and
//!     haven't been triggered
//!     - Fuzzing should check if non-internal or non-expected errors are thrown
//!     or that asserts have failed or unreachables have been reached.
//!     - Current testing already tests that valid input works, and invalid input
//!     doesn't, we just want to check for UB and crashes.
//! - Find way to do end-to-end testing with custom file reader
//!     - Use result generator and writer to test entire user text
//!     to ensure that it never changes, and if it does, to highlight it
//!     - This will finally include error results and error types
//!     - Integrate this with fuzzing
//!     - Use std.testing.tmpDir
//! - Performance testing

const std = @import("std");
const Stack = @import("Stack");
const Tokenizer = @import("Tokenizer");
pub const InfixEquation = @import("InfixEquation.zig");
pub const PostfixEquation = @import("PostfixEquation.zig");
const Allocator = std.mem.Allocator;

const Self = @This();

allocator: Allocator,
keywords: std.StringHashMap(KeywordInfo),

pub const Error = error{
    InvalidOperator,
    InvalidKeyword,
    DivisionByZero,
    EmptyInput,
    SequentialOperators,
    EndsWithOperator,
    StartsWithOperator,
    ParenEmptyInput,
    ParenStartsWithOperator,
    ParenEndsWithOperator,
    ParenMismatched,
    ParenMismatchedClose,
    ParenMismatchedStart,
    InvalidFloat,
    FnUnexpectedArgSize,
    FnArgBoundsViolated,
    FnArgInvalid,
    Comma,
};

pub fn isError(err: anyerror) bool {
    return switch (err) {
        Error.InvalidOperator,
        Error.InvalidKeyword,
        Error.DivisionByZero,
        Error.EmptyInput,
        Error.SequentialOperators,
        Error.EndsWithOperator,
        Error.StartsWithOperator,
        Error.ParenEmptyInput,
        Error.ParenStartsWithOperator,
        Error.ParenEndsWithOperator,
        Error.ParenMismatched,
        Error.ParenMismatchedClose,
        Error.ParenMismatchedStart,
        Error.InvalidFloat,
        Error.FnUnexpectedArgSize,
        Error.FnArgBoundsViolated,
        Error.FnArgInvalid,
        Error.Comma,
        => true,
        else => false,
    };
}

pub fn errorDescription(err: anyerror) anyerror![]const u8 {
    const E = Error;
    return switch (err) {
        E.InvalidOperator,
        E.Comma,
        => "You have entered an invalid operator\n",
        E.InvalidKeyword => "You have entered an invalid keyword\n",
        E.DivisionByZero => "You cannot divide by zero\n",
        E.EmptyInput => "You cannot have an empty input\n",
        E.SequentialOperators => "You cannot enter sequential operators\n",
        E.EndsWithOperator => "You cannot finish with an operator\n",
        E.StartsWithOperator => "You cannot start with an operator\n",
        E.ParenEmptyInput => "You cannot have an empty parenthesis block\n",
        E.ParenStartsWithOperator => "You cannot start a parentheses block with an operator\n",
        E.ParenEndsWithOperator => "You cannot end a parentheses block with an operator\n",
        E.ParenMismatched,
        E.ParenMismatchedClose,
        E.ParenMismatchedStart,
        => "You have mismatched parentheses!\n",
        E.InvalidFloat => "You have entered an invalid number\n",
        E.FnUnexpectedArgSize => "You haven't passed the correct number of arguments to this function\n",
        E.FnArgBoundsViolated => "Your arguments aren't within the range that this function expected\n",
        E.FnArgInvalid => "Your argument to this function is invalid\n",
        else => return err,
    };
}

pub const Operator = enum(u8) {
    addition = '+',
    subtraction = '-',
    division = '/',
    multiplication = '*',
    exponentiation = '^',
    modulus = '%',
    left_paren = '(',
    right_paren = ')',
    _,

    pub fn precedence(self: @This()) !u8 {
        return switch (self) {
            .left_paren => 1,
            .addition => 2,
            .subtraction => 2,
            .multiplication => 3,
            .division => 3,
            .modulus => 3,
            .exponentiation => 4,
            .right_paren => 5,
            else => Error.InvalidOperator,
        };
    }

    pub fn higherOrEqual(self: @This(), operator: @This()) !bool {
        return try self.precedence() >= try Operator.precedence(operator);
    }
};

pub const KeywordInfo = union(enum) {
    const FunctionInfo = struct {
        arg_length: usize,
        ptr: *const fn ([]f64) anyerror!f64,
    };

    /// Return
    Command: anyerror,
    /// Function
    Function: FunctionInfo,
    /// String
    StrFunction: *const fn ([]const u8) anyerror!f64,
    /// Constant
    Constant: f64,
};

pub fn init(
    allocator: Allocator,
    KeywordRegistrars: ?[]const *const fn (*Self) Allocator.Error!void,
) !Self {
    var self = Self{
        .allocator = allocator,
        .keywords = std.StringHashMap(KeywordInfo).init(allocator),
    };
    if (KeywordRegistrars) |registrars|
        for (registrars) |registrar|
            try registrar(&self);
    try self.registerKeywords();
    return self;
}

pub fn registerKeywords(self: *Self) !void {
    try self.addKeywords(&.{
        "inf",
        "nan",
    }, &.{
        .{ .Constant = std.math.inf(f64) },
        .{ .Constant = std.math.nan(f64) },
    });
}

pub fn addKeywords(self: *Self, keys: []const []const u8, values: []const KeywordInfo) !void {
    for (keys, values) |key, value|
        try self.keywords.put(key, value);
}

pub fn registerPreviousAnswer(self: *Self, prev_ans: f64) !void {
    try self.addKeywords(
        &[_][]const u8{ "a", "ans", "answer" },
        &[_]KeywordInfo{
            .{ .Constant = prev_ans },
            .{ .Constant = prev_ans },
            .{ .Constant = prev_ans },
        },
    );
}

pub fn newInfixEquation(self: Self, input: ?[]const u8, error_handler: anytype) !InfixEquation {
    return InfixEquation.fromString(input, self.allocator, self.keywords, error_handler);
}

pub fn free(self: *Self) void {
    self.keywords.deinit();
}
