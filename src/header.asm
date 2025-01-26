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
	ld b,b

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
	ld a, LCDCF_ON|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON|LCDCF_BG8800|LCDCF_OBJ8
	ldh [rLCDC],a


	ld a, 1
	ldh [PrintSettingsSheets], a
	ld a, $E4
	ldh [PrintSettingsPalette], a
	ld a, $40
	ldh [PrintSettingsExposure], a

	ld hl, PrintedImage
	ld bc, PrintedImage_End - PrintedImage
	call PrintLargeImage

Main:
	call WaitVblank
	ld a, "T"
	ld [_SCRN0], a
	ld a, "E"
	ld [_SCRN0+1], a
	ld a, "S"
	ld [_SCRN0+2], a
	ld a, "T"
	ld [_SCRN0+3], a

	ld a, OamBuffer>>8
	call RunOamDMA

	call ReadKeys

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
  pop af
  reti

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

PrintedImage::
	incbin "print_me.chr"
PrintedImage_End::
