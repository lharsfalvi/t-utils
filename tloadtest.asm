	PROCESSOR 6502

	SEG.U zero
	ORG $d0
	SEG.U bss
	ORG _textend

	SEG text
	ORG $1001

	INCLUDE "264defs.asm"
	INCLUDE "basicstub.asm"
	jmp rstart
	INCLUDE "tload.asm"

	SUBROUTINE
rstart	jsr CINT
	jsr PRIMM
	DC $0e, $08, $0d
	DC "hELLO!",$0d
	DC 0 
.rloop	jmp .rloop

	
_textend
	SEG.U bss
_bssend
	SEG.U zero
_zeroend
