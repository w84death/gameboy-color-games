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
        "-m",
        "ROM/p1x_gbc_engine.map",
        "-n",
        "ROM/p1x_gbc_engine.sym",
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

    const report = b.addSystemCommand(&[_][]const u8{
        "python3",
        "-c",
        "import re\nfrom pathlib import Path\nmap_path = Path('ROM/p1x_gbc_engine.map')\nused = 0\nfree = 0\nfor line in map_path.read_text().splitlines():\n    m = re.match(r'\\s*(ROM\\w*):\\s*(\\d+) bytes used / (\\d+) free', line)\n    if m:\n        used += int(m.group(2))\n        free += int(m.group(3))\nif used + free == 0:\n    raise SystemExit('Could not read ROM usage from map file')\ntotal = used + free\npct = (used / total) * 100\nprint(f'ROM used: {used} / {total} bytes ({pct:.2f}%)')\nprint(f'ROM free: {free} bytes')",
    });
    report.step.dependOn(&fix.step);

    const run = b.addSystemCommand(&[_][]const u8{
        "mgba",
        "ROM/p1x_gbc_engine.gbc",
    });
    run.step.dependOn(&report.step);

    const emulate = b.step("emulate", "Build and run in mGBA");
    emulate.dependOn(&run.step);

    b.default_step.dependOn(&report.step);
}
