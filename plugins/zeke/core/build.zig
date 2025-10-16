const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create module for zeke_core
    const core_module = b.addModule("zeke_core", .{
        .root_source_file = b.path("zeke_core.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build tests
    const test_module = b.createModule(.{
        .root_source_file = b.path("zeke_core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run zeke_core tests");
    test_step.dependOn(&run_tests.step);

    _ = core_module; // Module is available for import but doesn't build artifact
}
