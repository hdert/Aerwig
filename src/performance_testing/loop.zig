const std = @import("std");
const Calculator = @import("Calculator");
const Addons = @import("Addons");
const build_options = @import("build_options");
const use_next = build_options.use_next;

const error_handler = struct {
    pub fn handleError(
        self: error_handler,
        err: anyerror,
        location: ?[3]usize,
        equation: ?[]const u8,
    ) !void {
        _ = self;
        return std.log.err("err: {s}, location: {?d}, equation: {?s}", .{ @errorName(err), location, equation });
    }
};

pub fn main() !void {
    // const input = "100+sin(2pi)/10+sum(a,a,a,a,a,a,a,a,a,a,a,a)+average(sin(2pi), cos(2pi))^1";
    const input = "100+2/10+1+1+1+1+1+1+1+1+1+1+1+2+2^1";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Mem leak");
    const allocator = gpa.allocator();
    const loop_amount = 100_000;
    var loops: usize = loop_amount;

    var calculator = try Calculator.init(allocator, &.{Addons.registerKeywords});
    defer calculator.free();
    try calculator.registerPreviousAnswer(0);
    const err_handler = error_handler{};

    var timer = try std.time.Timer.start();
    while (loops > 0) : (loops -= 1) {
        try calculator.registerPreviousAnswer(
            if (use_next)
                try calculator.evaluate_experimental(input, err_handler)
            else
                try calculator.evaluate(input, err_handler),
        );
    }
    const time = timer.read();

    std.log.err(
        "Runs: {}, Time: {d}s, Average Time per run: {d}ms",
        .{
            loop_amount,
            @as(f64, @floatFromInt(time)) / std.time.ns_per_s,
            @as(f64, @floatFromInt(time)) / loop_amount / std.time.ns_per_us,
        },
    );
}
