	PROCESSOR 6502

	SEG text
	ORG $1001

CINT	EQU $ff81
PRIMM	EQU $ff4f

; Workaround for dasm's IFCONST bug
REL_T	SET "N/A"
	INCLUDE "ver.lst"

	INCLUDE "basicstub.asm"
	jmp rstart

	INCLUDE "tload.asm"

	SUBROUTINE
rstart	jsr CINT
	jsr PRIMM
	DC $0e, $08, $0d
	DC "Tloadtest",$0d
	DC "Tload V", REL_T
	DC.B 13,0

	lda $e6
	bne .r0
	lda #$c0
	sta $e6
	lda #0
	sta $e7
.r0	jsr tload_init
	lda #.fname-.fnam
	ldx #<.fnam
	ldy #>.fnam
	sei
	sta $ff3f
	jsr tload_start

	lda #3
.rloop	cmp $d0
	bne .rloop

	sei
	jsr tload_stop
	sta $ff3e
	jsr $e8c8

	jmp $ff52

.fnam	DC  "PAYLOAD"
.fname
