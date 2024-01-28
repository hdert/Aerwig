const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Calculator",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addCSourceFiles(.{
        .files = &.{
            "CalculatorLib.c",
            "Stack.c",
            // "CalculatorLib.h",
        },
        .flags = &.{"-std=c2x"},
    });
    exe.addIncludePath(.{ .path = "./" });
    // const calculator = b.addStaticLibrary(.{
    //     .name = "CalculatorLib",
    //     .root_source_file = .{ .path = "CalculatorLib.c" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    const exe_output = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&exe_output.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&exe_output.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
