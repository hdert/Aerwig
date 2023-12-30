const std = @import("std");

const targets: []const std.zig.CrossTarget = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const stack = b.dependency("stack", .{});
    const tokenizer = b.addModule("Tokenizer", .{ .source_file = .{ .path = "src/Tokenizer.zig" } });
    const calculator = b.addModule("Calculator", .{
        .source_file = .{ .path = "src/Calculator.zig" },
        .dependencies = &.{ .{
            .name = "Tokenizer",
            .module = tokenizer,
        }, .{
            .name = "Stack",
            .module = stack.module("Stack"),
        } },
    });
    const io = b.addModule("Io", .{
        .source_file = .{ .path = "src/Io.zig" },
        .dependencies = &.{.{
            .name = "Calculator",
            .module = calculator,
        }},
    });
    const addons = b.addModule("Addons", .{
        .source_file = .{ .path = "src/addons.zig" },
        .dependencies = &.{.{
            .name = "Calculator",
            .module = calculator,
        }},
    });

    // Creating cross-compilation builds

    for (targets) |t| {
        const exe = b.addExecutable(.{
            .name = "Calculator",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = t,
            .optimize = .ReleaseSafe,
        });
        exe.addModule("Io", io);
        exe.addModule("Addons", addons);
        exe.addModule("Calculator", calculator);

        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        });
        b.getInstallStep().dependOn(&target_output.step);
    }

    // Creating Native build

    const exe = b.addExecutable(.{
        .name = "Calculator",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("Io", io);
    exe.addModule("Addons", addons);
    exe.addModule("Calculator", calculator);
    const target_output = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{
                .custom = try target.zigTriple(b.allocator),
            },
        },
    });
    b.getInstallStep().dependOn(&target_output.step);

    // Creating executable run step

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&target_output.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Testing

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.addModule("Calculator", calculator);
    const calc_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/Calculator.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Adding option to generate test coverage

    const coverage = b.option(bool, "test-coverage", "Generate test coverage");
    if (coverage) |_| {
        // Currently doesn't work https://github.com/ziglang/zig/issues/17756
        // Workaround in runKcov.sh
        lib_unit_tests.setExecCmd(&[_]?[]const u8{
            "kcov",
            "--exclude-path=/usr/lib/zig/lib/,src/tests.zig,src/Tokenizer.zig,src/Io.zig,src/addons.zig,../Stack/src/",
            "kcov-output",
            null,
        });
    }

    // Creating test run step

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_calc_unit_tests = b.addRunArtifact(calc_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_calc_unit_tests.step);
}
