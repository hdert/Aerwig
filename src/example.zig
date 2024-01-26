const std = @import("std");
const Calculator = @import("Calculator");
const Addons = @import("Addons"); // Not included by default, optional

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) @panic("Memory leak");

    var calculator = try Calculator.init(
        allocator,
        &.{Addons.registerKeywords}, // Function pointer to register function
    );
    defer calculator.free(); // Uses a hashmap to have arbitrary keywords and functions

    try calculator.registerPreviousAnswer(10);

    const result = try calculator.evaluate("10 + answer", null); // You can pass in an optional error handler for more error context

    std.debug.print("Result: {d}", .{result}); // Result: 20
}
