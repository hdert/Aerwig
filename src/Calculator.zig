//! A library for taking in user equations and evaluating them.
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
const testing = std.testing;

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

const Operator = enum(u8) {
    const Self = @This();

    addition = '+',
    subtraction = '-',
    division = '/',
    multiplication = '*',
    exponentiation = '^',
    modulus = '%',
    left_paren = '(',
    right_paren = ')',
    _,

    fn precedence(self: Self) !u8 {
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

    fn higherOrEqual(self: Self, operator: Self) !bool {
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

/// Must be freed due to hashmap
pub const Equation = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    keywords: std.StringHashMap(KeywordInfo),

    pub fn init(
        allocator: std.mem.Allocator,
        keys: ?[]const []const u8,
        values: ?[]const KeywordInfo,
    ) !Self {
        var self = Self{
            .allocator = allocator,
            .keywords = std.StringHashMap(KeywordInfo).init(allocator),
        };
        if (keys) |ks|
            for (ks, values.?) |key, value|
                try self.keywords.put(key, value);
        return self;
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
};

pub const InfixEquation = struct {
    const Self = @This();

    data: []const u8,
    // stdout: ?std.fs.File.Writer = null,
    allocator: std.mem.Allocator,
    keywords: std.StringHashMap(KeywordInfo),
    error_info: ?[3]usize = null,

    pub fn fromString(
        input: ?[]const u8,
        allocator: std.mem.Allocator,
        keywords: std.StringHashMap(KeywordInfo),
        error_handler: anytype,
    ) !Self {
        var self = Self{
            .data = undefined,
            .allocator = allocator,
            .keywords = keywords,
        };
        validateInput(&self, input) catch |err| switch (err) {
            Error.DivisionByZero => unreachable,
            else => {
                if (@TypeOf(error_handler) != @TypeOf(null)) {
                    try error_handler.handleError(
                        err,
                        self.error_info,
                        self.data,
                    );
                }
                return err;
            },
        };
        return self;
    }

    pub fn toPostfixEquation(self: Self) !PostfixEquation {
        return PostfixEquation.fromInfixEquation(self);
    }

    /// Evaluate an infix expression.
    /// This chains together a bunch of library functions to do this.
    /// previousAnswer defaults to 0
    /// If InfixEquation has a valid stdout, prints errors to it using printError.
    /// Passes errors back to caller regardless of stdout being defined.
    pub fn evaluate(self: Self) !f64 {
        const postfixEquation = try self.toPostfixEquation();
        defer postfixEquation.free();
        return postfixEquation.evaluate();
    }

    // Private functions

    fn validateKeyword(self: *Self, tokens: *Tokenizer, keyword: []const u8) !void {
        const keywordInfo = self.keywords.get(keyword) orelse return Error.InvalidKeyword;
        var len: ?usize = null;
        var arg_counter: usize = 0;
        switch (keywordInfo) {
            .Command => |err| return err,
            .Function => |info| len = info.arg_length,
            .StrFunction => {},
            .Constant => return,
        }
        const token = tokens.next();
        if (token.tag != .left_paren) {
            self.error_info = .{ token.start, token.end, self.data.len };
            return Error.FnArgInvalid;
        }
        if (len) |l| {
            while (true) : (arg_counter += 1) {
                self.validateArgument(tokens) catch |err| switch (err) {
                    Error.Comma => continue,
                    Error.ParenMismatchedClose => {
                        arg_counter += 1;
                        break;
                    },
                    else => return err,
                };
            }
            if (l > 0 and arg_counter != l)
                return Error.FnUnexpectedArgSize;
        } else {
            while (true) {
                switch (tokens.next().tag) {
                    .right_paren => break,
                    .left_paren => return Error.FnArgInvalid,
                    .eol => return Error.FnUnexpectedArgSize,
                    else => {},
                }
            }
        }
    }

    fn validateArgument(self: *Self, tokens: *Tokenizer) anyerror!void {
        const State = enum {
            float,
            start,
            keyword,
            operator,
            paren,
            minus,
        };
        var state = State.start;
        var paren_counter: isize = 0;
        var old_error_info: ?[3]usize = null;
        while (true) {
            const token = tokens.next();
            self.error_info = .{ token.start, token.end, self.data.len };
            switch (token.tag) {
                .invalid_float => return Error.InvalidFloat,
                .invalid => return Error.InvalidKeyword,
                .eol => switch (state) {
                    .start => return Error.EmptyInput,
                    .operator, .paren, .minus => {
                        self.error_info = old_error_info;
                        return Error.EndsWithOperator;
                    },
                    .float, .keyword => break,
                },
                .comma => switch (state) {
                    .start => return Error.EmptyInput,
                    .operator, .paren, .minus => {
                        self.error_info = old_error_info;
                        return Error.EndsWithOperator;
                    },
                    .float, .keyword => {
                        if (paren_counter > 0) {
                            self.error_info = old_error_info;
                            return Error.ParenMismatched;
                        }
                        return Error.Comma;
                    },
                },
                .operator => switch (state) {
                    .start => return Error.StartsWithOperator,
                    .operator, .minus => return Error.SequentialOperators,
                    .paren => return Error.ParenStartsWithOperator,
                    .float, .keyword => state = .operator,
                },
                .float => state = .float,
                .minus => state = switch (state) {
                    .start, .operator, .paren, .minus => .minus,
                    .float, .keyword => .operator,
                },
                .left_paren => {
                    paren_counter += 1;
                    state = .paren;
                },
                .right_paren => switch (state) {
                    .start => return Error.ParenMismatchedStart,
                    .operator, .minus => {
                        self.error_info = old_error_info;
                        return Error.ParenEndsWithOperator;
                    },
                    .paren => return Error.ParenEmptyInput,
                    .float, .keyword => {
                        paren_counter -= 1;
                        if (paren_counter < 0) {
                            return Error.ParenMismatchedClose;
                        }
                        state = .float;
                    },
                },
                .keyword => {
                    try self.validateKeyword(tokens, token.slice);
                    state = .float;
                },
            }
            old_error_info = .{ token.start, token.end, self.data.len };
        }
        if (paren_counter > 0) {
            self.error_info = old_error_info;
            return Error.ParenMismatched;
        }
    }

    fn validateInput(self: *Self, input: ?[]const u8) !void {
        self.data = input orelse return Error.EmptyInput;
        if (@import("builtin").os.tag == .windows) {
            self.data = std.mem.trimRight(u8, self.data, "\r");
        }
        self.data = std.mem.trim(u8, self.data, " ");
        var tokens = Tokenizer.init(self.data);
        try self.validateArgument(&tokens);
    }
};

/// Must be freed
pub const PostfixEquation = struct {
    const Self = @This();

    data: []const u8,
    allocator: std.mem.Allocator,
    keywords: std.StringHashMap(KeywordInfo),

    /// When created using this method, the resultant struct must be freed
    pub fn fromInfixEquation(equation: InfixEquation) !Self {
        var self = Self{
            .data = undefined,
            .allocator = equation.allocator,
            .keywords = equation.keywords,
        };

        self.data = try self.infixToPostfix(equation);

        return self;
    }

    /// Evaluate a postfix expression.
    /// If PostfixEquation has a valid stdout, prints errors to it using printError.
    /// Passes errors back to caller regardless of stdout being defined.
    pub fn evaluate(self: Self) !f64 {
        var stack = Stack.Stack(f64).init(self.allocator);
        defer stack.free();
        var tokens = std.mem.tokenizeScalar(u8, self.data, ' ');
        while (tokens.next()) |token| {
            switch (token[token.len - 1]) {
                '0'...'9', '.' => {
                    try stack.push(try std.fmt.parseFloat(f64, token));
                },
                else => {
                    std.debug.assert(token.len == 1);
                    const value = stack.pop();
                    if (calculate(stack.pop(), value, token[0])) |result| {
                        try stack.push(result);
                    } else |err| {
                        switch (err) {
                            Error.DivisionByZero => {
                                // if (self.stdout) |out| try Io.printError(err, out, null, null);
                                return err;
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        }
        defer std.debug.assert(stack.len() == 0);
        return stack.pop();
    }

    pub fn free(self: *const Self) void {
        self.allocator.free(self.data);
    }

    // Private functions

    fn addOperatorToStack(
        stack: *Stack.Stack(Operator),
        operator: Operator,
        output: *std.ArrayList(u8),
    ) !void {
        while (stack.len() > 0 and try stack.peek().higherOrEqual(operator)) {
            try output.append(' ');
            try output.append(@intFromEnum(stack.pop()));
        }
        try output.append(' ');
        try stack.push(operator);
    }

    fn findArgumentEnd(tokens: *Tokenizer) Tokenizer.Token {
        var paren_counter: isize = 0;
        while (true) {
            const token = tokens.next();
            std.log.debug("{any}", .{token.tag});
            switch (token.tag) {
                // Our equation is valid, so cannot return on invalid state
                .comma => if (paren_counter == 0) return token,
                .left_paren => paren_counter += 1,
                .right_paren => {
                    paren_counter -= 1;
                    if (paren_counter < 0) {
                        return token;
                    }
                },
                .eol => unreachable,
                else => continue,
            }
        }
    }

    fn evaluateKeyword(self: Self, tokens: *Tokenizer, token_slice: []const u8) anyerror!f64 {
        const keyword = self.keywords.get(token_slice).?;
        switch (keyword) {
            .Command => unreachable,
            .Function => |info| {
                _ = tokens.next();
                var args = std.ArrayList(f64).init(self.allocator);
                defer args.deinit();
                while (true) {
                    const start = tokens.next().start;
                    const token = findArgumentEnd(tokens);
                    std.log.debug("'{s}'", .{tokens.buffer[start..token.start]});

                    const infix = InfixEquation{
                        .data = tokens.buffer[start..token.start],
                        .allocator = self.allocator,
                        .keywords = self.keywords,
                    };
                    try args.append(try infix.evaluate());
                    if (token.tag == .right_paren) break;
                }
                const arg_slice = try args.toOwnedSlice();
                defer self.allocator.free(arg_slice);
                return info.ptr(arg_slice);
            },
            .StrFunction => |ptr| {
                _ = tokens.next();
                const start = tokens.next().start;
                var end: usize = undefined;
                while (true) {
                    const token = tokens.next();
                    if (token.tag == .right_paren) {
                        end = token.start;
                        break;
                    }
                }
                return ptr(tokens.buffer[start..end]);
            },
            .Constant => |data| return data,
        }
    }

    /// Returns string that must be freed
    fn infixToPostfix(self: Self, equation: InfixEquation) ![]u8 {
        var stack = Stack.Stack(Operator).init(equation.allocator);
        defer stack.free();
        var output = std.ArrayList(u8).init(equation.allocator);
        defer output.deinit();
        var tokens = Tokenizer.init(equation.data);
        const State = enum { none, negative, float };
        var state = State.none;
        while (true) {
            const token = tokens.next();
            switch (token.tag) {
                .eol => break,
                .float => {
                    switch (state) {
                        .none => {},
                        .negative => try output.append('-'),
                        .float => {
                            try addOperatorToStack(&stack, .multiplication, &output);
                        },
                    }
                    if (token.slice[0] == '.') {
                        try output.append('0');
                    }
                    state = .float;
                    try output.appendSlice(token.slice);
                },
                .keyword => {
                    var result = try self.evaluateKeyword(&tokens, token.slice);
                    switch (state) {
                        .none => {},
                        .negative => result = -result,
                        .float => {
                            try addOperatorToStack(&stack, .multiplication, &output);
                        },
                    }
                    try std.fmt.format(output.writer(), "{d}", .{result});
                    state = .float;
                },
                .minus => switch (state) {
                    .none => state = .negative,
                    .negative => state = .none,
                    .float => {
                        state = .none;
                        try addOperatorToStack(&stack, .subtraction, &output);
                    },
                },
                .left_paren => {
                    switch (state) {
                        .none => {},
                        .negative => {
                            try output.appendSlice("-1");
                            try addOperatorToStack(&stack, .multiplication, &output);
                        },
                        .float => {
                            try addOperatorToStack(&stack, .multiplication, &output);
                        },
                    }
                    state = .none;
                    try stack.push(.left_paren);
                },
                .right_paren => {
                    while (stack.peek() != Operator.left_paren) {
                        try output.append(' ');
                        try output.append(@intFromEnum(stack.pop()));
                    }
                    _ = stack.pop();
                    state = .float;
                },
                .operator => {
                    try addOperatorToStack(&stack, @enumFromInt(token.slice[0]), &output);
                    state = .none;
                },
                else => unreachable,
            }
        }
        while (stack.len() > 0) {
            try output.append(' ');
            try output.append(@intFromEnum(stack.pop()));
        }
        return output.toOwnedSlice();
    }

    fn calculate(number_1: f64, number_2: f64, operator: u8) Error!f64 {
        return switch (@as(Operator, @enumFromInt(operator))) {
            Operator.addition => number_1 + number_2,
            Operator.subtraction => number_1 - number_2,
            Operator.division => if (number_2 == 0) Error.DivisionByZero else number_1 / number_2,
            Operator.multiplication => number_1 * number_2,
            Operator.exponentiation => std.math.pow(f64, number_1, number_2),
            Operator.modulus => if (number_2 <= 0) Error.DivisionByZero else @mod(number_1, number_2),
            else => Error.InvalidOperator,
        };
    }
};

test "Operator.precedence validity" {
    const success_cases = .{ '+', '-', '/', '*', '^', '%', '(', ')' };
    const fail_cases = .{ 'a', '1', '0', 'w', '9', '&', '.', 'a' };
    inline for (success_cases) |case| {
        _ = try @as(Operator, @enumFromInt(case)).precedence();
    }
    inline for (fail_cases) |case| {
        const result = @as(Operator, @enumFromInt(case)).precedence();
        try testing.expectError(Error.InvalidOperator, result);
    }
}

test "PostfixEquation.calculate" {
    const success_cases = .{ '+', '-', '/', '*', '^', '%' };
    const success_case_numbers = [_]comptime_float{
        10, 10, 20,  10, 10, 0,
        10, 10, 1,   10, 10, 100,
        10, 2,  100, 30, 10, 0,
    };
    try testing.expect(success_case_numbers.len % 3 == 0);
    try testing.expect(success_cases.len == success_case_numbers.len / 3);
    const fail_cases = .{ '/', '%', 'a', '&', '1' };

    const fail_case_numbers = .{
        10, 0,  10, 0,  10,
        10, 10, 10, 10, 10,
    };
    try testing.expect(fail_case_numbers.len % 2 == 0);
    try testing.expect(fail_cases.len == fail_case_numbers.len / 2);
    inline for (0..success_cases.len) |i| {
        const result = try comptime PostfixEquation.calculate(
            success_case_numbers[i * 3],
            success_case_numbers[i * 3 + 1],
            success_cases[i],
        );
        try testing.expectEqual(success_case_numbers[i * 3 + 2], result);
    }
    inline for (0..fail_cases.len) |i| {
        if (PostfixEquation.calculate(
            fail_case_numbers[i * 2],
            fail_case_numbers[i * 2 + 1],
            fail_cases[i],
        )) |_| {
            return error.NotFail;
        } else |_| {}
    }
}
