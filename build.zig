const std = @import("std");

pub fn build(b: *std.Build) void {
    // Since Geometry Dash 2.206, the game is now 64-bit
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .windows, .cpu_arch = .x86_64 } });
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "zig-example-gd-mod",
        .root_source_file = b.path("src/entry.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Required for windows headers
    lib.linkLibC();

    lib.addIncludePath(b.path("include/minhook/include"));
    lib.addCSourceFiles(.{ .root = b.path("include/minhook/src"), .files = &.{ "buffer.c", "trampoline.c", "hook.c", "hde/hde32.c", "hde/hde64.c" } });

    b.installArtifact(lib);
}
