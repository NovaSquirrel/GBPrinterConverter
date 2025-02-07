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

SECTION "HRAM", HRAM
temp1:: ds 1
temp2:: ds 1
temp3:: ds 1
temp4:: ds 1
temp5:: ds 1
temp6:: ds 1
temp7:: ds 1
temp8:: ds 1
framecount:: ds 1
RunOamDMA::  ds 8 ; OAM DMA routine
OamWrite:: ds 1 ; OAM write pointer
KeyDown:: ds 1
KeyLast:: ds 1
KeyNew::  ds 1

ImagePointer:: ds 2
ImageBytesLeft:: ds 2

; Print settings
PrintSettingsSheets:: ds 1
PrintSettingsMargins:: ds 1
PrintSettingsPalette:: ds 1
PrintSettingsExposure:: ds 1

; Printer status
PrinterReady::  ds 1
PrinterStatus:: ds 1

; Menu
CurrentMenuImage:: ds 1

SECTION "OAM Data", WRAM0, ALIGN[8]
OamBuffer::
	ds 256
