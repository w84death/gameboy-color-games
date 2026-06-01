#!/usr/bin/env python3
"""Render a simple Tiled TMX map into a flat PNG.

Supports orthogonal, finite maps with CSV tile layers and external TSX-style
tilesets. This is enough for the 32x32, 8x8 tile maps used by this project.
"""

from __future__ import annotations

import csv
import sys
import xml.etree.ElementTree as ET
from io import StringIO
from pathlib import Path

from PIL import Image

FLIPPED_HORIZONTALLY = 0x80000000
FLIPPED_VERTICALLY = 0x40000000
FLIPPED_DIAGONALLY = 0x20000000
GID_MASK = 0x0FFFFFFF


class Tileset:
    def __init__(self, firstgid: int, source: Path) -> None:
        self.firstgid = firstgid
        self.source = source
        root = ET.parse(source).getroot()
        self.tilewidth = int(root.attrib["tilewidth"])
        self.tileheight = int(root.attrib["tileheight"])
        self.tilecount = int(root.attrib["tilecount"])
        self.columns = int(root.attrib["columns"])

        image = root.find("image")
        if image is None:
            raise SystemExit(f"tileset {source} has no <image>")

        image_path = (source.parent / image.attrib["source"]).resolve()
        self.image = Image.open(image_path).convert("RGBA")

    @property
    def lastgid_exclusive(self) -> int:
        return self.firstgid + self.tilecount

    def has_gid(self, gid: int) -> bool:
        return self.firstgid <= gid < self.lastgid_exclusive

    def tile(self, gid: int) -> Image.Image:
        local = gid - self.firstgid
        x = (local % self.columns) * self.tilewidth
        y = (local // self.columns) * self.tileheight
        return self.image.crop((x, y, x + self.tilewidth, y + self.tileheight))


def parse_csv_data(text: str) -> list[int]:
    reader = csv.reader(StringIO(text.strip()))
    values: list[int] = []
    for row in reader:
        values.extend(int(cell.strip()) for cell in row if cell.strip())
    return values


def apply_tiled_flips(tile: Image.Image, raw_gid: int) -> Image.Image:
    diagonal = bool(raw_gid & FLIPPED_DIAGONALLY)
    horizontal = bool(raw_gid & FLIPPED_HORIZONTALLY)
    vertical = bool(raw_gid & FLIPPED_VERTICALLY)

    # Tiled encodes rotations as combinations of diagonal/horizontal/vertical
    # flips. This follows Tiled's documented transformation order closely
    # enough for orthogonal maps; desert_level.tmx currently only uses H flips.
    if diagonal:
        tile = tile.transpose(Image.Transpose.TRANSPOSE)
    if horizontal:
        tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if vertical:
        tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return tile


def load_tilesets(map_root: ET.Element, map_path: Path) -> list[Tileset]:
    tilesets: list[Tileset] = []
    for tileset_node in map_root.findall("tileset"):
        firstgid = int(tileset_node.attrib["firstgid"])
        source_attr = tileset_node.attrib.get("source")
        if source_attr is None:
            raise SystemExit("embedded tilesets are not supported yet")
        tilesets.append(Tileset(firstgid, (map_path.parent / source_attr).resolve()))
    return sorted(tilesets, key=lambda tileset: tileset.firstgid)


def find_tileset(tilesets: list[Tileset], gid: int) -> Tileset:
    for tileset in reversed(tilesets):
        if tileset.has_gid(gid):
            return tileset
    raise SystemExit(f"no tileset contains gid {gid}")


def render_tmx(map_path: Path, out_path: Path) -> None:
    map_root = ET.parse(map_path).getroot()
    if map_root.attrib.get("orientation") != "orthogonal":
        raise SystemExit("only orthogonal TMX maps are supported")
    if map_root.attrib.get("infinite", "0") != "0":
        raise SystemExit("infinite TMX maps are not supported")

    width = int(map_root.attrib["width"])
    height = int(map_root.attrib["height"])
    tilewidth = int(map_root.attrib["tilewidth"])
    tileheight = int(map_root.attrib["tileheight"])

    canvas = Image.new("RGBA", (width * tilewidth, height * tileheight), (0, 0, 0, 0))
    tilesets = load_tilesets(map_root, map_path)

    for layer in map_root.findall("layer"):
        data = layer.find("data")
        if data is None:
            continue
        if data.attrib.get("encoding") != "csv":
            raise SystemExit("only CSV tile layer data is supported")

        values = parse_csv_data(data.text or "")
        expected = width * height
        if len(values) != expected:
            raise SystemExit(
                f"layer {layer.attrib.get('name', layer.attrib.get('id'))} has {len(values)} gids, expected {expected}"
            )

        for index, raw_gid in enumerate(values):
            gid = raw_gid & GID_MASK
            if gid == 0:
                continue

            tileset = find_tileset(tilesets, gid)
            tile = tileset.tile(gid)
            tile = apply_tiled_flips(tile, raw_gid)

            x = (index % width) * tilewidth
            y = (index // width) * tileheight
            canvas.alpha_composite(tile, (x, y))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path)
    print(f"Rendered {map_path} -> {out_path}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: TOOLS/tmx_to_png.py source.tmx output.png")

    render_tmx(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())


if __name__ == "__main__":
    main()
