; ==========================================================================|80|
; Hello, World GameBoy Color Game
; by Krzysztof Krystian Jankowski
; smol.p1x.in/assembly/
; https://github.com/w84death/gameboy-color-games
; ==========================================================================|80|

; ======================================> GBC REGISTERS <===================|80|
INCLUDE "gbc_regs.inc"
; ==========================================================================|80|

; ======================================> GAME CONSTANTS  <=================|80|
DEF DPAD_RIGHT_BIT                      EQU $0000
DEF DPAD_LEFT_BIT                       EQU $0001
DEF DPAD_UP_BIT                         EQU $0002
DEF DPAD_DOWN_BIT                       EQU $0003
DEF SPRITE_TILE_ADDR                    EQU $8000
DEF BG_TILE_ADDR                        EQU $8000
DEF BG_MAP_ADDR                         EQU $9800

DEF TREE_COUNT                          EQU 24
DEF SPRITE_X_CENTER                     EQU 80 + 8
DEF SPRITE_Y_CENTER                     EQU 72 + 8
DEF PLAYER_ANIM_DELAY                   EQU 4
DEF TREE_FIRST_SLOT                     EQU 0
DEF PLAYER_SLOT                         EQU TREE_COUNT + 5
DEF PLAYER_OAM_ADDR                     EQU _OAMRAM + PLAYER_SLOT * 4

DEF TREE_TILE_A                         EQU 2
DEF TREE_TILE_B                         EQU 3
DEF TILES_BG_INDEX_START                EQU 4
DEF PAL_TREE                            EQU 0
DEF PAL_GROUND                          EQU 0
; ==========================================================================|80|

; ======================================> HEADER DATA <=====================|80|
SECTION "Header", ROM0[$100]
  nop
  jp Entry
  ds $150 - @, 0
; ==========================================================================|80|

; ======================================> WRAM DATA <=======================|80|
SECTION "WRAM Data", WRAM0
RandomSeed:
  ds 1
FrameCounter:
  ds 1
PlayerAnimTimer:
  ds 1
PlayerAnimFrame:
  ds 1   ; 0 or 1
; ==========================================================================|80|

; ======================================> MAIN SECTION <====================|80|
SECTION "Main", ROM0[$150]

Entry:
  di                                    ; disable interrups
  call WaitVBlank

  xor a
  ld [rLCDC], a

  ld a, [rDIV]
  or $01                                ; avoid zero
  ld [RandomSeed], a

  xor a
  ld [FrameCounter], a
  ld [PlayerAnimFrame], a

  ld a, PLAYER_ANIM_DELAY
  ld [PlayerAnimTimer], a

  ; VRAM bank 0
  xor a
  ld [rVBK], a

  ; Clear _OAMRAM
  ld hl, _OAMRAM
  ld b, 160
  .clear_oam
    xor a
    ld [hli], a
    dec b
    jr nz, .clear_oam

  .load_sprite_tiles
    ld hl, GameTiles
    ld de, SPRITE_TILE_ADDR
    ld bc, GameTilesEnd - GameTiles
    call LoadBytes

  .load_palettes
    ld a, [DMGObjPalette0]
    ld [rOBP0], a

    ld hl, CGBObjPalettes
    ld b, CGBObjPalettesEnd - CGBObjPalettes
    call LoadObjPalettesCGB

  .load_bg_palettes
    ld hl, CGBBgPalettes
    ld b, CGBBgPalettesEnd - CGBBgPalettes
    call LoadBgPalettesCGB

  call GenerateTerrain
  call InitPlayer
  call GenerateForest

  .turn_lcd_on
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000 | LCDCF_BG9800
  ld [rLCDC], a

; ======================================> MAIN LOOP <=======================|80|
MainLoop:
  call WaitVBlank
  call HandleDPad
  call AnimatePlayer
  jr MainLoop

; ==========================================================================|80|



; ======================================> PROCEDURES <======================|80|
WaitVBlank:
  .wait_vblank
  ld a, [rLY]
  cp 144
  jr c, .wait_vblank
  .wait_vblank_end
    ld a, [rLY]
    cp 144
    jr nc, .wait_vblank_end
  ret

RandomByte:
  ; Very simple 8-bit pseudo-random generator
  ld a, [RandomSeed]
  ld b, a

  ld a, [rDIV]
  xor b
  add $3D
  xor $A7
  rlca

  ld [RandomSeed], a
  ret

LoadBytes:
  ; Copies BC bytes from HL to DE
  ; input:
  ;   HL = source
  ;   DE = destination
  ;   BC = byte count
.copy
  ld a, b
  or c
  ret z

  ld a, [hli]
  ld [de], a
  inc de
  dec bc
  jr .copy
ret

LoadBgPalettesCGB:
  ld a, $80
  ld [rBGPI], a

  .copy
    ld a, b
    or a
    ret z

    ld a, [hli]
    ld [rBGPD], a
    dec b
    jr .copy
  ret

LoadObjPalettesCGB:
  ; Loads CGB OBJ palette bytes using auto-increment.
  ; input:
  ;   HL = palette data
  ;   B  = byte count
  ;
  ; Supports multiple palettes packed together.
  ; 1 palette = 8 bytes = 4 colors.

  ld a, $80
  ld [rOBPI], a

.copy
  ld a, b
  or a
  ret z

  ld a, [hli]
  ld [rOBPD], a
  dec b
  jr .copy
ret

LoadObjPaletteCGB:
  ; Loads CGB OBJ palette bytes using auto-increment
  ; input:
  ;   HL = palette data
  ;   B  = byte count
  ld a, $80
  ld [rOBPI], a

.copy
  ld a, b
  or a
  ret z

  ld a, [hli]
  ld [rOBPD], a
  dec b
  jr .copy
ret

WaitForAnyDPad:
  .wait
    call ReadDPad
    cp %00001111       ; no d-pad pressed
    jr z, .wait
  ret

HandleDPad:
  call ReadDPad
  bit DPAD_RIGHT_BIT, a
  call z, MoveRight
  bit DPAD_LEFT_BIT, a
  call z, MoveLeft
  bit DPAD_UP_BIT, a
  call z, MoveUp
  bit DPAD_DOWN_BIT, a
  call z, MoveDown
  ret

ReadDPad:
  ld a, %00100000     ; select d-pad buttons
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]         ; read twice for stability
  and %00001111       ; clean hiher bits to leave only buttons information
  ret

MoveRight:
  ld hl, PLAYER_OAM_ADDR + 1  ; sprite X
  inc [hl]
  ret

MoveLeft:
  ld hl, PLAYER_OAM_ADDR + 1
  dec [hl]
  ret

MoveUp:
  ld hl, PLAYER_OAM_ADDR      ; sprite Y
  dec [hl]
  ret

MoveDown:
  ld hl, PLAYER_OAM_ADDR
  inc [hl]
  ret

AnimatePlayer:
  .update_timer:
    ld a, [PlayerAnimTimer]
    dec a
    ld [PlayerAnimTimer], a
    jr nz, .done

  .reset_timer:
    ld a, PLAYER_ANIM_DELAY
    ld [PlayerAnimTimer], a

  .swap_frames:
    ld a, [PlayerAnimFrame]
    xor 1
    ld [PlayerAnimFrame], a

  .apply_tile:
  ld hl, PLAYER_OAM_ADDR + 2
  ld [hl], a

.done
  ret

InitPlayer:
  ld hl, PLAYER_OAM_ADDR                ; sprite slot
  ld a, SPRITE_Y_CENTER                 ; Y pos
  ld [hli], a
  ld a, SPRITE_X_CENTER                 ; X pos
  ld [hli], a
  ld a, [PlayerAnimFrame]               ; current animation frame
  ld [hli], a
  ld a, 1                               ; palette
  ld [hli], a
  ret

GenerateTerrain:
  xor a
  ld [rVBK], a
  ld hl, BG_MAP_ADDR
  ld bc, 32 * 32

  .next_tile
    call RandomByte
    and %00000011                       ; get 0..3
    cp 3
    jr nz, .valid
    xor a                               ; convert 3 to 0
  .valid
    add a, TILES_BG_INDEX_START         ; convert to tiles IDs
    ld [hli], a

    dec bc
    ld a, b
    or c
    jr nz, .next_tile

    ret

GenerateForest:
  ld hl, _OAMRAM + TREE_FIRST_SLOT * 4
  ld c, TREE_COUNT

  .next_tree
    ; random Y: 24..127
    call RandomByte
    and %01111111
    add 24
    ld [hli], a

    ; random X: 8..167
    call RandomByte
    and %01111111
    add 8
    ld [hli], a

    ; random tile: TREE_TILE_A or TREE_TILE_B
    call RandomByte
    and 1
    jr z, .tile_a

  .tile_b
    ld a, TREE_TILE_B
    jr .write_tile

  .tile_a
    ld a, TREE_TILE_A

  .write_tile
    ld [hli], a

    ; palette 0
    ld a, PAL_TREE
    ld [hli], a

    dec c
    jr nz, .next_tree

  ret
; ==========================================================================|80|

; ======================================> GAME DATA <=======================|80|
DMGObjPalette0:
  db %11100100

CGBObjPalettes:
CGBObjPalette0:
  dw $7FFF
  dw $22E7
  dw $19C4
  dw $14E0
CGBObjPalette0End:

CGBObjPalette1:
  dw $7FFF
  dw $7D7D
  dw $221F
  dw $3501
CGBObjPalette1End:
CGBObjPalettesEnd:

CGBBgPalettes:
CGBBgPalette0:
  dw $7FFF ; white
  dw $03E0 ; green
  dw $0200 ; dark green
  dw $0100 ; very dark green
CGBBgPalettesEnd:

GameTiles:
TilePlayerA:
  DB $00,$00,$42,$00,$18,$24,$66,$18
  DB $3C,$66,$42,$3C,$66,$18,$3C,$24
TilePlayerB:
  DB $00,$00,$99,$24,$66,$18,$3C,$66
  DB $42,$3C,$24,$18,$18,$24,$24,$24
TileTree:
  DB $38,$46,$68,$96,$E4,$1B,$6E,$91
  DB $D8,$27,$90,$6F,$00,$3E,$18,$18
TileTree2:
  DB $30,$08,$2E,$11,$DC,$03,$90,$66
  DB $10,$18,$60,$20,$10,$10,$10,$10
TileGrass:
  DB $00,$00,$00,$00,$22,$00,$00,$22
  DB $88,$00,$00,$88,$22,$00,$00,$22
TileDirt:
  DB $AA,$00,$55,$00,$AA,$00,$55,$00
  DB $AA,$00,$55,$00,$AA,$00,$55,$00
TileWater:
  DB $00,$00,$3C,$00,$00,$3C,$3C,$00
  DB $00,$00,$3C,$00,$00,$3C,$3C,$00
GameTilesEnd:
; ==========================================================================|80|
