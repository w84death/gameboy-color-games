#!/usr/bin/env python3
"""Print ROM usage stats for the RGBDS build."""

from __future__ import annotations

import re
from pathlib import Path

ROM_SIZE_BYTES = 32 * 1024
BANK_SIZE_BYTES = 16 * 1024
ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = ROOT / "ROM" / "p1x_gbc_engine.map"
SYM_PATH = ROOT / "ROM" / "p1x_gbc_engine.sym"
ROM_PATH = ROOT / "ROM" / "p1x_gbc_engine.gbc"


def fmt_bytes(value: int) -> str:
    return f"{value} bytes ({value / 1024:.2f} KiB)"


def parse_rom_summary() -> tuple[int, int]:
    used = 0
    free_in_linked_banks = 0
    summary_re = re.compile(r"\s*(ROM\w*):\s*(\d+) bytes used / (\d+) free")

    for line in MAP_PATH.read_text(encoding="utf-8").splitlines():
        match = summary_re.match(line)
        if match:
            used += int(match.group(2))
            free_in_linked_banks += int(match.group(3))

    if used + free_in_linked_banks == 0:
        raise SystemExit(f"Could not read ROM usage from {MAP_PATH}")

    return used, free_in_linked_banks


def symbol_absolute_addr(bank: int, addr: int) -> int:
    if bank == 0:
        return addr
    return bank * BANK_SIZE_BYTES + (addr - BANK_SIZE_BYTES)


def parse_symbols() -> dict[str, int]:
    symbols: dict[str, int] = {}
    symbol_re = re.compile(r"([0-9a-fA-F]{2}):([0-9a-fA-F]{4})\s+(.+)")

    for line in SYM_PATH.read_text(encoding="utf-8").splitlines():
        match = symbol_re.fullmatch(line.strip())
        if not match:
            continue
        bank = int(match.group(1), 16)
        addr = int(match.group(2), 16)
        name = match.group(3)
        symbols[name] = symbol_absolute_addr(bank, addr)

    return symbols


def range_size(symbols: dict[str, int], start_label: str) -> int | None:
    end_label = f"{start_label}End"
    if start_label not in symbols or end_label not in symbols:
        return None
    return symbols[end_label] - symbols[start_label]


def collect_ranges(
    symbols: dict[str, int], suffixes: tuple[str, ...]
) -> list[tuple[str, int]]:
    ranges: list[tuple[str, int]] = []
    for label in symbols:
        if "." in label or label.endswith("End"):
            continue
        if not label.endswith(suffixes):
            continue
        size = range_size(symbols, label)
        if size is not None and size >= 0:
            ranges.append((label, size))
    return sorted(ranges)


def print_group(
    title: str, ranges: list[tuple[str, int]], show_tile_count: bool = False
) -> int:
    total = sum(size for _, size in ranges)
    print(f"{title}: {fmt_bytes(total)}")
    for label, size in ranges:
        extra = f" / {size // 16} tiles" if show_tile_count else ""
        print(f"  {label}: {size} bytes{extra}")
    return total


def main() -> None:
    rom_used, linked_bank_free = parse_rom_summary()
    symbols = parse_symbols()

    tile_ranges = collect_ranges(symbols, ("Tiles",))
    map_ranges = collect_ranges(symbols, ("TileMap", "AttrMap"))
    palette_ranges = collect_ranges(symbols, ("Palettes",))

    tile_bytes = sum(size for _, size in tile_ranges)
    level_map_bytes = sum(size for _, size in map_ranges)
    palette_bytes = sum(size for _, size in palette_ranges)
    asset_bytes = tile_bytes + level_map_bytes + palette_bytes
    code_bytes = max(0, rom_used - asset_bytes)
    rom_free_32k = ROM_SIZE_BYTES - rom_used
    rom_file_size = ROM_PATH.stat().st_size if ROM_PATH.exists() else 0

    print("\nBuild stats")
    print("===========")
    print(f"ROM budget: {fmt_bytes(ROM_SIZE_BYTES)}")
    print(f"ROM file size after rgbfix: {fmt_bytes(rom_file_size)}")
    print(
        f"ROM used: {fmt_bytes(rom_used)} ({rom_used / ROM_SIZE_BYTES * 100:.2f}% of 32 KiB)"
    )
    print(f"Space left for 32 KiB ROM: {fmt_bytes(rom_free_32k)}")
    print(f"Free in linked RGBDS ROM banks: {fmt_bytes(linked_bank_free)}")
    print()
    print(f"Code/header size: {fmt_bytes(code_bytes)}")
    print_group("Tileset graphics size", tile_ranges, show_tile_count=True)
    print_group("Tile/attribute map size", map_ranges)
    print_group("Palette data size", palette_ranges)
    print(f"Total detected asset data: {fmt_bytes(asset_bytes)}")


if __name__ == "__main__":
    main()
