//! Holds struct definitions for the project
const tracy = @import("tracy.zig");

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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
        const tracy_zone = tracy.trace(@src());
        defer tracy_zone.end();
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
        const tracy_zone = tracy.trace(@src());
        defer tracy_zone.end();
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
