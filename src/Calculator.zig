//! Must be freed due to hashmap
//! Initialize an instance with init(), free with free().
//! Create new InfixEquation with newInfixEquation(), or
//! evaluate directly with evaluate().
//! Add custom keywords (constants, functions, commands) with addKeywords().
//! TODO:
//! - Create tests for Tokenizer
//!     - Depends on whether the code ever changes, and whether
//!     the public method testing covers it.
//! - Find way to do performance testing
//! - Find way to do end-to-end testing with custom file reader
//!     - Use result generator and writer to test entire user text
//!     to ensure that it never changes, and if it does, to highlight it
//!     - This will finally include error results and error types
//!     - Integrate this with fuzzing
//!     - Use std.testing.tmpDir

const std = @import("std");
const Stack = @import("Stack");
pub const Tokenizer = @import("Calculator/Tokenizer");
pub const InfixEquation = @import("Calculator/InfixEquation.zig");
pub const PostfixEquation = @import("Calculator/PostfixEquation.zig");
const Definitions = @import("Calculator/Definitions.zig");
pub const Error = Definitions.Error;
pub const isError = Definitions.isError;
pub const errorDescription = Definitions.errorDescription;
pub const Operator = Definitions.Operator;
pub const KeywordInfo = Definitions.KeywordInfo;
const Allocator = std.mem.Allocator;
pub const tracy = @import("Calculator/tracy.zig");

const Self = @This();

allocator: Allocator,
keywords: std.StringHashMap(KeywordInfo),

pub fn init(
    allocator: Allocator,
    KeywordRegistrars: ?[]const *const fn (*Self) Allocator.Error!void,
) !Self {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
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
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    try self.addKeywords(&.{
        "inf",
        "nan",
    }, &.{
        .{ .Constant = std.math.inf(f64) },
        .{ .Constant = std.math.nan(f64) },
    });
}

pub fn addKeywords(
    self: *Self,
    keys: []const []const u8,
    values: []const KeywordInfo,
) !void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    for (keys, values) |key, value|
        try self.keywords.put(key, value);
}

pub fn registerPreviousAnswer(self: *Self, prev_ans: f64) !void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    try self.addKeywords(
        &[_][]const u8{ "a", "ans", "answer" },
        &[_]KeywordInfo{
            .{ .Constant = prev_ans },
            .{ .Constant = prev_ans },
            .{ .Constant = prev_ans },
        },
    );
}

pub fn newInfixEquation(
    self: Self,
    input: ?[]const u8,
    error_handler: anytype,
) !InfixEquation {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    return InfixEquation.fromString(
        input,
        self.allocator,
        self.keywords,
        error_handler,
    );
}

pub fn evaluate(self: Self, input: ?[]const u8, error_handler: anytype) !f64 {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    return (try InfixEquation.fromString(
        input,
        self.allocator,
        self.keywords,
        error_handler,
    )).evaluate();
}

pub fn evaluate_experimental(self: Self, input: ?[]const u8, error_handler: anytype) !f64 {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    return (try InfixEquation.fromString(
        input,
        self.allocator,
        self.keywords,
        error_handler,
    )).evaluate_experimental();
}

pub fn free(self: *Self) void {
    const tracy_zone = tracy.trace(@src());
    defer tracy_zone.end();
    self.keywords.deinit();
}

test "PostfixEquation" {
    _ = PostfixEquation;
}
