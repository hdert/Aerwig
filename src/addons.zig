//! Addon functions for the calculator
//! TODO:
//! - Write unit tests for non-standard functions
//! - Write end-to-end testing for addons
const std = @import("std");
const Cal = @import("Calculator");

pub fn registerKeywords(equation: *Cal.Equation) !void {
    try equation.addKeywords(&[_][]const u8{
        "sqrt",  "abs", "exp",     "exp2",
        "gcd",   "sin", "asin",    "sinh",
        "asinh", "cos", "acos",    "cosh",
        "acosh", "tan", "atan",    "tanh",
        "atanh", "log", "log2",    "log10",
        "ln",    "sum", "average", "median",
        "mode",  "min", "max",     "pi",
        "e",     "tau",
    }, &[_]Cal.KeywordInfo{
        .{ .Function = .{ .arg_length = 1, .ptr = sqrt } },
        .{ .Function = .{ .arg_length = 1, .ptr = abs } },
        .{ .Function = .{ .arg_length = 1, .ptr = exp } },
        .{ .Function = .{ .arg_length = 1, .ptr = exp2 } },
        .{ .Function = .{ .arg_length = 2, .ptr = gcd } },
        .{ .Function = .{ .arg_length = 1, .ptr = sin } },
        .{ .Function = .{ .arg_length = 1, .ptr = asin } },
        .{ .Function = .{ .arg_length = 1, .ptr = sinh } },
        .{ .Function = .{ .arg_length = 1, .ptr = asinh } },
        .{ .Function = .{ .arg_length = 1, .ptr = cos } },
        .{ .Function = .{ .arg_length = 1, .ptr = acos } },
        .{ .Function = .{ .arg_length = 1, .ptr = cosh } },
        .{ .Function = .{ .arg_length = 1, .ptr = acosh } },
        .{ .Function = .{ .arg_length = 1, .ptr = tan } },
        .{ .Function = .{ .arg_length = 1, .ptr = atan } },
        .{ .Function = .{ .arg_length = 1, .ptr = tanh } },
        .{ .Function = .{ .arg_length = 1, .ptr = atanh } },
        .{ .Function = .{ .arg_length = 2, .ptr = log } },
        .{ .Function = .{ .arg_length = 1, .ptr = log2 } },
        .{ .Function = .{ .arg_length = 1, .ptr = log10 } },
        .{ .Function = .{ .arg_length = 1, .ptr = ln } },
        .{ .Function = .{ .arg_length = 0, .ptr = sum } },
        .{ .Function = .{ .arg_length = 0, .ptr = average } },
        .{ .Function = .{ .arg_length = 0, .ptr = median } },
        .{ .Function = .{ .arg_length = 0, .ptr = mode } },
        .{ .Function = .{ .arg_length = 0, .ptr = min } },
        .{ .Function = .{ .arg_length = 0, .ptr = max } },
        .{ .Constant = std.math.pi },
        .{ .Constant = std.math.e },
        .{ .Constant = std.math.tau },
    });
}

// Math functions

fn sqrt(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.sqrt(i[0]);
}

fn abs(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return if (i[0] < 0) -i[0] else i[0];
}

fn exp(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.exp(i[0]);
}

fn exp2(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.exp2(i[0]);
}

/// TODO: Write unit test
fn gcd(i: []const f64) !f64 {
    std.debug.assert(i.len == 2);
    if (i[0] <= 0 or
        i[1] <= 0 or
        i[0] > std.math.maxInt(u64) or
        i[1] > std.math.maxInt(u64))
    {
        return Cal.Error.FnArgBoundsViolated;
    }
    const num_1: u64 = @intFromFloat(i[0]);
    const num_2: u64 = @intFromFloat(i[1]);

    return @floatFromInt(std.math.gcd(num_1, num_2));
}

// fn lcm(i: []f64) !f64 {
//     std.debug.assert(i.len == 1);
//     return std.math.lcm(i[0]); // TODO
// }

// Trigonometry functions

fn sin(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.sin(i[0]);
}

fn asin(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.asin(i[0]);
}

fn sinh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.sinh(i[0]);
}

fn asinh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.asinh(i[0]);
}

fn cos(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.cos(i[0]);
}

fn acos(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.acos(i[0]);
}

fn cosh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.cosh(i[0]);
}
fn acosh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.acosh(i[0]);
}

fn tan(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.tan(i[0]);
}

fn atan(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.atan(i[0]);
}

fn tanh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.tanh(i[0]);
}

fn atanh(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.atanh(i[0]);
}

fn log(i: []const f64) !f64 {
    std.debug.assert(i.len == 2);
    return std.math.log(f64, i[0], i[1]);
}
fn log2(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.log2(i[0]);
}
fn log10(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.log10(i[0]);
}
fn ln(i: []const f64) !f64 {
    std.debug.assert(i.len == 1);
    return std.math.log(f64, std.math.e, i[0]);
}

// Statistics functions

/// TODO: Write unit test
fn sum(i: []const f64) !f64 {
    std.debug.assert(i.len > 0);
    var s: f64 = 0;
    for (i) |j| {
        s += j;
    }
    return s;
}

test "sum" {
    const inputs = [_][]const f64{
        &[_]f64{0},
        &[_]f64{1},
        &[_]f64{-1},
        &[_]f64{ 1, 1 },
        &[_]f64{ 1, 2, 3 },
        &[_]f64{ -1, 0, 1 },
        &[_]f64{ -1, 0, 3 },
    };
    const outputs = [inputs.len]f64{
        0, 1, -1, 2, 6, 0, 2,
    };
    inline for (inputs, outputs) |i, o| {
        try std.testing.expectEqual(try sum(i), o);
    }
}

/// TODO: Write unit test
fn average(i: []const f64) !f64 {
    std.debug.assert(i.len > 0);
    return try sum(i) / @as(f64, @floatFromInt(i.len));
}

test "average" {
    const inputs = [_][]const f64{
        &[_]f64{0},
        &[_]f64{1},
        &[_]f64{ -1, 1 },
        &[_]f64{ 1, 2, 3 },
        &[_]f64{ -1, -2, -3 },
        &[_]f64{ -1, 2, -1 },
    };
    const outputs = [inputs.len]f64{
        0, 1, 0, 2, -2, 0,
    };
    inline for (inputs, outputs) |i, o| {
        try std.testing.expectEqual(try average(i), o);
    }
}

/// TODO: Write unit test
fn median(i: []f64) !f64 {
    std.debug.assert(i.len > 0);
    const half_len = i.len / 2;
    std.sort.heap(f64, i, {}, std.sort.asc(f64));
    return switch (i.len % 2 == 0) {
        true => return average(i[half_len - 1 .. half_len + 1]),
        false => return i[half_len],
    };
}

/// TODO: Write unit test
fn mode(i: []f64) !f64 {
    std.debug.assert(i.len > 0);
    std.sort.heap(f64, i, {}, std.sort.asc(f64));
    var longest_length: usize = 0;
    var next_length: usize = 0;
    var current_longest: f64 = i[0];
    var next: f64 = i[0];
    for (i) |j| {
        if (j == next) {
            next_length += 1;
        } else {
            next = j;
            next_length = 1;
        }
        if (next_length > longest_length) {
            current_longest = next;
            longest_length = next_length;
        }
    }
    return current_longest;
}

/// TODO: Write unit test
fn min(i: []const f64) !f64 {
    std.debug.assert(i.len > 0);
    var smallest = i[0];
    for (i) |j| {
        if (j < smallest) smallest = j;
    }
    return smallest;
}

/// TODO: Write unit test
fn max(i: []const f64) !f64 {
    std.debug.assert(i.len > 0);
    var biggest = i[0];
    for (i) |j| {
        if (j > biggest) biggest = j;
    }
    return biggest;
}
