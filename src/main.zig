const std = @import("std");
const Calculator = @import("Calculator");
const Io = @import("Io");
const Addons = @import("Addons");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) std.debug.print("Memory leak", .{});
    var result: f64 = 0;
    var buffer: [1000]u8 = undefined;
    const io = Io.init(stdout, stdin);
    var equation = try Calculator.Equation.init(
        allocator,
        null,
        null,
    );
    defer equation.free();
    try Io.registerKeywords(&equation);
    try Addons.registerKeywords(&equation);

    try io.defaultHelp();
    while (true) {
        try equation.registerPreviousAnswer(result);
        const infixEquation = io.getInputFromUser(
            equation,
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
