# P1X GameBoy Color Engine

## About

I started this project to learn 8-bit assembly. As an x86 assembly programmer I'm starting right from making an actual engne.

## Architecture


## Memory


## Level PNG workflow

The default level is generated from `ASSETS/default_level.png` during `zig build`.
The converter uses `rgbgfx` to emit background tiles, a tile map, an attribute map,
and CGB palettes into `BUILD/generated/`, then writes `SRC/level.inc` for RGBDS.

Limits enforced by the build:
- max 8 CGB background palettes
- max 250 generated background tiles (`0..5` are reserved for the bee sprite)
- max 4 colors per 8x8 tile
- max 256x256 px / 32x32 tiles for the current BG map

If `rgbgfx` reports too many palettes/colors/tiles, reduce the PNG and run
`zig build` again.

## Build & Test

Build .gbc ROM file:
```
zig build
```

Run in mGBA emulator:
```
zig build emulate
```




## Dev Logs

### 05-05-2026 Hello, World
I asked ChatGPT for a simple Hello, World game that will show a custom sprite in the center of the screen.
That project is saved in [HELLO-WORLD](/HELLO-WORLD/) folder.

### 05-05-2026 Engine Beginnings
I started playing with the code, ask for more features. Starting refactoring it. Soon I got few sprites, background terrain, and movable player.
