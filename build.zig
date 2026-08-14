const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const readismodule_header = b.addTranslateC(.{
        .root_source_file = b.path("src/headers/redismodule.h"),
        .target = target,
        .optimize = optimize,
    });
    const libredismerkle = b.addLibrary(.{
        .name = "redis-merkle",
        .linkage = .dynamic,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "redismodule", .module = readismodule_header.createModule() },
            },
        }),
    });

    b.installArtifact(libredismerkle);
}
