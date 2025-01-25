INCLUDE "hardware.inc"

SECTION "Printing", ROM0

SendSerialByte:
	ldh [rSB], a

	; Keep track of a checksum as we go
	add e
	ld e, a
	jr nc, :+
		inc d
	:

	ld a, SCF_START|SCF_SOURCE
	ldh [rSC], a
:	ldh a, [rSC]
	add a
	jr c, :-
	ret

; ---------------------------------------------------------

; A = Command
; BC = Data length
; HL = Data pointer
; Output: B = Keepalive, C = Status
SendPrinterPacket::
	push af
	ld a, $88
	call SendSerialByte ; Magic
	ld a, $33
	call SendSerialByte ; Magic
	pop af
	ld d, 0
	ld e, 0
	call SendSerialByte ; Command
	xor a
	call SendSerialByte ; No compression

	ld a, c
	call SendSerialByte ; Length (low)
	ld a, b
	call SendSerialByte ; Length (high)

	ld a, b
	or c
	jr z, .noTransfer
.transfer:
	ld a, [hl+]
	call SendSerialByte
	dec bc
	ld a, b
	or c
	jr nz, .transfer
.noTransfer:

	ld b, d
	ld a, e
	call SendSerialByte ; Checksum (low)
	ld a, b
	call SendSerialByte ; Checksum (high)
	
	; Get keepalive
	xor a
	call SendSerialByte
	ldh a, [rSB]
	ldh [PrinterStatus1], a

	; Get status
	xor a
	call SendSerialByte
	ldh a, [rSB]
	ldh [PrinterStatus2], a
	ret

; ---------------------------------------------------------

; HL = image
; BC = size
PrintLargeImage::
	; Initial configuration
	ld a, l
	ldh [ImagePointer+0], a
	ld a, h
	ldh [ImagePointer+1], a
	ld a, c
	ldh [ImageBytesLeft+0], a
	ld a, b
	ldh [ImageBytesLeft+1], a

	ld a, $10
	ldh [PrintSettingsMargins], a

.transfer:
	ld a, $f
	ld bc, 0
	call SendPrinterPacket
	call WaitVblank
	ldh a, [PrinterStatus1]
	cp $81
	jr nz, .transfer

	ld a, 1 ; Initialize printer
	ld bc, 0
	call SendPrinterPacket

	ldh a, [ImageBytesLeft+0]
	ld c, a
	ldh a, [ImageBytesLeft+1]
	ld b, a
	call LimitTo0x280

	; Decrease the amount of bytes left to go
	ldh a, [ImageBytesLeft+0]
	sub c
	ldh [ImageBytesLeft+0], a
	ldh a, [ImageBytesLeft+1]
	sbc b
	ldh [ImageBytesLeft+1], a

	; Get pointer and move it forward
	ldh a, [ImagePointer+0]
	ld l, a
	add c
	ldh [ImagePointer+0], a
	ldh a, [ImagePointer+1]
	ld h, a
	adc b
	ldh [ImagePointer+1], a
	ld b,b

	ld a, 4
	call SendPrinterPacket

	ld a, 4 ; Send empty print command
	ld bc, 0
	call SendPrinterPacket

	; Last one should have some margin on the bottom
	ld a, [PrintSettingsMargins]
	or a
	jr nz, :+
		ldh a, [ImageBytesLeft+0]
		ld b, a
		ldh a, [ImageBytesLeft+1]
		or b
		jr nz, :+
			ld a, $03
			ldh [PrintSettingsMargins], a
	:

	ld a, 2 ; Start printing
	ld bc, 4
	ld hl, PrintSettingsSheets
	call SendPrinterPacket

:	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, :-
	ld a, "?"
	ld [_SCRN0 + 32 + 8], a

.waitWhilePrinting:
	ld a, $f
	ld bc, 0
	call SendPrinterPacket
	call WaitVblank
	ldh a, [PrinterStatus2]
	cp 6
	jr nz, .waitWhilePrinting

:	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, :-
	ld a, "!"
	ld [_SCRN0 + 32 + 8], a

.waitWhilePrinting2:
	ld a, $f
	ld bc, 0
	call SendPrinterPacket
	call WaitVblank
	ldh a, [PrinterStatus2]
	cp 4
	jr nz, .waitWhilePrinting2

:	ldh a, [rSTAT]
	and STATF_BUSY
	jr nz, :-
	ld a, " "
	ld [_SCRN0 + 32 + 8], a

	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte
	xor a
	call SendSerialByte

	xor a
	ld [PrintSettingsMargins], a

	; Keep going?
	ldh a, [ImageBytesLeft+0]
	ld c, a
	ldh a, [ImageBytesLeft+1]
	or c
	jp nz, .transfer
	ret

LimitTo0x280:
	ld a, b
	cp 3
	jr nc, .applyLimit
	cp 2
	ret c
	ld a, c
	cp $81
	ret c
.applyLimit:
	ld bc, $280
	ret

; ---------------------------------------------------------

