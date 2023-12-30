const std = @import("std");
const c = @import("Calculator");
const testing = std.testing;
const allocator = std.testing.allocator; // I regret having this as a global
const Allocator = std.mem.Allocator; // This is a good idea though
const check_allocation_failures = true;

const testData = struct {
    infix_equations: []const []const u8,
    postfix_equations: []const []const u8,
    inputs: []const f64,
    results: []const f64,
};

const test_cases: testData = .{
    .infix_equations = &[_][]const u8{
        "10+10",                  "10 + 10",
        "10+10 (20)",             "10+10 *(20)",
        "10/10",                  "10 / (10)",
        "10*(10)",                "10 * ( 10 )",
        "10",                     "10.10+10.10",
        "10.999",                 "10.789 * ( 10.123 )",
        "10.123+10.123",          "10.",
        "10 + (10 / 2 * 3) + 10", "10 + a",
        "10.+10.",                "a",
        "a",                      "-a",
        "a+a",                    "a*a+a",
        "123.+a",                 ".123",
        ".",                      "123.",
        "10(10)",                 "10(10)10",
        "(10)10",                 "10 (10)",
        "10 10",                  "10 + 10 10",
        "10.123 10",              "(10) 10",
        "a a",                    "10a",
        "10 a",                   "10 (a)",
        "a (10)",                 "10a10",
        "a10",                    "10 a 10",
        "a 10",                   "10 ^ 10 10",
        "a a a",                  "-10",
        "-.",                     "-a",
        "10-10",                  "0-10",
        "0+-10",                  "10*-10",
        "10--10",                 "10---10",
        "10+--10",                "10-.",
        "10--a",                  "-0",
        "-.0",                    "-0.",
        "--0",                    "--.",
        "--.0",                   "--0.0",
        "--0.",                   "-0.-0",
        ".-0",                    "0.0--0",
        ".--0",                   ". -. -0",
        ".--.",                   "--a",
        "-(10+5)",                "--(10+5)",
        "10-(10+5)",              "10+-(10+5)",
        "10 + (2 + 3 * 3) - 10",  "10. * 10.456",
        "0 . - - .",              "2 ^ 2 . * -.",
    },
    .postfix_equations = &[_][]const u8{
        "10 10 +",              "10 10 +",
        "10 10 20 * +",         "10 10 20 * +",
        "10 10 /",              "10 10 /",
        "10 10 *",              "10 10 *",
        "10",                   "10.10 10.10 +",
        "10.999",               "10.789 10.123 *",
        "10.123 10.123 +",      "10.",
        "10 10 2 / 3 * + 10 +", "10 10 +",
        "10. 10. +",            "0",
        "10",                   "-10",
        "10 10 +",              "10 10 * 10 +",
        "123. 0.456 +",         "0.123",
        "0.",                   "123.",
        "10 10 *",              "10 10 * 10 *",
        "10 10 *",              "10 10 *",
        "10 10 *",              "10 10 10 * +",
        "10.123 10 *",          "10 10 *",
        "10 10 *",              "10 10 *",
        "10 10 *",              "10 10 *",
        "10 10 *",              "10 10 * 10 *",
        "10 10 *",              "10 10 * 10 *",
        "10 10 *",              "10 10 ^ 10 *",
        "10 10 * 10 *",         "-10",
        "-0.",                  "-10",
        "10 10 -",              "0 10 -",
        "0 -10 +",              "10 -10 *",
        "10 -10 -",             "10 10 -",
        "10 10 +",              "10 0. -",
        "10 10 -",              "-0",
        "-0.0",                 "-0.",
        "0",                    "0.",
        "0.0",                  "0.0",
        "0.",                   "-0. 0 -",
        "0. 0 -",               "0.0 -0 -",
        "0. -0 -",              "0. 0. - 0 -",
        "0. -0. -",             "10",
        "-1 10 5 + *",          "10 5 +",
        "10 10 5 + -",          "10 -1 10 5 + * +",
        "10 2 3 3 * + + 10 -",  "10. 10.456 *",
        "0 0. * -0. -",         "2 2 ^ 0. * -0. *",
    },
    .inputs = &[_]f64{
        0,   0,  0,  0,  0,  0,  0,     0,
        0,   0,  0,  0,  0,  0,  0,     10,
        0,   0,  10, 10, 10, 10, 0.456, 0,
        0,   0,  0,  0,  0,  0,  0,     0,
        0,   0,  10, 10, 10, 10, 10,    10,
        10,  10, 10, 0,  10, 0,  0,     10,
        0,   0,  0,  0,  0,  0,  0,     0,
        -10, 0,  0,  0,  0,  0,  0,     0,
        0,   0,  0,  0,  0,  0,  0,     10,
        0,   0,  0,  0,  0,  0,  0,     0,
    },
    .results = &[_]f64{
        20,                 20,     210,     210,
        1,                  1,      100,     100,
        10,                 20.2,   10.999,  109.217047,
        20.246,             10,     35,      20,
        20,                 0,      10,      -10,
        20,                 110,    123.456, 0.123,
        0,                  123,    100,     1000,
        100,                100,    100,     110,
        101.22999999999999, 100,    100,     100,
        100,                100,    100,     1000,
        100,                1000,   100,     100000000000,
        1000,               -10,    0,       -10,
        0,                  -10,    -10,     -100,
        20,                 0,      20,      10,
        0,                  0,      0,       0,
        0,                  0,      0,       0,
        0,                  0,      0,       0,
        0,                  0,      0,       10,
        -15,                15,     -5,      -5,
        11,                 104.56, 0,       0,
    },
};

test {
    _ = @import("Io.zig");
}

test {
    _ = @import("addons.zig");
}

test "isError" {
    inline for (@typeInfo(c.Error).ErrorSet.?) |e| {
        try testing.expect(c.isError(@field(c.Error, e.name)));
    }
}

fn infixEquationFromStringTest(alloc: Allocator) !void {
    const fail_cases = [_]?[]const u8{
        "-",       "10++10",     "10(*10)",
        "10(10*)", "10*",        "10(10)*",
        "()",      "10()",       "21 + 2 ) * ( 5 / 6",
        "10.789.", "10.789.123", "10..",
        "",        "-",          "-0.-",
        "10-",     "--",         ".-",
        ". -. -",  null,         "1(",
        "(",       "      ",     "()",
        "(*",      "asdf",       "aa",
        "aa a",    "a aa",       "aaa",
        "10-*10",  "_",          "+",
        ")",       "(",          "(1",
        "æ",      ")",          "1)",
        ",",       "\x00",       "(,)",
        "1+,",     "-,",         "1,",
        "1),",     "(1,)",
    };
    var eq = try c.Equation.init(alloc, null, null);
    defer eq.free();
    try eq.registerPreviousAnswer(0);
    for (test_cases.infix_equations, 0..) |case, i| {
        const result = eq.newInfixEquation(case, null) catch |err| {
            std.debug.print("\nNumber: {d}", .{i});
            return err;
        };
        try testing.expectEqualSlices(u8, case, result.data);
    }
    for (fail_cases, 0..) |case, i| {
        if (eq.newInfixEquation(case, null)) |_| {
            std.debug.print("\nNumber: {d}\n", .{i});
            return error.NotFail;
        } else |err| {
            switch (err) {
                c.Error.InvalidOperator,
                c.Error.DivisionByZero,
                => return error.UnexpectedError,
                else => {
                    if (!c.isError(err)) return error.InvalidError;
                },
            }
        }
    }
}

test "InfixEquation.fromString" {
    if (check_allocation_failures) {
        try testing.checkAllAllocationFailures(allocator, infixEquationFromStringTest, .{});
    } else {
        try infixEquationFromStringTest(allocator);
    }
}

fn infixEquationToPostfixEquationTest(alloc: Allocator) !void {
    var eq = try c.Equation.init(alloc, null, null);
    defer eq.free();
    for (
        test_cases.infix_equations,
        test_cases.postfix_equations,
        test_cases.inputs,
    ) |infix, postfix, input| {
        try eq.registerPreviousAnswer(input);
        const infixEquation = try eq.newInfixEquation(infix, null);
        const postfixEquation = try infixEquation.toPostfixEquation();
        defer postfixEquation.free();
        try testing.expectEqualSlices(u8, postfix, postfixEquation.data);
        const postfixEquation2 = try c.PostfixEquation.fromInfixEquation(infixEquation);
        defer postfixEquation2.free();
        try testing.expectEqualSlices(u8, postfix, postfixEquation2.data);
    }
}

test "InfixEquation.toPostfixEquation" {
    if (check_allocation_failures) {
        try testing.checkAllAllocationFailures(allocator, infixEquationEvaluateTest, .{});
    } else {
        try infixEquationEvaluateTest(allocator);
    }
}

fn infixEquationEvaluateTest(alloc: Allocator) !void {
    var eq = try c.Equation.init(
        alloc,
        &.{"a"},
        &.{c.KeywordInfo{
            .Constant = 0,
        }},
    );
    defer eq.free();
    for (
        test_cases.infix_equations,
        test_cases.inputs,
        test_cases.results,
    ) |infix, input, result| {
        try eq.registerPreviousAnswer(input);
        var infix_equation = try eq.newInfixEquation(infix, null);
        const output = try infix_equation.evaluate();
        testing.expectEqual(result, output) catch |err| {
            std.debug.print("Expected: {d}\nGot: {d}\nCase: {s}\nPrevious Answer: {d}\n", .{
                result,
                output,
                infix,
                input,
            });
            return err;
        };
    }
}

test "InfixEquation.evaluate" {
    if (check_allocation_failures) {
        try testing.checkAllAllocationFailures(allocator, infixEquationEvaluateTest, .{});
    } else {
        try infixEquationEvaluateTest(allocator);
    }
}

fn postfixEquationEvaluateTestPass(alloc: std.mem.Allocator) !void {
    var eq = try c.Equation.init(allocator, null, null);
    defer eq.free();
    for (
        test_cases.postfix_equations,
        test_cases.results,
    ) |postfix, result| {
        const postfix_equation = c.PostfixEquation{
            .data = postfix,
            .allocator = alloc,
            .keywords = eq.keywords,
        };
        const output = try postfix_equation.evaluate();
        testing.expectEqual(result, output) catch |err| {
            std.debug.print("Expected: {d}\nGot: {d}\nCase: {s}\n", .{
                result,
                output,
                postfix,
            });
            return err;
        };
    }
}

fn postfixEquationEvaluateTestFail(alloc: std.mem.Allocator) !void {
    var eq = try c.Equation.init(allocator, null, null);
    defer eq.free();
    const fail_cases = [_][]const u8{
        "10 0 /",       "10 0 %",
        "10 10 10 - /", "10 10 10 - %",
        "10 0 /",       "10 0 %",
        "--10",
    };
    for (fail_cases) |case| {
        const postfix_equation = c.PostfixEquation{
            .data = case,
            .allocator = alloc,
            .keywords = eq.keywords,
        };
        const result = postfix_equation.evaluate();
        if (result) |_| {
            return error.NotFail;
        } else |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => return err,
                else => {},
            }
        }
    }
}

test "PostfixEquation.evaluate" {
    if (check_allocation_failures) {
        try testing.checkAllAllocationFailures(allocator, postfixEquationEvaluateTestPass, .{});
        try testing.checkAllAllocationFailures(allocator, postfixEquationEvaluateTestFail, .{});
    } else {
        try postfixEquationEvaluateTestPass(allocator);
        try postfixEquationEvaluateTestFail(allocator);
    }
}
