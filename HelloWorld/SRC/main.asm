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
DEF SPRITE_X_CENTER                     EQU 80 + 8
DEF SPRITE_Y_CENTER                     EQU 72 + 16
DEF PLAYER_ANIM_DELAY                   EQU 4

; ==========================================================================|80|

; ======================================> HEADER DATA <=====================|80|
SECTION "Header", ROM0[$100]
  nop
  jp Entry
  ds $150 - @, 0
; ==========================================================================|80|

; ======================================> WRAM DATA <=======================|80|
SECTION "WRAM Data", WRAM0

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

  call InitPlayer
  call InitTerrain

  .turn_lcd_on
  ; LCD on, sprites on
  ld a, $80 | $02
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
  ld hl, _OAMRAM + 1  ; sprite X
  inc [hl]
  ret

MoveLeft:
  ld hl, _OAMRAM + 1
  dec [hl]
  ret

MoveUp:
  ld hl, _OAMRAM      ; sprite Y
  dec [hl]
  ret

MoveDown:
  ld hl, _OAMRAM
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
  ld hl, _OAMRAM + 2
  ld [hl], a

.done
  ret

InitPlayer:
  ld hl, _OAMRAM                        ; sprite slot 0
  ld a, SPRITE_Y_CENTER                 ; Y pos
  ld [hli], a
  ld a, SPRITE_X_CENTER                 ; X pos
  ld [hli], a
  ld a, [PlayerAnimFrame]               ; current animation frame
  ld [hli], a
  ld a, 1                               ; palette
  ld [hli], a
  ret

InitTerrain:
  ld hl, _OAMRAM + 8                    ; sprite slot 2
  ld a, SPRITE_Y_CENTER                 ; Y pos
  ld [hli], a
  ld a, SPRITE_X_CENTER - 16            ; X pos
  ld [hli], a
  ld a, 2                               ; tile
  ld [hli], a
  ld a, 0                               ; palette
  ld [hli], a

  ld hl, _OAMRAM + 12                   ; sprite slot 3
  ld a, SPRITE_Y_CENTER - 16
  ld [hli], a
  ld a, SPRITE_X_CENTER + 24
  ld [hli], a
  ld a, 3                               ; tile id
  ld [hli], a
  ld a, 0                               ; palette
  ld [hli], a
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
GameTilesEnd:
; ==========================================================================|80|
