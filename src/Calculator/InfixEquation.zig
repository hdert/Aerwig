//! Holds a validated infix notation expression.
//! Create and validate with fromString().
//! Convert to PostfixEquation with toPostfixEquation().
//! Evaluate with evaluate(), which will convert and evaluate in one step.
const std = @import("std");
const Stack = @import("Stack");
const Tokenizer = @import("Tokenizer.zig");
const Definitions = @import("Definitions.zig");
const Error = Definitions.Error;
const Operator = Definitions.Operator;
const KeywordInfo = Definitions.KeywordInfo;
const PostfixEquation = @import("PostfixEquation.zig");
const tracy = @import("tracy.zig");

const Self = @This();

data: []const u8,
allocator: std.mem.Allocator,
keywords: std.StringHashMap(KeywordInfo),
error_info: ?[3]usize = null,
conversion_stack: ?*Stack.Stack(Operator) = null,
evaluation_stack: ?*Stack.Stack(f64) = null,

pub fn fromString(
    input: ?[]const u8,
    allocator: std.mem.Allocator,
    keywords: std.StringHashMap(KeywordInfo),
    error_handler: anytype,
) !Self {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    return PostfixEquation.init(self);
}

// Private functions

fn validateKeyword(self: *Self, tokens: *Tokenizer, keyword: []const u8) !void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    self.data = input orelse return Error.EmptyInput;
    if (@import("builtin").os.tag == .windows) {
        self.data = std.mem.trimRight(u8, self.data, "\r");
    }
    self.data = std.mem.trim(u8, self.data, " ");
    var tokens = Tokenizer.init(self.data);
    try self.validateArgument(&tokens);
}

// Evaluate

fn addOperatorToStack(
    input_stack: *Stack.Stack(Operator),
    input_stack_base_length: usize,
    operator: Operator,
    output_stack: *Stack.Stack(f64),
) !void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    while (input_stack.len() > input_stack_base_length and try input_stack.peek().higherOrEqual(operator)) {
        try evaluateOperator(output_stack, input_stack.pop());
    }
    try input_stack.push(operator);
}

fn findArgumentEnd(tokens: *Tokenizer) Tokenizer.Token {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    var paren_counter: isize = 0;
    while (true) {
        const token = tokens.next();
        std.log.debug("{any}", .{token.tag});
        switch (token.tag) {
            .comma => if (paren_counter == 0) return token,
            .left_paren => paren_counter += 1,
            .right_paren => {
                paren_counter -= 1;
                if (paren_counter < 0) {
                    return token;
                }
            },
            // Our equation has been validated, so cannot return in invalid state
            .eol => unreachable,
            else => continue,
        }
    }
}

fn evaluateKeyword(
    self: Self,
    tokens: *Tokenizer,
    token_slice: []const u8,
    conversion_stack: *Stack.Stack(Operator),
    evaluation_stack: *Stack.Stack(f64),
) anyerror!f64 {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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

                const infix = Self{
                    .data = tokens.buffer[start..token.start],
                    .allocator = self.allocator,
                    .keywords = self.keywords,
                    .conversion_stack = conversion_stack,
                    .evaluation_stack = evaluation_stack,
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

fn evaluateOperator(stack: *Stack.Stack(f64), operator: Operator) !void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    const value = stack.pop();
    if (calculate(stack.pop(), value, @intFromEnum(operator))) |result| {
        try stack.push(result);
    } else |err| {
        switch (err) {
            Error.DivisionByZero => return err,
            else => unreachable,
        }
    }
}

fn calculate(number_1: f64, number_2: f64, operator: u8) Error!f64 {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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

/// Evaluates an infix expression.
pub fn evaluate(self: Self) !f64 {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    var conversion_stack_backing = if (self.conversion_stack == null)
        Stack.Stack(Operator).init(self.allocator)
    else
        undefined;
    defer if (self.conversion_stack == null) conversion_stack_backing.free();
    var evaluation_stack_backing = if (self.evaluation_stack == null)
        Stack.Stack(f64).init(self.allocator)
    else
        undefined;
    defer if (self.evaluation_stack == null) evaluation_stack_backing.free();
    var conversion_stack: *Stack.Stack(Operator) = if (self.conversion_stack) |stack| stack else &conversion_stack_backing;
    var evaluation_stack: *Stack.Stack(f64) = if (self.evaluation_stack) |stack| stack else &evaluation_stack_backing;
    const conversion_stack_start_length = conversion_stack.len();
    const evaluation_stack_start_length = evaluation_stack.len();
    var tokens = Tokenizer.init(self.data);
    const State = enum { none, negative, float };
    var state = State.none;
    while (true) {
        const token = tokens.next();
        switch (token.tag) {
            .eol => break,
            .float => {
                const starts_with_dot = token.slice[0] == '.';
                const number_string = if (starts_with_dot)
                    try std.fmt.allocPrint(self.allocator, "0{s}", .{token.slice})
                else
                    token.slice;
                defer if (starts_with_dot) self.allocator.free(number_string);
                const number = try std.fmt.parseFloat(f64, number_string);
                switch (state) {
                    .none => try evaluation_stack.push(number),
                    .negative => try evaluation_stack.push(-number),
                    .float => {
                        try addOperatorToStack(
                            conversion_stack,
                            conversion_stack_start_length,
                            .multiplication,
                            evaluation_stack,
                        );
                        try evaluation_stack.push(number);
                    },
                }
                state = .float;
            },
            .keyword => {
                const result = try self.evaluateKeyword(&tokens, token.slice, conversion_stack, evaluation_stack);
                switch (state) {
                    .none => try evaluation_stack.push(result),
                    .negative => try evaluation_stack.push(-result),
                    .float => {
                        try addOperatorToStack(
                            conversion_stack,
                            conversion_stack_start_length,
                            .multiplication,
                            evaluation_stack,
                        );
                        try evaluation_stack.push(result);
                    },
                }
                state = .float;
            },
            .minus => switch (state) {
                .none => state = .negative,
                .negative => state = .none,
                .float => {
                    state = .none;
                    try addOperatorToStack(
                        conversion_stack,
                        conversion_stack_start_length,
                        .subtraction,
                        evaluation_stack,
                    );
                },
            },
            .left_paren => {
                switch (state) {
                    .none => {},
                    .negative => {
                        try evaluation_stack.push(-1);
                        try addOperatorToStack(
                            conversion_stack,
                            conversion_stack_start_length,
                            .multiplication,
                            evaluation_stack,
                        );
                    },
                    .float => {
                        try addOperatorToStack(
                            conversion_stack,
                            conversion_stack_start_length,
                            .multiplication,
                            evaluation_stack,
                        );
                    },
                }
                state = .none;
                try conversion_stack.push(.left_paren);
            },
            .right_paren => {
                while (conversion_stack.peek() != Operator.left_paren) {
                    try evaluateOperator(evaluation_stack, conversion_stack.pop());
                }
                _ = conversion_stack.pop();
                state = .float;
            },
            .operator => {
                try addOperatorToStack(
                    conversion_stack,
                    conversion_stack_start_length,
                    @enumFromInt(token.slice[0]),
                    evaluation_stack,
                );
                state = .none;
            },
            else => unreachable,
        }
    }
    while (conversion_stack.len() > conversion_stack_start_length) {
        try evaluateOperator(evaluation_stack, conversion_stack.pop());
    }
    std.debug.assert(evaluation_stack.len() == evaluation_stack_start_length + 1);
    return evaluation_stack.pop();
}
