/// Heavy inspiration from https://www.ryanliptak.com/blog/fuzzing-zig-code/
/// Run command to fuzz (may not require environment variables on your system):
/// AFL_SKIP_CPUFREQ=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 afl-fuzz -t 5 -x dictionary/InfixEquation.dict -i input -o output -- zig-out/lib/infixEquation_fuzz
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const stack = b.dependency("stack", .{});
    const tokenizer = b.addModule("Tokenizer", .{ .root_source_file = .{ .path = "../src/Tokenizer.zig" } });
    const calculator = b.addModule("Calculator", .{
        .root_source_file = .{ .path = "../src/Calculator.zig" },
    });
    calculator.addImport("Tokenizer", tokenizer);
    calculator.addImport("Stack", stack.module("Stack"));
    const InfixEquationLib = b.addStaticLibrary(.{
        .name = "InfixEquation",
        .root_source_file = .{ .path = "src/InfixEquation.zig" },
        .target = target,
        .optimize = .Debug,
        .pic = true,
    });
    InfixEquationLib.want_lto = true;
    InfixEquationLib.bundle_compiler_rt = true;
    InfixEquationLib.root_module.addImport("Calculator", calculator);

    const InfixEquationLib_install = b.addInstallArtifact(InfixEquationLib, .{});
    const InfixEquationLib_compile = b.addSystemCommand(&.{ "afl-clang-lto", "-o", "zig-out/lib/infixEquation_fuzz" });
    InfixEquationLib_compile.addArtifactArg(InfixEquationLib);

    const fuzz_compile_run = b.step("fuzz", "Build executable for fuzz testing using afl-clang-lto");
    fuzz_compile_run.dependOn(&InfixEquationLib_install.step);
    fuzz_compile_run.dependOn(&InfixEquationLib_compile.step);
}
