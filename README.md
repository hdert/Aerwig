# Aerwig
An Expression Resolver, Written In Zig. An extensible library, for resolving and evaluating expressions using the shunting yard algorithm. Suitable for implementing a calculator in your application, or for using standalone as a calculator on the command line. Inspired by [Speedcrunch](https://bitbucket.org/heldercorreia/speedcrunch/src/master/) and similar to [YARER](https://github.com/davassi/yarer/tree/master). See an example WASM-web implementation [here](https://calculator.hdert.com/).

Example of use (src/example.zig):
```zig
const std = @import("std");
const Calculator = @import("Calculator");
const Addons = @import("Addons"); // Not included by default, optional

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() == .leak) @panic("Memory leak");

    var calculator = try Calculator.init(
        allocator,
        &.{Addons.registerKeywords}, // Function pointer to do setup
    );
    defer calculator.free(); // Uses a hashmap so you can use arbitrary keywords and functions

    try calculator.registerPreviousAnswer(10);

    const result = try calculator.evaluate("10 + answer", null); // You can pass in an optional error handler for more error context

    std.debug.print("Result: {d}", .{result}); // Result: 20
}
```