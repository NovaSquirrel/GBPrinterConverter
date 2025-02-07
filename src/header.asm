; Game Boy Printer album demo
;
; Copyright 2025 NovaSquirrel
; 
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
; 
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
; 
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;

; https://gbdev.io/pandocs/Gameboy_Printer.html
; https://shonumi.github.io/articles/art2.html

INCLUDE "hardware.inc"

MACRO wait_vram
.waitVRAM\@
	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, .waitVRAM\@
	; Now there's 16 "safe" cycles to write during hblank.
	; If STAT is read on the very last cycle of hblank or vblank, the OAM scan will start immediately after,
	; and when this macro ends, you're left with 16 cycles remaining of OAM scan (which is also safe to write VRAM during)
ENDM

MACRO add_hl_a
  add a,l
  ld l,a
  jr nc, @+3
  inc h
ENDM

MACRO add_bc_a
  add a,c
  ld c,a
  jr nc, @+3
  inc b
ENDM

MACRO add_de_a
  add a,e
  ld e,a
  jr nc, @+3
  inc d
ENDM

SECTION "vblank", ROM0[$0040]
	jp vblank

SECTION "stat", ROM0[$0048]
	push af
	ld a, LCDCF_ON|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON|LCDCF_BG8800|LCDCF_OBJ8
	ldh [rLCDC],a
	pop af
	reti

SECTION "Header", ROM0[$100]

	; This is your ROM's entry point
	; You have 4 bytes of code to do... something
	di
	jp EntryPoint

	; Make sure to allocate some space for the header, so no important
	; code gets put there and later overwritten by RGBFIX.
	; RGBFIX is designed to operate over a zero-filled header, so make
	; sure to put zeros regardless of the padding value. (This feature
	; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
	; introduced in that version.)
	ds $150 - @, 0

SECTION "Entry point", ROM0

EntryPoint:
	ld sp, $E000

	; Disable audio
	xor a
	ldh [rAUDENA], a

	; Copy in DMA routine
	ld hl, oam_dma_routine
	ld de, RunOamDMA
	ld c, oam_dma_routine_end - oam_dma_routine
	call memcpy8

	; Clear RAM (but not the return address)
	ld hl, _RAM
	ld bc, 8192-2
	call memclear

	; Turn the screen off
	call ScreenOff

    ; Clear video RAM before putting anything in it
	ld hl, _VRAM8000
	ld bc, 8192
	call memclear

    ; Copy over background data
	ld hl, BackgroundGfx
	ld de, _VRAM9000
	ld bc, BackgroundGfxEnd-BackgroundGfx
	call memcpy

    ; Copy over sprite graphics
	ld hl, SpritesGfx
	ld de, _VRAM8000
	ld bc, SpritesGfxEnd-SpritesGfx
	call memcpy

	; Reset the scroll
	xor a
	ldh [rSCX], a
	ldh [rSCY], a

	; Set up a palette
	ld a, %11100100
	ldh [rBGP], a
	ldh [rOBP0], a
	ldh [rOBP1], a

	; -----------------------------------------

	xor a
	ldh [CurrentMenuImage], a
	call DisplayImageOnScreen

Main:
	call WaitVblank

	ld a, OamBuffer>>8
	call RunOamDMA

	call ReadKeys

	ldh a, [KeyNew]
	and PADF_LEFT
	jr z, .NotLeft
		ldh a, [CurrentMenuImage]
		dec a
		ldh [CurrentMenuImage], a

		cp $ff
		jr nz, :+
			ld a, [FileCount]
			dec a
			ldh [CurrentMenuImage], a
		:
		call DisplayImageOnScreen
	.NotLeft:

	ldh a, [KeyNew]
	and PADF_RIGHT
	jr z, .NotRight
		ldh a, [CurrentMenuImage]
		inc a
		ldh [CurrentMenuImage], a
		ld b, a

		ld a, [FileCount]
		cp b
		jr nz, :+
			xor a
			ldh [CurrentMenuImage], a
		:
		call DisplayImageOnScreen
	.NotRight:

	ldh a, [KeyNew]
	and PADF_A
	jr z, .NotPrint
		ldh a, [CurrentMenuImage]
		ld l, a
		ld h, 0
		add hl, hl ; * 2
		add hl, hl ; * 4
		add_hl_a

		ld de, FileDirectory
		add hl, de
		ld a, [hl+]
		ldh [temp1], a ; File pointer L
		ld a, [hl+]
		ldh [temp2], a ; File pointer H
		ld a, [hl+]
		ld [rROMB0], a ; Bank
		ld a, [hl+]
		ld c, a        ; Size L
		ld a, [hl+]
		ld b, a        ; Size H

		ld a, 1
		ldh [PrintSettingsSheets], a
		ld a, $E4
		ldh [PrintSettingsPalette], a
		ld a, $40
		ldh [PrintSettingsExposure], a

		ld a, %00011011
		ldh [rBGP], a

		ldh a, [temp1]
		ld l, a
		ldh a, [temp2]
		ld h, a
		call PrintLargeImage

		ld a, %11100100
		ldh [rBGP], a
	.NotPrint:

	call ClearOAM
	xor a
	ldh [OamWrite], a
	;call RunPlayer

	jp Main

PutHex:
	push af
	swap a
	and 15
	ld de, .table
	add_de_a
	ld a, [de]
	ld [hl+], a
	pop af
	and 15
	ld de, .table
	add_de_a
	ld a, [de]
	ld [hl+], a
	ret
.table:
	db "0123456789ABCDEF"

vblank::
	push af
	ldh a, [framecount]
	inc a
	ldh [framecount], a

	ld a, LCDCF_ON|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON|LCDCF_BG8000|LCDCF_OBJ8
	ldh [rLCDC],a
	pop af
	reti


DisplayImageOnScreen:
	call ScreenOff

	; Clear VRAM
	ld hl, _VRAM8000
	ld bc, 20*18*16
	call memclear

	; Initialize tilemap
	ld hl, _SCRN0
	ld de, 32-20
	xor a
	ld c, 18
.new_row:
	ld b, 20
:	ld [hl+], a
	inc a
	dec b
	jr nz, :-
	add hl, de
	dec c
	jr nz, .new_row

	ldh a, [CurrentMenuImage]
	ld l, a
	ld h, 0
	add hl, hl ; * 2
	add hl, hl ; * 4
	add_hl_a

	ld de, FileDirectory
	add hl, de
	ld a, [hl+]
	ldh [temp1], a ; File pointer L
	ld a, [hl+]
	ldh [temp2], a ; File pointer H
	ld a, [hl+]
	ldh [temp3], a ; Bank
	ld a, [hl+]
	ld c, a
	ldh [temp4], a ; File size L
	ld a, [hl+]
	ld b, a
	ldh [temp5], a ; File size H

	; Switch in the bank with the file
	ldh a, [temp3]
	ld [rROMB0], a

	; Limit it to only copying over 1 screen of tiles
	ld a, b
	cp HIGH(20*19*16)
	jr c, :+
		ld bc, 20*18*16
	:

	; Copy over graphics
	ldh a, [temp1]
	ld l, a
	ldh a, [temp2]
	ld h, a
	ld de, _VRAM8000
	call memcpy

	; Interrupt at the bottom of the screen
	ld a, 11*8
	ldh [rLYC], a
	ld a, STATF_LYC
	ldh [rSTAT], a

	; Turn the screen on
	ld a, LCDCF_ON|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON|LCDCF_BG8000|LCDCF_OBJ8
	ldh [rLCDC],a
	ret


SECTION "Graphics", ROM0

SpritesGfx:
	rept 8
	  db %00000000
	  db %00000000
	endr

	rept 8
	  db %11111111
	  db %00000000
	endr

	rept 8
	  db %00000000
	  db %11111111
	endr

	rept 8
	  db %11111111
	  db %11111111
	endr
SpritesGfxEnd:

BackgroundGfx:
	incbin "font.chr"
BackgroundGfxEnd:
