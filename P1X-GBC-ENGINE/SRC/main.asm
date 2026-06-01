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
DEF BUTTON_START_BIT                    EQU $0003
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
DEF PLAYER_BASE_OAM_ADDR                EQU PLAYER_OAM_ADDR + 8

DEF TILES_BG_INDEX_START                EQU 6
DEF BEE_BODY_TILE_LEFT                  EQU 0
DEF BEE_BODY_TILE_RIGHT                 EQU 1
DEF BEE_WINGS_FRAME0_LEFT               EQU 2
DEF BEE_WINGS_FRAME0_RIGHT              EQU 4
DEF BEE_WINGS_FRAME1_LEFT               EQU 3
DEF BEE_WINGS_FRAME1_RIGHT              EQU 5
DEF PAL_BEE_WINGS                       EQU 0   ; Obj pal
DEF PAL_BEE_BODY                        EQU 1
DEF BEE_WING_LEFT_ATTR                  EQU PAL_BEE_WINGS
DEF BEE_WING_RIGHT_ATTR                 EQU PAL_BEE_WINGS
; ==========================================================================|80|

; ======================================> HEADER DATA <=====================|80|
SECTION "VBlank vector", ROM0[$0040]
  jp VBlankISR

SECTION "Header", ROM0[$100]
  nop
  jp Entry
  ds $150 - @, 0
; ==========================================================================|80|

; ======================================> WRAM DATA <=======================|80|
SECTION "WRAM Data", WRAM0
FrameCounter:                           ds 1
FrameReady:                             ds 1
PlayerAnimTimer:                        ds 1
PlayerAnimFrame:                        ds 1
PlayerFacing:                           ds 1
CameraX:                                ds 1
CameraY:                                ds 1
CurrentLevel:                           ds 1
PrevButtons:                            ds 1
; ==========================================================================|80|

; ======================================> MAIN SECTION <====================|80|
SECTION "Main", ROM0[$150]

Entry:
  di                                    ; disable interrups
  ld sp, $FFFE
  xor a
  ld [rIE], a
  ld [rIF], a
  call WaitVBlank

  xor a
  ld [rLCDC], a

  .init_camera
  xor a
  ld [CameraX], a
  ld [CameraY], a

  .init_level_switch
  xor a
  ld [CurrentLevel], a
  ld a, %00001111
  ld [PrevButtons], a

  .init_player
  xor a
  ld [FrameCounter], a
  ld [FrameReady], a
  ld [PlayerAnimFrame], a
  ld [PlayerFacing], a
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

  call LoadDefaultLevel
  call InitPlayer

  .init_lcd
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000 | LCDCF_BG9800
  ld [rLCDC], a

  xor a
  ld [rIF], a
  ld a, IEF_VBLANK
  ld [rIE], a
  ei

; ======================================> MAIN LOOP <=======================|80|
MainLoop:
  call WaitFrame
  call HandleLevelSwap
  call HandleDPad
  call AnimatePlayer
  call UpdateCamera
  jr MainLoop

; ==========================================================================|80|



; ======================================> PROCEDURES <======================|80|
WaitVBlank:
  .wait_vblank_end
  ld a, [rLY]
  cp 144
  jr nc, .wait_vblank_end

  .wait_vblank
  ld a, [rLY]
  cp 144
  jr c, .wait_vblank
  ret

WaitFrame:
  halt
  nop
  ld a, [FrameReady]
  and a
  jr z, WaitFrame
  xor a
  ld [FrameReady], a
  ret

VBlankISR:
  push af
  ld a, 1
  ld [FrameReady], a
  pop af
  reti

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

HandleLevelSwap:
  call ReadButtons
  ld b, a
  ld a, [PrevButtons]
  ld c, a
  ld a, b
  ld [PrevButtons], a

  bit BUTTON_START_BIT, b               ; pressed = 0
  ret nz
  bit BUTTON_START_BIT, c               ; ignore held START
  ret z

  call ToggleLevel
  ret

ReadButtons:
  ld a, %00010000                       ; select A/B/Select/Start
  ld [rP1], a
  ld a, [rP1]
  ld a, [rP1]
  and %00001111
  ret

ToggleLevel:
  ld a, [CurrentLevel]
  xor 1
  ld [CurrentLevel], a
  or a
  jr z, .load_default

.load_desert
  call LoadDesertLevelHot
  ret

.load_default
  call LoadDefaultLevelHot
  ret

MoveRight:
  ld a, 1
  ld [PlayerFacing], a
  call ApplyBeeFacingTiles

  ld hl, PLAYER_BASE_OAM_ADDR + 1
  ld a, [hl]
  cp OAM_RIGHT_THRESH
  jr nc, .scroll_camera

  call MovePlayerSpritesRight
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
  xor a
  ld [PlayerFacing], a
  call ApplyBeeFacingTiles

  ld hl, PLAYER_BASE_OAM_ADDR + 1       ; sprite X
  ld a, [hl]
  cp OAM_LEFT_THRESH
  jr c, .scroll_camera

  call MovePlayerSpritesLeft
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
  ld hl, PLAYER_BASE_OAM_ADDR           ; sprite Y
  ld a, [hl]
  cp OAM_TOP_THRESH                     ; compare player Y with top threshold
  jr c, .scroll_camera                  ; jump if position is bigger

  call MovePlayerSpritesUp
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
  ld hl, PLAYER_BASE_OAM_ADDR           ; sprite Y
  ld a, [hl]
  cp OAM_BOTTOM_THRESH
  jr nc, .scroll_camera

  call MovePlayerSpritesDown
  ret

  .scroll_camera
  ld hl, CameraY
  ld a, [hl]
  cp CAMERA_Y_MAX
  ret nc

  inc a
  ld [hl], a
  ret

MovePlayerSpritesRight:
  ld hl, PLAYER_OAM_ADDR + 1
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 5
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 9
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 13
  inc [hl]
  ret

MovePlayerSpritesLeft:
  ld hl, PLAYER_OAM_ADDR + 1
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 5
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 9
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 13
  dec [hl]
  ret

MovePlayerSpritesUp:
  ld hl, PLAYER_OAM_ADDR
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 4
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 8
  dec [hl]
  ld hl, PLAYER_OAM_ADDR + 12
  dec [hl]
  ret

MovePlayerSpritesDown:
  ld hl, PLAYER_OAM_ADDR
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 4
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 8
  inc [hl]
  ld hl, PLAYER_OAM_ADDR + 12
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
  call ApplyBeeFacingTiles
.done
  ret

ApplyBeeFacingTiles:
  ; attributes based on facing
  ld a, [PlayerFacing]
  or a
  jr z, .face_left_attr

.face_right_attr
  ld hl, PLAYER_OAM_ADDR + 3
  ld a, BEE_WING_LEFT_ATTR | OAMF_XFLIP
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 7
  ld a, BEE_WING_RIGHT_ATTR | OAMF_XFLIP
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 11
  ld a, PAL_BEE_BODY | OAMF_XFLIP
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 15
  ld a, PAL_BEE_BODY | OAMF_XFLIP
  ld [hl], a
  jr .attr_done

.face_left_attr
  ld hl, PLAYER_OAM_ADDR + 3
  ld a, BEE_WING_LEFT_ATTR
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 7
  ld a, BEE_WING_RIGHT_ATTR
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 11
  ld a, PAL_BEE_BODY
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 15
  ld a, PAL_BEE_BODY
  ld [hl], a

.attr_done
  ; body tiles based on facing
  ld a, [PlayerFacing]
  or a
  jr z, .face_left_body

.face_right_body
  ld hl, PLAYER_OAM_ADDR + 10
  ld a, BEE_BODY_TILE_RIGHT
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 14
  ld a, BEE_BODY_TILE_LEFT
  ld [hl], a
  jr .body_done

.face_left_body
  ld hl, PLAYER_OAM_ADDR + 10
  ld a, BEE_BODY_TILE_LEFT
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 14
  ld a, BEE_BODY_TILE_RIGHT
  ld [hl], a

.body_done
  ; wing tiles based on anim frame and facing
  ld a, [PlayerAnimFrame]
  or a
  jr z, .anim0

.anim1
  ld b, BEE_WINGS_FRAME1_LEFT
  ld c, BEE_WINGS_FRAME1_RIGHT
  jr .apply_wings

.anim0
  ld b, BEE_WINGS_FRAME0_LEFT
  ld c, BEE_WINGS_FRAME0_RIGHT

.apply_wings
  ld a, [PlayerFacing]
  or a
  jr z, .face_left_wings

.face_right_wings
  ld hl, PLAYER_OAM_ADDR + 2
  ld a, c
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 6
  ld a, b
  ld [hl], a
  ret

.face_left_wings
  ld hl, PLAYER_OAM_ADDR + 2
  ld a, b
  ld [hl], a
  ld hl, PLAYER_OAM_ADDR + 6
  ld a, c
  ld [hl], a
  ret

InitPlayer:
  ; top-left wing
  ld hl, PLAYER_OAM_ADDR
  ld a, SPRITE_Y_CENTER - TILE_SIZE + 3
  ld [hli], a
  ld a, SPRITE_X_CENTER
  ld [hli], a
  ld a, BEE_WINGS_FRAME0_LEFT
  ld [hli], a
  ld a, BEE_WING_LEFT_ATTR
  ld [hli], a



  ; top-right wing
  ld a, SPRITE_Y_CENTER - TILE_SIZE + 3
  ld [hli], a
  ld a, SPRITE_X_CENTER + TILE_SIZE
  ld [hli], a
  ld a, BEE_WINGS_FRAME0_RIGHT
  ld [hli], a
  ld a, BEE_WING_RIGHT_ATTR
  ld [hli], a

  ; bottom-left body (anchor)
  ld a, SPRITE_Y_CENTER
  ld [hli], a
  ld a, SPRITE_X_CENTER
  ld [hli], a
  ld a, BEE_BODY_TILE_LEFT
  ld [hli], a
  ld a, PAL_BEE_BODY
  ld [hli], a

  ; bottom-right body
  ld a, SPRITE_Y_CENTER
  ld [hli], a
  ld a, SPRITE_X_CENTER + TILE_SIZE
  ld [hli], a
  ld a, BEE_BODY_TILE_RIGHT
  ld [hli], a
  ld a, PAL_BEE_BODY
  ld [hli], a

  call ApplyBeeFacingTiles
  ret

LoadDefaultLevelHot:
  call WaitVBlank
  xor a
  ld [rLCDC], a
  call LoadDefaultLevel
  call RestoreLCD
  ret

LoadDesertLevelHot:
  call WaitVBlank
  xor a
  ld [rLCDC], a
  call LoadDesertLevel
  call RestoreLCD
  ret

RestoreLCD:
  ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_BGON | LCDCF_BG8000 | LCDCF_BG9800
  ld [rLCDC], a
  ret

LoadDefaultLevel:
  .load_palettes
    ld hl, DefaultLevelBgPalettes
    ld b, DefaultLevelBgPalettesEnd - DefaultLevelBgPalettes
    call LoadBgPalettesCGB

  .load_tiles
    xor a
    ld [rVBK], a

    ld hl, DefaultLevelTiles
    ld de, BG_TILE_ADDR + (TILES_BG_INDEX_START * 16)
    ld bc, DefaultLevelTilesEnd - DefaultLevelTiles
    call LoadBytes

  .load_tilemap
    xor a
    ld [rVBK], a

    ld hl, DefaultLevelTileMap
    ld de, BG_MAP_ADDR
    ld bc, DefaultLevelTileMapEnd - DefaultLevelTileMap
    call LoadBytes

  .load_attrmap
    ld a, 1
    ld [rVBK], a

    ld hl, DefaultLevelAttrMap
    ld de, BG_MAP_ADDR
    ld bc, DefaultLevelAttrMapEnd - DefaultLevelAttrMap
    call LoadBytes

    xor a
    ld [rVBK], a
    ret

LoadDesertLevel:
  .load_palettes
    ld hl, DesertLevelBgPalettes
    ld b, DesertLevelBgPalettesEnd - DesertLevelBgPalettes
    call LoadBgPalettesCGB

  .load_tiles
    xor a
    ld [rVBK], a

    ld hl, DesertLevelTiles
    ld de, BG_TILE_ADDR + (TILES_BG_INDEX_START * 16)
    ld bc, DesertLevelTilesEnd - DesertLevelTiles
    call LoadBytes

  .load_tilemap
    xor a
    ld [rVBK], a

    ld hl, DesertLevelTileMap
    ld de, BG_MAP_ADDR
    ld bc, DesertLevelTileMapEnd - DesertLevelTileMap
    call LoadBytes

  .load_attrmap
    ld a, 1
    ld [rVBK], a

    ld hl, DesertLevelAttrMap
    ld de, BG_MAP_ADDR
    ld bc, DesertLevelAttrMapEnd - DesertLevelAttrMap
    call LoadBytes

    xor a
    ld [rVBK], a
    ret
; ==========================================================================|80|

include "SRC/data.inc"
include "SRC/palette.inc"
include "SRC/level.inc"
