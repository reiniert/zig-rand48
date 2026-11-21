const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/rand48.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // The library itself
    const lib = b.addLibrary(.{
        .name = "rand48",
        .root_module = root_module,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Pure Zig-based functional tests
    const lib_tests_zig = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/zig/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib_tests_zig.root_module.addImport("rand48", root_module);

    // C-based functional tests
    // Windows does not have the rand48 declarations, so add our include file
    const c_flags: []const []const u8 = if (target.result.os.tag == .windows)
        &[_][]const u8{ "-include", "test/c/rand48.h" }
    else
        &[_][]const u8{};

    // OpenGroup C example linked with the pure Zig lib as a drop-in
    const lib_tests_c_opengroup = b.addExecutable(.{
        .name = "test-c-opengroup",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib_tests_c_opengroup.root_module.addCSourceFile(.{
        .file = b.path("test/c/test_opengroup.c"),
        .flags = c_flags,
    });
    lib_tests_c_opengroup.root_module.linkLibrary(lib);
    b.installArtifact(lib_tests_c_opengroup);

    // Glibc test linked with the pure Zig lib as a drop-in
    const lib_tests_c_glibc = b.addExecutable(.{
        .name = "test-c-glibc",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib_tests_c_glibc.root_module.addCSourceFile(.{
        .file = b.path("test/c/test_glibc.c"),
        .flags = c_flags,
    });
    lib_tests_c_glibc.root_module.linkLibrary(lib);
    b.installArtifact(lib_tests_c_glibc);

    // Burkardt test linked with the pure Zig lib as a drop-in
    const lib_tests_c_burkardt = b.addExecutable(.{
        .name = "test-c-burkardt",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib_tests_c_burkardt.root_module.addCSourceFile(.{
        .file = b.path("test/c/test_burkardt.c"),
        .flags = c_flags,
    });
    lib_tests_c_burkardt.root_module.linkLibrary(lib);
    b.installArtifact(lib_tests_c_burkardt);

    const lib_tests = b.addTest(.{ .root_module = root_module });
    const install_tests = b.addInstallArtifact(lib_tests, .{});

    const build_test_step = b.step("build-test", "Compile library tests without running");
    build_test_step.dependOn(&install_tests.step);

    const run_zig_tests = b.addRunArtifact(lib_tests_zig);
    const run_all_tests_step = b.step("test", "Run all library tests");
    run_all_tests_step.dependOn(&run_zig_tests.step);

    const run_lib_tests_c_opengroup = b.addRunArtifact(lib_tests_c_opengroup);
    run_all_tests_step.dependOn(&run_lib_tests_c_opengroup.step);

    const run_lib_tests_c_glibc = b.addRunArtifact(lib_tests_c_glibc);
    run_all_tests_step.dependOn(&run_lib_tests_c_glibc.step);

    const run_lib_tests_c_burkardt = b.addRunArtifact(lib_tests_c_burkardt);
    // Tell the run step to capture stdout and assert it matches the expected file contents
    run_lib_tests_c_burkardt.expectStdOutEqual(@embedFile("test/c/test_burkardt.txt"));
    run_all_tests_step.dependOn(&run_lib_tests_c_burkardt.step);

    // Documentation generation
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate HTML documentation");
    docs_step.dependOn(&install_docs.step);
}
