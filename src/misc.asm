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

INCLUDE "hardware.inc"

SECTION "Misc", ROM0

memcpy::
    ; Increment B if C is non-zero
    dec bc
    inc b
    inc c
.loop
    ld a, [hl+]
    ld [de], a
    inc de
    dec c
    jr nz, .loop
    dec b
    jr nz, .loop
    ret

memcpy8::
  ld a, [hl+]
  ld [de], a
  inc de
  dec c
  jr nz, memcpy8
  ret

memclear::
	xor a
memset::
    ; Increment B if C is non-zero
    dec bc
    inc b
    inc c
.loop
    ld [hl+], a
    inc de
    dec c
    jr nz, .loop
    dec b
    jr nz, .loop
	ret

ScreenOff::
  ; Is the screen already off?
  ldh a,[rLCDC]
  add a
  ret nc

  call WaitVblank
  xor a
  ldh [rLCDC], a
  ret

ScreenOn::
  ld a, LCDCF_ON|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON|LCDCF_BG8800|LCDCF_OBJ8
  ldh [rLCDC],a
  ret

WaitVblank::
	push hl
	push af
	ld a, IEF_VBLANK|IEF_STAT
	ldh [rIE],a     ; Enable vblank interrupt
	ei

	ld   hl, framecount
	ld   a, [hl]
.loop:
	halt
	cp   a, [hl]
	jr   z, .loop
	pop af
	pop hl
	ret

ReadKeys::
  ldh a, [KeyDown]
  ldh [KeyLast], a

  ld a, P1F_GET_BTN
  call .onenibble
  and $f
  ld b, a

  ld a, P1F_GET_DPAD
  call .onenibble
  and $f
  swap a
  or b
  cpl
  ldh [KeyDown], a

  ld a,P1F_GET_NONE ; Stop asking for any keys
  ldh [rP1],a

  ldh a, [KeyLast]
  cpl
  ld b, a
  ldh a, [KeyDown]
  and b
  ldh [KeyNew], a
  ret

.onenibble:
  ldh [rP1],a     ; switch the key matrix
  call .knownret  ; burn 10 cycles calling a known ret
  ldh a,[rP1]     ; ignore value while waiting for the key matrix to settle
  ldh a,[rP1]
  ldh a,[rP1]     ; this read counts
.knownret:
  ret

memclear8::
  xor a
memset8::
  ld [hl+], a
  dec c
  jr nz, memset8
  ret

; -----------------------------------------

ClearOAM::
  ld hl, OamBuffer
  xor a
  ldh [OamWrite], a
.clear_sprites:
  ld [hl+], a
  inc l
  inc l
  inc l
  jr nz, .clear_sprites
  ret

ClearAndWriteOAM::
  call ClearOAM
  ld a, OamBuffer>>8
  jp RunOamDMA

oam_dma_routine::
	ldh [rDMA],a
	ld  a,$28
.wait:
	dec a
	jr  nz,.wait
	ret
oam_dma_routine_end::

