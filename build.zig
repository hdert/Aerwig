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
        const zig_triple = try t.zigTriple(b.allocator);
        const exe = b.addExecutable(.{
            .name = try std.fmt.allocPrint(b.allocator, "Calculator-{s}", .{zig_triple}),
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
                    .custom = zig_triple,
                },
            },
        });
        b.getInstallStep().dependOn(&target_output.step);
    }

    // Creating Native build and Native build step

    const native_exe = b.addExecutable(.{
        .name = "Calculator",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    native_exe.root_module.addImport("Io", io);
    native_exe.root_module.addImport("Addons", addons);
    native_exe.root_module.addImport("Calculator", calculator);
    const native_exe_output = b.addInstallArtifact(native_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = try target.query.zigTriple(b.allocator),
            },
        },
    });
    b.getInstallStep().dependOn(&native_exe_output.step);
    const native_build_step = b.step("native", "Build only the native executable");
    native_build_step.dependOn(&native_exe_output.step);

    // Creating executable run step

    const run_cmd = b.addRunArtifact(native_exe);
    run_cmd.step.dependOn(&native_exe_output.step);

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
        const clear_kcov_output = if (@import("builtin").os.tag == .windows) b.addSystemCommand(&.{
            "rmdir",
            "/s",
            "kcov-output",
        }) else b.addSystemCommand(&.{
            "rm",
            "-r",
            "kcov-output",
        });
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

        lib_unit_tests_run_kcov.step.dependOn(&clear_kcov_output.step);
        calc_unit_tests_run_kcov.step.dependOn(&clear_kcov_output.step);

        test_step.dependOn(&lib_unit_tests_run_kcov.step);
        test_step.dependOn(&calc_unit_tests_run_kcov.step);
    } else {
        // Create test run step
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        const run_calc_unit_tests = b.addRunArtifact(calc_unit_tests);
        test_step.dependOn(&run_lib_unit_tests.step);
        test_step.dependOn(&run_calc_unit_tests.step);
    }

    // Create Fuzzing step
    // Heavy inspiration from https://www.ryanliptak.com/blog/fuzzing-zig-code/

    const InfixEquationFuzzer = b.addStaticLibrary(.{
        .name = "InfixEquationFuzzer",
        .root_source_file = .{ .path = "fuzzers/src/InfixEquation.zig" },
        .target = target,
        .optimize = .Debug,
        .pic = true,
    });
    InfixEquationFuzzer.want_lto = true;
    InfixEquationFuzzer.bundle_compiler_rt = true;
    InfixEquationFuzzer.root_module.addImport("Calculator", calculator);

    const InfixEquationFuzzer_install = b.addInstallArtifact(InfixEquationFuzzer, .{});
    const InfixEquationFuzzer_compile = b.addSystemCommand(&.{ "afl-clang-lto", "-o", "zig-out/lib/infixEquationFuzzer" });
    InfixEquationFuzzer_compile.addArtifactArg(InfixEquationFuzzer);
    InfixEquationFuzzer_compile.step.dependOn(&InfixEquationFuzzer_install.step);

    const fuzz_compile = b.step("fuzz", "Build executables for fuzz testing using afl-clang-lto");
    fuzz_compile.dependOn(&InfixEquationFuzzer_compile.step);

    // Create Fuzzing Run step

    const InfixEquationFuzzer_run = b.addSystemCommand(&.{
        "afl-fuzz",
        "-t",
        "5",
        "-x",
        "fuzzers/dictionary/InfixEquation.dict",
        "-i",
        "fuzzers/input",
        "-o",
        "afl-output",
        "--",
        "zig-out/lib/infixEquationFuzzer",
    });
    InfixEquationFuzzer_run.setEnvironmentVariable("AFL_SKIP_CPUFREQ", "1");
    InfixEquationFuzzer_run.setEnvironmentVariable("AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES", "1");
    InfixEquationFuzzer_run.step.dependOn(&InfixEquationFuzzer_compile.step);

    const fuzz_run = b.step("fuzz-run", "Build executables for fuzz testing using afl-clang-lto, then run them with afl++");
    fuzz_run.dependOn(&InfixEquationFuzzer_run.step);

    // Create Graph Creation Step

    const fuzz_graph_cmd = b.addSystemCommand(&.{
        "afl-plot",
        "afl-output/default/",
        "afl-graph-output/",
    });

    const fuzz_graph = b.step("fuzz-graph", "Graph the results of running the fuzzer");
    fuzz_graph.dependOn(&fuzz_graph_cmd.step);

    // Example

    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .path = "src/example.zig" },
        .target = target,
        .optimize = optimize,
    });
    example_exe.root_module.addImport("Calculator", calculator);
    example_exe.root_module.addImport("Addons", addons);
    const example_install = b.addInstallArtifact(example_exe, .{});

    b.getInstallStep().dependOn(&example_install.step);
}
