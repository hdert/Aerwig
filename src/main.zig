//! TODO:
//! - Add support for command line input with clap
const std = @import("std");
const Calculator = @import("Calculator");
const Io = @import("Io");
const Addons = @import("Addons");
const tracy = Calculator.tracy;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) std.debug.print("Memory leak", .{});
    var result: f64 = 0;
    var buffer: [1000]u8 = undefined;
    const io = Io.init(stdout, stdin);
    var calculator = try Calculator.init(
        allocator,
        &.{ Io.registerKeywords, Addons.registerKeywords },
    );
    defer calculator.free();

    try io.defaultHelp();
    while (true) {
        try calculator.registerPreviousAnswer(result);
        const infixEquation = io.getInputFromUser(
            calculator,
            buffer[0..],
        ) catch |err| switch (err) {
            Io.Error.Help => continue,
            Io.Error.Exit => return,
            Io.Error.Keywords => continue,
            else => return err,
        };

        result = infixEquation.evaluate() catch |err| {
            try io.handleError(err, null, null);
            continue;
        };

        try io.printResult(result);
    }
}
