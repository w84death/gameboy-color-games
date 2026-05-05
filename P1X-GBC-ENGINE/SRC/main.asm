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
DEF BG_MAP_ADDR                         EQU _SCRN0

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
DEF PAL_PLAYER                          EQU 1
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
    ld hl, SpritesPalettes
    ld b, SpritesPalettesEnd - SpritesPalettes
    call LoadObjPalettesCGB

    ld hl, TilesPalettes
    ld b, TilesPalettesEnd - TilesPalettes
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
    push bc

    ld a, [RandomSeed]
    ld b, a

    ld a, [rDIV]
    xor b
    add $3D
    xor $A7
    rlca

    ld [RandomSeed], a

    pop bc
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
  ld a, PAL_PLAYER                      ; palette
  ld [hli], a
  ret

GenerateTerrain:
  xor a
  ld [rVBK], a
  ld hl, _SCRN0
  ld bc, 32 * 32

  .next_tile
    call RandomByte
    and %00000011                       ; get 0..3
    cp 3
    jr nz, .valid
    xor a                               ; convert 3 to 0 -> 0..2
  .valid
    add a, TILES_BG_INDEX_START         ; convert to tiles IDs
    ld [hli], a

    dec bc
    ld a, b
    or c
    jr nz, .next_tile

  .gen_attributes
    ld a, 1
    ld [rVBK], a

    ld hl, _SCRN0
    ld bc, 32 * 32
    ld d, PAL_GROUND

  .write_attrs
    ld a, d
    ld [hli], a

    dec bc
    ld a, b
    or c
    jr nz, .write_attrs

    xor a
    ld [rVBK], a
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
SpritesPalettes:
    dw 32767, 801, 5728, 6593
    dw 32767, 32125, 8735, 13569
SpritesPalettesEnd:

TilesPalettes:
    dw 759, 1451, 649, 9729
TilesPalettesEnd:

GameTiles:
  TilePlayerA:
  DB $00,$00,$42,$00,$3C,$00,$66,$18
  DB $3C,$66,$42,$3C,$24,$5A,$3C,$24
  TilePlayerB:
  DB $00,$00,$99,$24,$66,$18,$3C,$66
  DB $42,$3C,$24,$5A,$18,$24,$24,$24
  TileTree1:
  DB $38,$46,$68,$96,$E4,$1B,$6E,$91
  DB $D8,$27,$90,$6F,$00,$3E,$18,$18
  TileTree2:
  DB $30,$08,$2E,$11,$DC,$03,$90,$66
  DB $10,$18,$60,$20,$10,$10,$10,$10
  TileGround1:
  DB $82,$04,$26,$42,$61,$20,$12,$00
  DB $00,$00,$44,$88,$C5,$44,$10,$20
  TileGround2:
  DB $E4,$FE,$00,$D1,$B8,$BB,$32,$FE
  DB $44,$CE,$14,$F7,$C3,$FF,$41,$D3
  TileGround3:
  DB $42,$FF,$CE,$BF,$27,$FA,$99,$7F
  DB $38,$EF,$63,$DE,$4F,$FB,$99,$F6
GameTilesEnd:
; ==========================================================================|80|
