const std = @import("std");

pub fn build(b: *std.Build) void {
    const assemble = b.addSystemCommand(&[_][]const u8{
        "rgbasm",
        "-o",
        "main.o",
        "SRC/main.asm",
    });

    const link = b.addSystemCommand(&[_][]const u8{
        "rgblink",
        "-o",
        "ROM/p1x_gbc_engine.gbc",
        "main.o",
    });
    link.step.dependOn(&assemble.step);

    const cleanup = b.addSystemCommand(&[_][]const u8{
        "rm",
        "main.o",
    });
    cleanup.step.dependOn(&link.step);

    const fix = b.addSystemCommand(&[_][]const u8{
        "rgbfix",
        "-v",
        "-p",
        "0",
        "-C",
        "ROM/p1x_gbc_engine.gbc",
    });
    fix.step.dependOn(&cleanup.step);

    const run = b.addSystemCommand(&[_][]const u8{
        "mgba",
        "ROM/p1x_gbc_engine.gbc",
    });
    run.step.dependOn(&fix.step);

    const emulate = b.step("emulate", "Build and run in mGBA");
    emulate.dependOn(&run.step);

    b.default_step.dependOn(&fix.step);
}
