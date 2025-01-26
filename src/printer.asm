INCLUDE "hardware.inc"

SECTION "Printing", ROM0

; Send one byte over the serial port, and add it to DE
SendSerialByte:
	ldh [rSB], a

	; Keep track of a checksum as we go
	add e
	ld e, a
	jr nc, :+
		inc d
	:

	; Start transfer and wait for it to finish
	ld a, SCF_START|SCF_SOURCE
	ldh [rSC], a
:	ldh a, [rSC]
	add a
	jr c, :-
	ret

; ---------------------------------------------------------

; A  = Command
; BC = Data length
; HL = Data pointer
; Output: PrinterReady, PrinterStatus
SendPrinterPacketNoData::
	ld bc, 0
SendPrinterPacket::
	push af
	ld a, $88
	call SendSerialByte ; Magic byte to identify printer command
	ld a, $33
	call SendSerialByte ; Magic byte to identify printer command
	pop af
	ld de, 0 ; Reset the checksum
	call SendSerialByte ; Command
	xor a
	call SendSerialByte ; No compression

	ld a, c
	call SendSerialByte ; Length (low)
	ld a, b
	call SendSerialByte ; Length (high)

	; Transfer all of the data, if there is actually any to send
	ld a, b
	or c
	jr z, .noTransfer ; No data to send?
.transfer:
	ld a, [hl+]
	call SendSerialByte
	dec bc
	ld a, b
	or c
	jr nz, .transfer
.noTransfer:

	; Send the checksum of the stuff so far
	ld b, d
	ld a, e
	call SendSerialByte ; Checksum (low)
	ld a, b
	call SendSerialByte ; Checksum (high)
	
	; Get keepalive
	xor a
	call SendSerialByte
	ldh a, [rSB]
	ldh [PrinterReady], a

	; Get status
	xor a
	call SendSerialByte
	ldh a, [rSB]
	ldh [PrinterStatus], a
	ret

; ---------------------------------------------------------

; HL = Image to print
; BC = Size of the image, in bytes
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

	; First print should have a margin of 1 at the top
	ld a, $10
	ldh [PrintSettingsMargins], a

.transfer:
	; First, check if the printer is even active and ready to accept a command
	ld a, $f ; no operation
	ld bc, 0
	call SendPrinterPacket
	call WaitVblank
	ldh a, [PrinterReady]
	cp $81
	jr nz, .transfer

	; Initialize printer buffer
	ld a, 1
	call SendPrinterPacketNoData

	; Try to send as many bytes as possible
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

	; Get pointer and also move it forward
	ldh a, [ImagePointer+0]
	ld l, a
	add c
	ldh [ImagePointer+0], a
	ldh a, [ImagePointer+1]
	ld h, a
	adc b
	ldh [ImagePointer+1], a

	; Command 4 = fill buffer
	ld a, 4
	call SendPrinterPacket

	; Need to do command 4 again with no data or print will be ignored
	ld a, 4
	call SendPrinterPacketNoData

	; If this is the very last print, put some extra margin on the bottom
	ldh a, [PrintSettingsMargins] ; Don't put margin on the bottom if it's the first print and there's margin on the top
	or a
	jr nz, :+
		ldh a, [ImageBytesLeft+0] ; If this is the last print, there will be no bytes left to send
		ld b, a
		ldh a, [ImageBytesLeft+1]
		or b
		jr nz, :+
			ld a, $03
			ldh [PrintSettingsMargins], a
	:

	; Send a command to start printing
	ld a, 2
	ld bc, 4
	ld hl, PrintSettingsSheets ; Print settings
	call SendPrinterPacket

	; Wait for printer to start printing
:	ld a, $f
	call SendPrinterPacketNoData
	call WaitVblank
	ldh a, [PrinterStatus]
	cp 6
	jr nz, :-

	; Wait for printer to stop printing
:	ld a, $f
	call SendPrinterPacketNoData
	call WaitVblank
	ldh a, [PrinterStatus]
	cp 4
	jr nz, :-

	; "Send 16 zero bytes to clear the printer’s receive buffer" as Game Boy Camera does
	ld b, 16
:	xor a
	call SendSerialByte
	dec b
	jr nz, :-

	; Only put a margin above the very first print, so remove the margin for prints after that
	xor a
	ld [PrintSettingsMargins], a

	; If there's still bytes left to send, start another print
	ldh a, [ImageBytesLeft+0]
	ld c, a
	ldh a, [ImageBytesLeft+1]
	or c
	jp nz, .transfer
	ret

; BC = min(BC, $280)
; Printer command 4 maxes out at $280 bytes per command, which is 40 tiles worth of data (two rows on the screen)
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
