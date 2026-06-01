#!/usr/bin/env python3
"""Convert PNG level maps into RGBDS include data.

The engine reserves tile IDs 0..5 for the bee sprite, so background tiles are
emitted with tile IDs starting at 6. The current renderer uses one 32x32 BG map,
so source images are padded to a full 256x256-pixel map after conversion.
"""

from __future__ import annotations

import math
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "BUILD" / "generated"
INC_PATH = ROOT / "SRC" / "level.inc"

BG_TILE_BASE = 6
MAX_BG_TILES = 256 - BG_TILE_BASE
MAX_BG_PALETTES = 8
MAP_WIDTH_TILES = 32
MAP_HEIGHT_TILES = 32
TILE_SIZE = 8
PALETTE_BYTES = MAX_BG_PALETTES * 4 * 2

LEVELS = (
    ("GrasslandLevel", ROOT / "ASSETS" / "grassland_level.png", "grassland_level"),
    ("DesertLevel", ROOT / "ASSETS" / "desert_level.png", "desert_level"),
)


@dataclass(frozen=True)
class ConvertedLevel:
    label_prefix: str
    source_png: Path
    tiles: Path
    tilemap: Path
    attrmap: Path
    palettes: Path
    width_tiles: int
    height_tiles: int
    tile_count: int


def rel(path: Path) -> str:
    path = path.resolve()
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def resolve_source_path(raw_path: str) -> Path:
    path = Path(raw_path)
    if path.is_absolute():
        return path.resolve()

    cwd_path = (Path.cwd() / path).resolve()
    if cwd_path.exists():
        return cwd_path

    return (ROOT / path).resolve()


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalize_png(source: Path, dest: Path) -> tuple[int, int]:
    if not source.exists():
        fail(
            f"missing source PNG: {rel(source)}\n"
            "Put your level image there, or pass PNG paths to TOOLS/png_to_level.py."
        )

    image = Image.open(source).convert("RGBA")
    width, height = image.size
    if width <= 0 or height <= 0:
        fail(f"{rel(source)} is empty")
    if width > MAP_WIDTH_TILES * TILE_SIZE or height > MAP_HEIGHT_TILES * TILE_SIZE:
        fail(
            f"{rel(source)} is {width}x{height}px, but the current BG map supports at most "
            f"{MAP_WIDTH_TILES * TILE_SIZE}x{MAP_HEIGHT_TILES * TILE_SIZE}px."
        )

    padded_width = math.ceil(width / TILE_SIZE) * TILE_SIZE
    padded_height = math.ceil(height / TILE_SIZE) * TILE_SIZE
    width_tiles = padded_width // TILE_SIZE
    height_tiles = padded_height // TILE_SIZE

    if (padded_width, padded_height) != image.size:
        fill = image.getpixel((0, 0))
        padded = Image.new("RGBA", (padded_width, padded_height), fill)
        padded.paste(image, (0, 0))
        image = padded

    image.save(dest)
    return width_tiles, height_tiles


def explain_rgbgfx_error(output: str) -> None:
    for line in output.splitlines():
        marker = "Tile at ("
        if marker not in line:
            continue
        try:
            coords = line.split(marker, 1)[1].split(")", 1)[0]
            x_text, y_text = coords.split(",", 1)
            x = int(x_text.strip())
            y = int(y_text.strip())
        except (IndexError, ValueError):
            continue

        print(
            f"note: rgbgfx reports pixel coordinates. ({x}, {y}) is the top-left "
            f"pixel of tile ({x // TILE_SIZE}, {y // TILE_SIZE}); inspect pixels "
            f"x={x}..{x + TILE_SIZE - 1}, y={y}..{y + TILE_SIZE - 1}.",
            file=sys.stderr,
        )


def run_rgbgfx(
    source: Path, tiles: Path, tilemap: Path, attrmap: Path, palettes: Path
) -> None:
    cmd = [
        "rgbgfx",
        "-u",
        "-b",
        str(BG_TILE_BASE),
        "-N",
        str(MAX_BG_TILES),
        "-n",
        str(MAX_BG_PALETTES),
        "-o",
        str(tiles),
        "-t",
        str(tilemap),
        "-a",
        str(attrmap),
        "-p",
        str(palettes),
        str(source),
    ]
    result = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    if result.returncode == 0:
        return

    combined_output = result.stdout + result.stderr
    print("rgbgfx failed while converting a level PNG.", file=sys.stderr)
    print(
        f"Limits: max {MAX_BG_PALETTES} BG palettes, max {MAX_BG_TILES} BG tiles, "
        "max 4 colors per 8x8 tile.",
        file=sys.stderr,
    )
    print("Reduce the PNG/tileset and run `zig build` again.", file=sys.stderr)
    explain_rgbgfx_error(combined_output)
    if result.stdout:
        print(result.stdout, file=sys.stderr, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    raise SystemExit(result.returncode)


def pad_map(
    source_map: Path, dest_map: Path, width_tiles: int, height_tiles: int, fill: int
) -> None:
    data = source_map.read_bytes()
    expected = width_tiles * height_tiles
    if len(data) != expected:
        fail(f"{rel(source_map)} is {len(data)} bytes, expected {expected}")

    output = bytearray([fill] * (MAP_WIDTH_TILES * MAP_HEIGHT_TILES))
    for y in range(height_tiles):
        src_start = y * width_tiles
        dst_start = y * MAP_WIDTH_TILES
        output[dst_start : dst_start + width_tiles] = data[
            src_start : src_start + width_tiles
        ]
    dest_map.write_bytes(output)


def pad_palettes(path: Path) -> None:
    data = path.read_bytes()
    if len(data) > PALETTE_BYTES:
        fail(
            f"{rel(path)} contains {len(data) // 8} palettes; "
            f"the CGB BG limit is {MAX_BG_PALETTES}."
        )
    path.write_bytes(data + bytes(PALETTE_BYTES - len(data)))


def convert_level(
    label_prefix: str, source_png: Path, file_prefix: str
) -> ConvertedLevel:
    normalized_png = OUT_DIR / f"{file_prefix}.normalized.png"
    raw_tiles = OUT_DIR / f"{file_prefix}.2bpp"
    raw_tilemap = OUT_DIR / f"{file_prefix}.raw.tilemap"
    raw_attrmap = OUT_DIR / f"{file_prefix}.raw.attrmap"
    palettes = OUT_DIR / f"{file_prefix}.pal"
    padded_tilemap = OUT_DIR / f"{file_prefix}.tilemap"
    padded_attrmap = OUT_DIR / f"{file_prefix}.attrmap"

    width_tiles, height_tiles = normalize_png(source_png, normalized_png)
    run_rgbgfx(normalized_png, raw_tiles, raw_tilemap, raw_attrmap, palettes)

    first_tile = (
        raw_tilemap.read_bytes()[0] if raw_tilemap.stat().st_size else BG_TILE_BASE
    )
    first_attr = raw_attrmap.read_bytes()[0] if raw_attrmap.stat().st_size else 0
    pad_map(raw_tilemap, padded_tilemap, width_tiles, height_tiles, first_tile)
    pad_map(raw_attrmap, padded_attrmap, width_tiles, height_tiles, first_attr)
    pad_palettes(palettes)

    return ConvertedLevel(
        label_prefix=label_prefix,
        source_png=source_png,
        tiles=raw_tiles,
        tilemap=padded_tilemap,
        attrmap=padded_attrmap,
        palettes=palettes,
        width_tiles=width_tiles,
        height_tiles=height_tiles,
        tile_count=raw_tiles.stat().st_size // 16,
    )


def include_for(level: ConvertedLevel) -> str:
    prefix = level.label_prefix
    return (
        f"; Source PNG: {rel(level.source_png)}\n"
        f"DEF {prefix.upper()}_WIDTH_TILES EQU {level.width_tiles}\n"
        f"DEF {prefix.upper()}_HEIGHT_TILES EQU {level.height_tiles}\n"
        f"DEF {prefix.upper()}_BG_TILE_COUNT EQU {level.tile_count}\n\n"
        f"{prefix}Tiles:\n"
        f'    INCBIN "{rel(level.tiles)}"\n'
        f"{prefix}TilesEnd:\n\n"
        f"{prefix}TileMap:\n"
        f'    INCBIN "{rel(level.tilemap)}"\n'
        f"{prefix}TileMapEnd:\n\n"
        f"{prefix}AttrMap:\n"
        f'    INCBIN "{rel(level.attrmap)}"\n'
        f"{prefix}AttrMapEnd:\n\n"
        f"{prefix}BgPalettes:\n"
        f'    INCBIN "{rel(level.palettes)}"\n'
        f"{prefix}BgPalettesEnd:\n\n"
        f"{prefix}Descriptor:\n"
        f"    DW {prefix}BgPalettes, {prefix}BgPalettesEnd\n"
        f"    DW {prefix}Tiles, {prefix}TilesEnd\n"
        f"    DW {prefix}TileMap, {prefix}TileMapEnd\n"
        f"    DW {prefix}AttrMap, {prefix}AttrMapEnd\n"
    )


def write_include(levels: tuple[ConvertedLevel, ...]) -> None:
    content = (
        "; This file is generated by TOOLS/png_to_level.py. Do not edit by hand.\n\n"
        f"DEF LEVEL_MAP_WIDTH_TILES EQU {MAP_WIDTH_TILES}\n"
        f"DEF LEVEL_MAP_HEIGHT_TILES EQU {MAP_HEIGHT_TILES}\n"
        f"DEF LEVEL_BG_TILE_BASE EQU {BG_TILE_BASE}\n\n"
    )
    content += "\n\n".join(include_for(level) for level in levels)
    content += "\n"
    INC_PATH.write_text(content, encoding="utf-8")


def requested_levels() -> tuple[tuple[str, Path, str], ...]:
    if len(sys.argv) == 1:
        return LEVELS
    if len(sys.argv) != 3:
        fail(
            "usage: TOOLS/png_to_level.py [grassland_level.png desert_level.png]\n"
            "The build uses ASSETS/grassland_level.png and ASSETS/desert_level.png."
        )
    return (
        ("GrasslandLevel", resolve_source_path(sys.argv[1]), "grassland_level"),
        ("DesertLevel", resolve_source_path(sys.argv[2]), "desert_level"),
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    levels = tuple(
        convert_level(label, source.resolve(), prefix)
        for label, source, prefix in requested_levels()
    )
    write_include(levels)

    for level in levels:
        print(
            f"Generated {level.label_prefix} from {rel(level.source_png)} "
            f"({level.width_tiles}x{level.height_tiles} tiles, {level.tile_count} unique BG tiles)."
        )
    print(f"Wrote {rel(INC_PATH)}.")


if __name__ == "__main__":
    main()
