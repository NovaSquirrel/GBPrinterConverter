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
