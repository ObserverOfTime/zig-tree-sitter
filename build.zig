const std = @import("std");
const ts = @import("tree_sitter");

const wasm_url = "https://github.com/tree-sitter/tree-sitter-c/releases/download/v0.24.1/tree-sitter-c.wasm";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
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
    const wasmtime = if (enable_wasm) core.builder.lazyDependency(ts.wasmtimeDep(target.result), .{}) else null;

    const module = b.addModule("tree_sitter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkLibrary(core_lib);
    module.addOptions("build", options);
    if (wasmtime) |dep| {
        module.addLibraryPath(dep.path("lib"));
        module.linkSystemLibrary("wasmtime", .{
            .preferred_link_mode = .static,
        });
    }

    const docs = b.addObject(.{
        .name = "tree_sitter",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .Debug,
    });
    docs.root_module.addOptions("build", options);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Install generated docs");
    docs_step.dependOn(&install_docs.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibrary(core_lib);
    tests.root_module.addOptions("build", options);
    if (wasmtime) |dep| {
        tests.root_module.addLibraryPath(dep.path("lib"));
        tests.root_module.linkSystemLibrary("wasmtime", .{
            .preferred_link_mode = .static,
        });
        tests.root_module.linkSystemLibrary("unwind", .{});
        if (target.result.os.tag == .windows) {
            if (target.result.abi != .msvc) {
                tests.root_module.linkSystemLibrary("unwind", .{});
                tests.root_module.linkSystemLibrary("advapi32", .{});
                tests.root_module.linkSystemLibrary("bcrypt", .{});
                tests.root_module.linkSystemLibrary("ntdll", .{});
                tests.root_module.linkSystemLibrary("ole32", .{});
                tests.root_module.linkSystemLibrary("shell32", .{});
                tests.root_module.linkSystemLibrary("userenv", .{});
                tests.root_module.linkSystemLibrary("ws2_32", .{});
            } else {
                const fail = b.addFail("FIXME: cannot build with enable-wasm for MSVC");
                tests.step.dependOn(&fail.step);
            }
        }
    }

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // HACK: fetch tree-sitter-c only for tests (ziglang/zig#19914)
    var args = try std.process.argsWithAllocator(b.allocator);
    defer args.deinit();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "test")) {
            const dep = b.lazyDependency("tree_sitter_c", .{
                .target = target,
                .optimize = optimize,
            }) orelse continue;
            tests.linkLibrary(dep.artifact("tree-sitter-c"));

            if (enable_wasm) {
                // FIXME: prevent the file from being downloaded multiple times
                std.log.info("Downloading {s}\n", .{ wasm_url });
                const run_curl = b.addSystemCommand(&.{"curl", "-LSsf", wasm_url, "-o"});
                const wasm_file = run_curl.addOutputFileArg("tree-sitter-c.wasm");
                run_curl.expectStdErrEqual("");
                tests.step.dependOn(&run_curl.step);
                tests.root_module.addAnonymousImport("tree-sitter-c.wasm", .{
                    .root_source_file = wasm_file,
                });
            }

            break;
        }
    }
}
