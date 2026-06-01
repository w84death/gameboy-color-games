const std = @import("std");

pub fn build(b: *std.Build) void {
    const project_root = b.path(".");

    const render_desert_level = b.addSystemCommand(&[_][]const u8{
        "python3",
        "TOOLS/tmx_to_png.py",
        "../BLUE-LAGOON-SURVIVOR/DOCS/desert_level.tmx",
        "ASSETS/desert_level.png",
    });
    render_desert_level.setCwd(project_root);

    const convert_level = b.addSystemCommand(&[_][]const u8{
        "python3",
        "TOOLS/png_to_level.py",
    });
    convert_level.setCwd(project_root);
    convert_level.step.dependOn(&render_desert_level.step);

    const assemble = b.addSystemCommand(&[_][]const u8{
        "rgbasm",
        "-o",
        "main.o",
        "SRC/main.asm",
    });
    assemble.setCwd(project_root);
    assemble.step.dependOn(&convert_level.step);

    const link = b.addSystemCommand(&[_][]const u8{
        "rgblink",
        "-o",
        "ROM/p1x_gbc_engine.gbc",
        "-m",
        "ROM/p1x_gbc_engine.map",
        "-n",
        "ROM/p1x_gbc_engine.sym",
        "main.o",
    });
    link.setCwd(project_root);
    link.step.dependOn(&assemble.step);

    const cleanup = b.addSystemCommand(&[_][]const u8{
        "rm",
        "main.o",
    });
    cleanup.setCwd(project_root);
    cleanup.step.dependOn(&link.step);

    const fix = b.addSystemCommand(&[_][]const u8{
        "rgbfix",
        "-v",
        "-p",
        "0",
        "-C",
        "-t",
        "P1X BGC Engine",
        "ROM/p1x_gbc_engine.gbc",
    });
    fix.setCwd(project_root);
    fix.step.dependOn(&cleanup.step);

    const stats_cmd = b.addSystemCommand(&[_][]const u8{
        "python3",
        "TOOLS/build_stats.py",
    });
    stats_cmd.setCwd(project_root);
    stats_cmd.step.dependOn(&fix.step);

    const stats = b.step("stats", "Build and print ROM/tile/code size stats");
    stats.dependOn(&stats_cmd.step);

    const run = b.addSystemCommand(&[_][]const u8{
        "mgba",
        "ROM/p1x_gbc_engine.gbc",
    });
    run.setCwd(project_root);
    run.step.dependOn(&stats_cmd.step);

    const emulate = b.step("emulate", "Build and run in mGBA");
    emulate.dependOn(&run.step);

    b.default_step.dependOn(&stats_cmd.step);
}
