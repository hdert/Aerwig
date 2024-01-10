const std = @import("std");
const stack = @import("Stack");
const Tokenizer = @import("Tokenizer");
const Calculator = @import("Calculator.zig");
const Error = Calculator.Error;
const PostfixEquation = @import("PostfixEquation.zig");

const Self = @This();

data: []const u8,
// stdout: ?std.fs.File.Writer = null,
allocator: std.mem.Allocator,
keywords: std.StringHashMap(Calculator.KeywordInfo),
error_info: ?[3]usize = null,

pub fn fromString(
    input: ?[]const u8,
    allocator: std.mem.Allocator,
    keywords: std.StringHashMap(Calculator.KeywordInfo),
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
    return PostfixEquation.init(self);
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
