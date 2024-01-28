const std = @import("std");
const Calculator = @cImport({
    @cInclude("stdbool.h");
    @cInclude("CalculatorLib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Mem leak");
    const allocator = gpa.allocator();
    const input_string = "100+2/10+1+1+1+1+1+1+1+1+1+1+1+2+2^1";
    const input = try allocator.alloc(u8, input_string.len);
    defer allocator.free(input);
    std.mem.copyForwards(u8, input, input_string);
    const loop_amount = 100_000;
    var loops: usize = loop_amount;
    var zig_buffer: [100]u8 = undefined;
    const buffer: [*c]u8 = (&zig_buffer).ptr;
    var result: f64 = 0;

    var timer = try std.time.Timer.start();
    while (loops > 0) : (loops -= 1) {
        if (!Calculator.validate_input(input.ptr, input.len))
            break;
        if (!Calculator.infix_to_postfix(input.ptr, input.len, buffer, zig_buffer.len))
            break;
        if (!Calculator.evaluate_postfix(buffer, 0, &result))
            break;
    }
    const time = @as(f64, @floatFromInt(timer.read()));

    std.debug.print(
        "Runs: {}, Time: {d}s, Average Time per run: {d}ms\n",
        .{
            loop_amount - loops,
            time / std.time.ns_per_s,
            time / loop_amount / std.time.ns_per_us,
        },
    );
}
