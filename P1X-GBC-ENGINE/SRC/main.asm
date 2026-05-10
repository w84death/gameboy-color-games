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

DEF SCREEN_WIDTH                        EQU 160
DEF SCREEN_HEIGHT                       EQU 144
DEF TILE_SIZE                           EQU 8
DEF SPRITE_WIDTH                        EQU 8
DEF SPRITE_HEIGHT                       EQU 8

DEF OAM_X_OFFSET                        EQU 8
DEF OAM_Y_OFFSET                        EQU 16
DEF OAM_RIGHT_THRESH                    EQU 152
DEF OAM_LEFT_THRESH                     EQU 16
DEF OAM_TOP_THRESH                      EQU 24
DEF OAM_BOTTOM_THRESH                   EQU 144
DEF CAMERA_X_MAX                        EQU 96
DEF CAMERA_Y_MAX                        EQU 112

DEF SPRITE_X_CENTER                     EQU 80 + 8
DEF SPRITE_Y_CENTER                     EQU 72 + 8
DEF PLAYER_ANIM_DELAY                   EQU 4
DEF TREE_FIRST_SLOT                     EQU 0
DEF PLAYER_OAM_ADDR                     EQU _OAMRAM

DEF TREE_TILE_A                         EQU 2
DEF TREE_TILE_B                         EQU 3
DEF TILES_BG_INDEX_START                EQU 6
DEF PAL_PLAYER                          EQU 0   ; Obj pal
DEF PAL_TREE                            EQU 0   ; Bg pal
DEF PAL_GROUND                          EQU 1
; ==========================================================================|80|

; ======================================> HEADER DATA <=====================|80|
SECTION "Header", ROM0[$100]
  nop
  jp Entry
  ds $150 - @, 0
; ==========================================================================|80|

; ======================================> WRAM DATA <=======================|80|
SECTION "WRAM Data", WRAM0
RandomSeed:                             ds 1
FrameCounter:                           ds 1
PlayerAnimTimer:                        ds 1
PlayerAnimFrame:                        ds 1
CameraX:                                ds 1
CameraY:                                ds 1
; ==========================================================================|80|

; ======================================> MAIN SECTION <====================|80|
SECTION "Main", ROM0[$150]

Entry:
  di                                    ; disable interrups
  call WaitVBlank

  xor a
  ld [rLCDC], a

  .init_randomizer
  ld a, [rDIV]
  or $01                                ; avoid zero
  ld [RandomSeed], a

  .init_camera
  xor a
  ld [CameraX], a
  ld [CameraY], a

  .init_player
  xor a
  ld [FrameCounter], a
  ld [PlayerAnimFrame], a
  ld a, PLAYER_ANIM_DELAY
  ld [PlayerAnimTimer], a

  .init_vram
  xor a
  ld [rVBK], a

  .init_oamram
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

  .init_lcd
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000 | LCDCF_BG9800
  ld [rLCDC], a

; ======================================> MAIN LOOP <=======================|80|
MainLoop:
  call WaitVBlank
  call HandleDPad
  call AnimatePlayer
  call UpdateCamera
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

UpdateCamera:
  ld a, [CameraX]
  ld [rSCX], a
  ld a, [CameraY]
  ld [rSCY], a
ret

HandleDPad:
  call ReadDPad
  ld b, a
  bit DPAD_RIGHT_BIT, b
  call z, MoveRight
  bit DPAD_LEFT_BIT, b
  call z, MoveLeft
  bit DPAD_UP_BIT, b
  call z, MoveUp
  bit DPAD_DOWN_BIT, b
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
  ld hl, PLAYER_OAM_ADDR + 1
  ld a, [hl]
  cp OAM_RIGHT_THRESH
  jr nc, .scroll_camera

  inc [hl]
  ret

  .scroll_camera
  ld hl, CameraX
  ld a, [hl]
  cp CAMERA_X_MAX
  ret nc

  inc a
  ld [hl], a
  ret

MoveLeft:
  ld hl, PLAYER_OAM_ADDR + 1            ; sprite X
  ld a, [hl]
  cp OAM_LEFT_THRESH
  jr c, .scroll_camera

  dec [hl]
  ret

  .scroll_camera
  ld hl, CameraX
  ld a, [hl]
  or a                                  ; set zero flag if a is zero
  ret z                                 ; return if zero

  dec a
  ld [hl], a
  ret

MoveUp:
  ld hl, PLAYER_OAM_ADDR                ; sprite Y
  ld a, [hl]
  cp OAM_TOP_THRESH                     ; compare player Y with top threshold
  jr c, .scroll_camera                  ; jump if position is bigger

  dec [hl]
  ret

  .scroll_camera
  ld hl, CameraY
  ld a, [hl]
  or a
  ret z

  dec a
  ld [hl], a
  ret

MoveDown:
  ld hl, PLAYER_OAM_ADDR                ; sprite Y
  ld a, [hl]
  cp OAM_BOTTOM_THRESH
  jr nc, .scroll_camera

  inc [hl]
  ret

  .scroll_camera
  ld hl, CameraY
  ld a, [hl]
  cp CAMERA_Y_MAX
  ret nc

  inc a
  ld [hl], a
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
  add 2
  ld [hli], a
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
  ld hl, _SCRN0
  ld bc, 32 * 32                        ; loop index i16

  .next_tile
    xor a
    ld [rVBK], a                        ; zero for tile data

    call RandomByte
    and %00000111                       ; get 0..7
    ld d, a                             ; save tile index
    add a, TILES_BG_INDEX_START         ; shift over player sprites
    ld [hl], a                          ; write tile id

    ld a, 1
    ld [rVBK], a                        ; one for attributes

    ld a, d                             ; load tile index
    cp 4                                ; 0..3 vs 4..7
    xor a                               ; set pal 0
    jr c, .pal_set                      ; if <4 skip pal 1
    ld a, 1                             ; set pal 1
    .pal_set
    ld [hli], a                         ; write attribute and inc hl poiner

    dec bc                              ; reduce loop index i16
    ld a, b                             ; copy high byte of index
    or c                                ; or with low, if both 0 then zero flag
    jr nz, .next_tile                   ; if non-zero repeat

    xor a
        ld [rVBK], a
    ret
; ==========================================================================|80|

include "SRC/data.inc"
include "SRC/palette.inc"
