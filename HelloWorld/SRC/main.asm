; main.asm

INCLUDE "gbc_regs.inc"

SECTION "Header", ROM0[$100]
    nop
    jp Entry
    ds $150 - @, 0

SECTION "Main", ROM0[$150]

Entry:
    di

WaitVBlank:
    ld a, [rLY]
    cp 144
    jr c, WaitVBlank

    xor a
    ld [rLCDC], a

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

    ; Copy sprite tile to $8000
    ld hl, SpriteTile
    ld de, $8000
    ld b, SpriteTileEnd - SpriteTile
.copy_tile
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .copy_tile

    ; DMG sprite palette: color 1/2/3 visible
    ld a, %11100100
    ld [rOBP0], a

    ; CGB OBJ palette 0:
    ; color 0 white, color 1 black, color 2 black, color 3 black
    ld a, $80
    ld [rOBPI], a
    ld a, $FF
    ld [rOBPD], a
    ld a, $7F
    ld [rOBPD], a
    xor a
    ld [rOBPD], a
    ld [rOBPD], a
    ld [rOBPD], a
    ld [rOBPD], a
    ld [rOBPD], a
    ld [rOBPD], a

    ; Sprite centered roughly at screen x=80, y=72
    ld hl, _OAMRAM
    ld a, 72 + 16
    ld [hli], a
    ld a, 80 + 8
    ld [hli], a
    xor a
    ld [hli], a        ; tile 0
    ld [hl], a         ; attrs: palette 0, VRAM bank 0

    ; LCD on, sprites on
    ld a, $80 | $02
    ld [rLCDC], a

Loop:
  call WaitVBlankNow
  call ReadDPad

   ; A now contains d-pad bits:
   ; bit 0 = Right
   ; bit 1 = Left
   ; bit 2 = Up
   ; bit 3 = Down
   ; pressed = 0

   bit 0, a
   call z, MoveRight

   bit 1, a
   call z, MoveLeft

   bit 2, a
   call z, MoveUp

   bit 3, a
   call z, MoveDown

   call WaitVBlankEnd
   jr Loop

   WaitVBlankNow:
       ld a, [rLY]
       cp 144
       jr c, WaitVBlankNow
       ret

   WaitVBlankEnd:
       ld a, [rLY]
       cp 144
       jr nc, WaitVBlankEnd
       ret
ReadDPad:
       ld a, %00100000     ; select d-pad buttons
       ld [rP1], a
       ld a, [rP1]
       ld a, [rP1]         ; read twice for stability
       and %00001111
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

SpriteTile:
    db %00111100, %00000000
    db %01000010, %00000000
    db %10100101, %00000000
    db %10000001, %00000000
    db %10100101, %00000000
    db %10011001, %00000000
    db %01000010, %00000000
    db %00111100, %00000000
SpriteTileEnd:
