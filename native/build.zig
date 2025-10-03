const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "possess",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    lib.linker_allow_shlib_undefined = true;

    // Add Node.js headers from environment variable or default
    const node_include_path = b.graph.env_map.get("NODE_INCLUDE_PATH") orelse
        b.graph.env_map.get("NODE_INCLUDE_DIR") orelse
        "/usr/local/include/node";
    lib.addIncludePath(.{ .cwd_relative = node_include_path });

    // Add ghostty as a module dependency
    const ghostty = b.dependency("ghostty", .{
        .target = target,
        .optimize = optimize,
    });

    // Import the ghostty module
    lib_mod.addImport("ghostty", ghostty.module("ghostty-vt"));

    b.installArtifact(lib);

    // Test step
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("ghostty", ghostty.module("ghostty-vt"));

    const tests = b.addTest(.{
        .root_module = test_mod,
    });
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
