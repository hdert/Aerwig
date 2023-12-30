//! All calculator and library helper functions that deal with IO.
//! This module is nearly entirely untested, due to it's nature, so extra
//! scrutiny is advised and required.
//! TODO:
//! - Implement function that prints all keywords prettily with as much
//! information as possible.
//!     - Is not very pretty
//! - See if I can implement better stdin clearing with delimiter \000
const std = @import("std");
const Cal = @import("Calculator");

pub const Error = error{
    Help,
    Exit,
    Keywords,
};

const Self = @This();

stdout: std.fs.File.Writer,
stdin: std.fs.File.Reader,

pub fn init(stdout: std.fs.File.Writer, stdin: std.fs.File.Reader) Self {
    return Self{
        .stdout = stdout,
        .stdin = stdin,
    };
}

pub fn registerKeywords(equation: *Cal.Equation) !void {
    try equation.addKeywords(&[_][]const u8{
        "h",
        "help",
        "exit",
        "leave",
        "return",
        "quit",
        "q",
        "close",
        "keywords",
    }, &[_]Cal.KeywordInfo{
        .{ .Command = Error.Help },
        .{ .Command = Error.Help },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Exit },
        .{ .Command = Error.Keywords },
    });
}

pub fn printResult(self: Self, result: f64) !void {
    const abs_result = if (result < 0) -result else result;
    const small = abs_result < std.math.pow(f64, 10, -9);
    const big = abs_result > std.math.pow(f64, 10, 9);
    if (!(big or small) or result == 0) {
        try self.stdout.print("The result is {d}\n", .{result});
    } else {
        try self.stdout.print("The result is {e}\n", .{result});
    }
}

/// The caller ensures equation.stdout is not null
pub fn getInputFromUser(
    self: Self,
    equation: Cal.Equation,
    buffer: []u8,
) !Cal.InfixEquation {
    while (true) {
        try self.stdout.writeAll("Enter your equation: ");
        const user_input = self.stdin.readUntilDelimiterOrEof(buffer, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try self.stdout.writeAll("Input too large\n");
                try self.stdin.skipUntilDelimiterOrEof('\n'); // Try to flush stdin
                continue;
            },
            else => return err,
        };
        if (equation.newInfixEquation(user_input, self)) |result| {
            return result;
        } else |err| switch (err) {
            Error.Help => {
                try self.defaultHelp();
                return err;
            },
            Error.Exit => return err,
            Error.Keywords => {
                try self.printKeywords(equation);
                return err;
            },
            else => if (!Cal.isError(err)) return err,
        }
    }
}

/// Handles any internal error passed to it.
/// It will print error info if this has been passed to it.
/// If location is not null, equation must be not null.
/// In the case the error passed to it is not internal,
/// it will return that error as an error.
/// This function is not meant to check if an error is internal,
/// for that use isError from the Calculator Library.
pub fn handleError(
    self: Self,
    err: anyerror,
    location: ?[3]usize,
    equation: ?[]const u8,
) !void {
    const stdout = self.stdout;
    const E = Cal.Error;
    switch (err) {
        E.InvalidOperator,
        E.Comma,
        => try stdout.writeAll(
            "You have entered an invalid operator\n",
        ),
        E.InvalidKeyword => try stdout.writeAll(
            "You have entered an invalid keyword\n",
        ),
        E.DivisionByZero => try stdout.writeAll(
            "Cannot divide by zero\n",
        ),
        E.EmptyInput => try stdout.writeAll(
            "You cannot have an empty input\n",
        ),
        E.SequentialOperators => try stdout.writeAll(
            "You cannot enter sequential operators\n",
        ),
        E.EndsWithOperator => try stdout.writeAll(
            "You cannot finish with an operator\n",
        ),
        E.StartsWithOperator => try stdout.writeAll(
            "You cannot start with an operator\n",
        ),
        E.ParenEmptyInput => try stdout.writeAll(
            "You cannot have an empty parenthesis block\n",
        ),
        E.ParenStartsWithOperator => try stdout.writeAll(
            "You cannot start a parentheses block with an operator\n",
        ),
        E.ParenEndsWithOperator => try stdout.writeAll(
            "You cannot end a parentheses block with an operator\n",
        ),
        E.ParenMismatched,
        E.ParenMismatchedClose,
        E.ParenMismatchedStart,
        => try stdout.writeAll(
            "Mismatched parentheses!\n",
        ),
        E.InvalidFloat => try stdout.writeAll(
            "You cannot have more than one period in a floating point number\n",
        ),
        E.FnUnexpectedArgSize => try stdout.writeAll(
            "You haven't passed the correct number of arguments to this function\n",
        ),
        E.FnArgBoundsViolated => try stdout.writeAll(
            "Your arguments aren't within the range that this function expected\n",
        ),
        E.FnArgInvalid => try stdout.writeAll(
            "Your argument to this function is invalid\n",
        ),
        else => return err,
    }
    if (location) |l| {
        switch (err) {
            Cal.Error.DivisionByZero, Cal.Error.EmptyInput => {},
            else => {
                std.debug.assert(l[1] >= l[0]);
                std.debug.assert(equation != null);
                try stdout.print("{?s}\n", .{equation});
                for (l[0]) |_| try stdout.writeAll("-");
                for (l[1] - l[0]) |_| try stdout.writeAll("^");
                for (l[2] - l[1]) |_| try stdout.writeAll("-");
                try stdout.writeAll("\n");
            },
        }
    }
}

/// This doesn't work very well, maybe a function help module would be nicer?
pub fn printKeywords(self: Self, equation: Cal.Equation) !void {
    var iterator = equation.keywords.iterator();
    while (true) {
        const entry = iterator.next() orelse break;
        if (entry.value_ptr.* != .Command)
            try self.stdout.print("{s}: ", .{entry.key_ptr.*});
        switch (entry.value_ptr.*) {
            .Command => continue,
            .Function => |function| {
                if (function.arg_length == 0) {
                    try self.stdout.writeAll("function with infinite arguments\n");
                } else {
                    try self.stdout.print("function with {d} arguments\n", .{function.arg_length});
                }
            },
            .StrFunction => try self.stdout.writeAll("function with string input\n"),
            .Constant => |num| {
                try self.stdout.print("constant with value {d}\n", .{num});
            },
        }
    }
}

/// Print out a nice default help.
pub fn defaultHelp(self: Self) !void {
    try self.stdout.writeAll(
        \\General Purpose Calculator, written in Zig by Justin, © 2023-2024
        \\This calculator supports the standard order of operations, with the
        \\exception of the ordering of powers '^', these are ordered left-to-
        \\-right, unlike most calculators which order them right-to-left.
        \\
        \\You can exit this calculator with the keywords 'exit', 'quit', 
        \\'leave', 'close', or 'q'.
        \\You can call this help menu with the keywords 'h' or 'help'.
        \\This calculator supports using the previous answer with the keywords
        \\'a', 'ans', or 'answer'.
        \\
        \\The operators in this calculator are:
        \\    Brackets/Parentheses: '(', ')'
        \\    Exponentiation/Powers: '^'
        \\    Division: '/'
        \\    Multiplication: '*'
        \\    Addition: '+'
        \\    Subtraction: '-'
        \\
        \\This calculator supports functions which can be called like this:
        \\    'cos(2pi)'
        \\    'sum(2.5pi, -5, 40)'
        \\
        \\For a full list of functions and constants, use the command 'keywords'.
        \\
    );
}

test "handleError" {
    inline for (@typeInfo(Cal.Error).ErrorSet.?) |e| {
        try handleError(
            Self{
                .stdout = std.io.getStdErr().writer(),
                .stdin = undefined,
            },
            @field(Cal.Error, e.name),
            null,
            null,
        );
    }
}
