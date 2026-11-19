const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/rand48.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "rand48",
        .root_module = root_module,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Pure C application linked with the pure Zig lib as a drop-in
    const lib_tests_c_zig = b.addExecutable(.{
        .name = "test-c-zig",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = false,
        }),
    });
    lib_tests_c_zig.root_module.addCSourceFile(.{
        .file = b.path("src/rand48test.c"),
        .flags = &[_][]const u8{},
    });
    lib_tests_c_zig.root_module.linkLibrary(lib);
    b.installArtifact(lib_tests_c_zig);

    // The same pure C application linked with libc, as a reference implementation
    const lib_tests_c_libc = b.addExecutable(.{
        .name = "test-c-libc",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib_tests_c_libc.root_module.addCSourceFile(.{
        .file = b.path("src/rand48test.c"),
        .flags = &[_][]const u8{},
    });
    b.installArtifact(lib_tests_c_libc);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate HTML documentation");
    docs_step.dependOn(&install_docs.step);

    const lib_tests = b.addTest(.{ .root_module = root_module });
    const install_tests = b.addInstallArtifact(lib_tests, .{});

    const build_test_step = b.step("build-test", "Compile library tests without running");
    build_test_step.dependOn(&install_tests.step);

    const run_tests = b.addRunArtifact(lib_tests);
    const run_test_step = b.step("test", "Run library tests");
    run_test_step.dependOn(&run_tests.step);

    const run_lib_tests_c_libc = b.addRunArtifact(lib_tests_c_libc);
    run_test_step.dependOn(&run_lib_tests_c_libc.step);

    const run_lib_tests_c_zig = b.addRunArtifact(lib_tests_c_zig);
    run_test_step.dependOn(&run_lib_tests_c_zig.step);
}
