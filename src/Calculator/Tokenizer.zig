//! Tokenizes arithmetic expressions.
//! Use by calling fn init([]const u8) Tokenizer
//! Then call next() to get next token.
const tracy = @import("tracy.zig");
const Self = @This();

buffer: []const u8,
index: usize = 0,

const State = enum {
    float,
    float_decimals,
    float_e_notation_start,
    float_e_notation,
    keyword,
    start,
};

pub fn init(buffer: []const u8) Self {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    return Self{
        .buffer = buffer,
    };
}

/// Takes Self, returns Token.
pub fn next(self: *Self) Token {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    var result = Token{
        .tag = .eol,
    };
    result.start = self.index;
    var state = State.start;
    while (self.index < self.buffer.len) : (self.index += 1) {
        const c = self.buffer[self.index];
        switch (state) {
            .start => switch (c) {
                ' ' => {
                    result.start = self.index + 1;
                    continue;
                },
                0, '\n', '\t', '\r' => break,
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                    break;
                },
                '0'...'9' => {
                    state = .float;
                    result.tag = .float;
                },
                '.' => {
                    state = .float_decimals;
                    result.tag = .float;
                },
                '+', '/', '*', '^', '%' => {
                    result.tag = .operator;
                    self.index += 1;
                    break;
                },
                '-' => {
                    result.tag = .minus;
                    self.index += 1;
                    break;
                },
                '(' => {
                    result.tag = .left_paren;
                    self.index += 1;
                    break;
                },
                ')' => {
                    result.tag = .right_paren;
                    self.index += 1;
                    break;
                },
                'a'...'z', 'A'...'Z' => {
                    result.tag = .keyword;
                    state = .keyword;
                },
                else => {
                    result.tag = .invalid;
                    self.index += 1;
                    break;
                },
            },
            .float => switch (c) {
                '0'...'9' => continue,
                '.' => state = .float_decimals,
                'e' => {
                    state = .float_e_notation_start;
                    result.tag = .invalid_float;
                },
                else => break,
            },
            .float_decimals => switch (c) {
                '0'...'9' => continue,
                '.' => {
                    self.index += 1;
                    result.tag = .invalid_float;
                    break;
                },
                'e' => {
                    state = .float_e_notation_start;
                    result.tag = .invalid_float;
                },
                else => break,
            },
            .float_e_notation_start => switch (c) {
                '0'...'9' => {
                    state = .float_e_notation;
                    result.tag = .float;
                },
                '+', '-' => {
                    state = .float_e_notation;
                    result.tag = .invalid_float;
                },
                else => break,
            },
            .float_e_notation => switch (c) {
                '0'...'9' => result.tag = .float,
                else => break,
            },
            .keyword => switch (c) {
                'a'...'z', 'A'...'Z', '_' => continue,
                else => break,
            },
        }
    }
    result.slice = self.buffer[result.start..self.index];
    result.end = self.index;
    return result;
}

pub const Token = struct {
    slice: []const u8 = undefined,
    start: usize = undefined,
    end: usize = undefined,
    tag: Tag,

    const Tag = enum {
        float,
        invalid_float,
        operator,
        left_paren,
        right_paren,
        minus,
        keyword,
        eol,
        invalid,
        comma,
    };
};
