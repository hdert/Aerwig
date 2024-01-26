//! Must be freed
//! Struct that holds a RPN (Reverse Polish Notation) representation
//! of an expression, and methods to manipulate it.
//! Create with init() which accepts an InfixEquation.
//! Evaluate expression with evaluate().
const std = @import("std");
const testing = std.testing;
const Stack = @import("Stack");
const Tokenizer = @import("Tokenizer");
const Calculator = @import("Calculator.zig");
const Operator = Calculator.Operator;
const Error = Calculator.Error;
const InfixEquation = @import("InfixEquation.zig");

const Self = @This();

data: []const u8,
allocator: std.mem.Allocator,
keywords: std.StringHashMap(Calculator.KeywordInfo),

/// When created using this method, the resultant struct must be freed
pub fn init(equation: InfixEquation) !Self {
    var self = Self{
        .data = undefined,
        .allocator = equation.allocator,
        .keywords = equation.keywords,
    };

    self.data = try self.infixToPostfix(equation);

    return self;
}

/// Evaluate a postfix expression.
pub fn evaluate(self: Self) !f64 {
    var stack = Stack.Stack(f64).init(self.allocator);
    defer stack.free();
    var tokens = std.mem.tokenizeScalar(u8, self.data, ' ');
    while (tokens.next()) |token| {
        switch (token[token.len - 1]) {
            '0'...'9', '.', 'f', 'n' => { // inf and nan
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
        const result = try comptime Self.calculate(
            success_case_numbers[i * 3],
            success_case_numbers[i * 3 + 1],
            success_cases[i],
        );
        try testing.expectEqual(success_case_numbers[i * 3 + 2], result);
    }
    inline for (0..fail_cases.len) |i| {
        if (Self.calculate(
            fail_case_numbers[i * 2],
            fail_case_numbers[i * 2 + 1],
            fail_cases[i],
        )) |_| {
            return error.NotFail;
        } else |_| {}
    }
}
