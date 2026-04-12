const std = @import("std");
const ts = @import("tree_sitter");

const wasm_url = "https://github.com/tree-sitter/tree-sitter-c/releases/download/v0.24.1/tree-sitter-c.wasm";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    const test_deps = b.option(bool, "test-deps", "Fetch test dependencies") orelse false;
    const enable_wasm = b.option(bool, "enable-wasm", "Enable Wasm support") orelse false;
    options.addOption(bool, "enable_wasm", enable_wasm);

    const core = b.dependencyFromBuildZig(ts, .{
        .target = target,
        .optimize = optimize,
        .amalgamated = true,
        .@"build-shared" = false,
        .@"enable-wasm" = enable_wasm,
    });
    const core_lib = core.artifact("tree-sitter");
    const wasmtime = if (enable_wasm)
        core.builder.lazyDependency(ts.wasmtimeDep(target.result), .{})
    else
        null;

    const module = b.addModule("tree_sitter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkLibrary(core_lib);
    module.addOptions("build", options);

    const lib = b.addLibrary(.{
        .name = "zig-tree-sitter",
        .root_module = module,
        .linkage = .static,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Install generated docs");
    docs_step.dependOn(&install_docs.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.linkLibrary(lib);
    test_mod.addOptions("build", options);

    const run_tests = b.addRunArtifact(b.addTest(.{
        .root_module = test_mod,
        .test_runner = .{
            .mode = .simple,
            .path = b.path("test_runner.zig"),
        },
    }));
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    if (wasmtime) |dep| {
        if (target.result.os.tag == .windows) {
            test_mod.linkSystemLibrary("advapi32", .{});
            test_mod.linkSystemLibrary("bcrypt", .{});
            test_mod.linkSystemLibrary("ntdll", .{});
            test_mod.linkSystemLibrary("ole32", .{});
            test_mod.linkSystemLibrary("shell32", .{});
            test_mod.linkSystemLibrary("userenv", .{});
            test_mod.linkSystemLibrary("ws2_32", .{});
        }

        if (target.result.abi != .msvc) {
            test_mod.linkSystemLibrary("unwind", .{ .use_pkg_config = .no });
        }

        if (target.result.os.tag == .windows and target.result.abi != .msvc) {
            const copy_wasmtime = b.addInstallLibFile(dep.path("lib/libwasmtime.a"), "wasmtime.lib");
            lib.step.dependOn(&copy_wasmtime.step);
            module.addLibraryPath(b.path("zig-out/lib"));
            test_mod.addLibraryPath(b.path("zig-out/lib"));
        } else {
            module.addLibraryPath(dep.path("lib"));
            test_mod.addLibraryPath(dep.path("lib"));
        }

        module.linkSystemLibrary("wasmtime", .{
            .use_pkg_config = .no,
            .search_strategy = .no_fallback,
            .preferred_link_mode = .static,
        });
    }

    if (test_deps) {
        const dep = b.lazyDependency("tree_sitter_c", .{
            .target = target,
            .optimize = optimize,
        }) orelse return;
        test_mod.linkLibrary(dep.artifact("tree-sitter-c"));

        if (enable_wasm) {
            const run_curl = b.addSystemCommand(&.{ "curl", "-LSsf", wasm_url, "-o" });
            const wasm_file = run_curl.addOutputFileArg("tree-sitter-c.wasm");
            run_curl.expectExitCode(0);
            run_curl.expectStdErrEqual("");
            test_step.dependOn(&run_curl.step);
            test_mod.addAnonymousImport("tree-sitter-c.wasm", .{
                .root_source_file = wasm_file,
            });
        }
    }
}
