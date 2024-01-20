const std = @import("std");

const targets: []const std.Target.Query = &.{
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
    const tokenizer = b.addModule(
        "Tokenizer",
        .{ .root_source_file = .{ .path = "src/Tokenizer.zig" } },
    );
    const calculator = b.addModule("Calculator", .{
        .root_source_file = .{ .path = "src/Calculator.zig" },
    });
    calculator.addImport("Tokenizer", tokenizer);
    calculator.addImport("Stack", stack.module("Stack"));
    const io = b.addModule(
        "Io",
        .{ .root_source_file = .{ .path = "src/Io.zig" } },
    );
    io.addImport("Calculator", calculator);
    const addons = b.addModule(
        "Addons",
        .{ .root_source_file = .{ .path = "src/addons.zig" } },
    );
    addons.addImport("Calculator", calculator);

    // Creating cross-compilation builds

    for (targets) |t| {
        const exe = b.addExecutable(.{
            .name = try std.fmt.allocPrint(b.allocator, "Calculator-{s}", .{try t.zigTriple(b.allocator)}),
            .root_source_file = .{ .path = "src/main.zig" },
            .target = b.resolveTargetQuery(t),
            .optimize = .ReleaseSafe,
        });
        exe.root_module.addImport("Io", io);
        exe.root_module.addImport("Addons", addons);
        exe.root_module.addImport("Calculator", calculator);

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
    exe.root_module.addImport("Io", io);
    exe.root_module.addImport("Addons", addons);
    exe.root_module.addImport("Calculator", calculator);
    const target_output = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{
                .custom = try target.query.zigTriple(b.allocator),
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
    lib_unit_tests.root_module.addImport("Calculator", calculator);
    const calc_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/Calculator.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Creating test step

    const test_step = b.step("test", "Run unit tests");

    // Adding option to generate test coverage

    const coverage = b.option(bool, "test-coverage", "Generate test coverage");
    if (coverage) |_| {
        // Currently doesn't work https://github.com/ziglang/zig/issues/17756
        // Workaround in runKcov.sh
        // lib_unit_tests.setExecCmd(&[_]?[]const u8{
        //     "kcov",
        //     "--exclude-path=/usr/lib/zig/lib/",
        //     "kcov-output",
        //     null,
        // });
        // calc_unit_tests.setExecCmd(&.{
        //     "kcov",
        //     "--exclude-path=/usr/lib/zig/lib",
        //     "kcov-output",
        //     null,
        // });
        // Working version, but may run tests twice
        const lib_unit_tests_run_kcov = b.addSystemCommand(&.{
            "kcov",
            "--exclude-path=/usr/lib/zig/lib/",
            "kcov-output",
        });
        const calc_unit_tests_run_kcov = b.addSystemCommand(&.{
            "kcov",
            "--exclude-path=/usr/lib/zig/lib/",
            "kcov-output",
        });

        lib_unit_tests_run_kcov.addArtifactArg(lib_unit_tests);
        calc_unit_tests_run_kcov.addArtifactArg(calc_unit_tests);

        test_step.dependOn(&lib_unit_tests_run_kcov.step);
        test_step.dependOn(&calc_unit_tests_run_kcov.step);
    } else {
        // Create test run step
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        const run_calc_unit_tests = b.addRunArtifact(calc_unit_tests);
        test_step.dependOn(&run_lib_unit_tests.step);
        test_step.dependOn(&run_calc_unit_tests.step);
    }
}
