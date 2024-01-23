//! From: https://www.ryanliptak.com/blog/fuzzing-zig-code/
const std = @import("std");
const calculator = @import("Calculator");
// const tokenizer = @import("Tokenizer.zig");

fn cMain() callconv(.C) void {
    main() catch unreachable;
}

comptime {
    @export(cMain, .{ .name = "main", .linkage = .Strong });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn();
    const data = try stdin.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    var calc = try calculator.init(allocator, null);
    defer calc.free();

    _ = calc.evaluate_experimental(data, null) catch |err| {
        if (calculator.isError(err)) return;
        return err;
    };
}
