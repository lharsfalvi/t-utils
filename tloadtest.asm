	PROCESSOR 6502

	SEG text
	ORG $1001

TLOAD_BSS 	SET $1800	; we explicitly set tload's BSS

CINT	EQU $ff81
PRIMM	EQU $ff4f

ST	EQU $90
tstat_e	EQU $d0
tstat	EQU $d1

ptr1	EQU $b2
ptr2	EQU $ac
succ	EQU $9d
fail	EQU $9e

; Workaround for dasm's IFCONST bug
REL_T	SET "N/A"
	INCLUDE "ver.inc"

	INCLUDE "basicstub.asm"
	jmp rstart

	INCLUDE "tload.asm"

	SUBROUTINE

refresh
	txa
	pha
	asl
	tax
	lda .dst,x
	sta ptr2
	lda .dst+1,x
	sta ptr2+1
	lda .src+1,x
	bmi .string
	ldy .src,x
	lda $0000,y
	pha
	ldy #0
	lsr
	lsr
	lsr
	lsr
	tax
	lda .digits,x
	sta (ptr2),y
	iny
	pla
	and #$0f
	tax
	lda .digits,x
	sta (ptr2),y
	bne .loop

.string	and #$7f
	asl
	pha
	lda #0
	sta ptr1+1
	lda .src,x
	tax
	lda $00,x
	asl
	asl
	asl
	asl
	asl
	rol ptr1+1
	sta ptr1
	pla
	tay
	lda .strb,y
	clc
	adc ptr1
	sta ptr1
	lda .strb+1,y
	adc ptr1+1
	sta ptr1+1
	ldy #31
.l0	lda (ptr1),y
	pha
	asl
	rol
	rol
	rol
	and #$03
	tax
	pla
	clc
	adc .conv,x
	sta (ptr2),y
	dey
	bpl .l0

.loop	pla
	tax
	inx
	cpx #10
	bne refresh
	rts

.src	DC.W $00e6, $00e7, $00d0, $80d0
	DC.W $00d1, $81d1, $002e, $002d
	DC.W $009d, $009e

.dst	DC.W $0cab, $0cdb, $0d03, $0d1c
	DC.W $0d53, $0d6c, $0d9a, $0d9c
	DC.W $0dc4, $0de9

.strb	DC.W .extmsg
	DC.W .intmsg

.digits	DC.B '0, '1, '2, '3, '4, '5, '6, '7
	DC.B '8, '9, 'A, 'B, 'C, 'D, 'E, 'F
.conv	DC.B $80, 0, 0, $a0

.extmsg	DC "Press play on tape              "
	DC "Searching                       "
	DC "Loading                         "
	DC "Finished                        "
;	    12345678901234567890123456789012
.intmsg DC "Press play on tape              "
	DC "Seeking file lead-in            "
	DC "Pending found valid lead        "
	DC "Seeking file header start       "
	DC "Reading trailing $ee            "
	DC "Reading header                  "
	DC "Read data                       "
	DC "Read checksum                   "
	DC "Finished                        "


	SUBROUTINE
rstart	jsr CINT
	jsr PRIMM
	DC $0e, $08, $0d
	DC "tLOADTEST",$0d
	DC "tLOAD v", REL_T
	DC.B $0d,$0d,0

	jsr PRIMM
	DC "tIMEBASE: $", $0d
	DC "sIGNAL ASYMMETRY: $", $0d
	DC "lOADER EXT STATE: $", $0d, $0d

	DC "lOADER INT STATE: $", $0d, $0d

	DC "lOADING: $", $0d
	DC "sUCCEEDED: $", $0d
	DC "fAILED: $", 0

	lda #0
	sta succ
	sta fail

	lda $e6
	bne .r0
	lda #$c0
	sta $e6
	lda #0
	sta $e7

.r0	ldx #0
	jsr refresh

.rloop0	jsr tload_init
	lda #.fname-.fnam
	ldx #<.fnam
	ldy #>.fnam
	sei
	sta $ff3f
	jsr tload_start

.rloop	ldx #2
	jsr refresh

	lda #3
	cmp $d0
	bne .rloop

	sei
	jsr tload_stop

	lda ST
	bmi .fail
	inc succ
	DC.B $2c
.fail	inc fail

	ldx #2
	jsr refresh

	jmp .rloop0


;	sta $ff3e
;	jsr $e8c8

;	jmp $ff52

.fnam	DC  "PAYLOAD"
.fname

	ORG $1c00			; primitive test save

	lda #0
	sta .t
.l	lda #$01
	ldx #$07
	ldy #$80
	jsr $ffba
	lda #.fname-.fnam
	ldx #<.fnam
	ldy #>.fnam
	jsr $ffbd
	lda #0
	sta $d0
	sta $d1
	lda #$d0
	ldx #$ff
	ldy #$ff
	jsr $ffd8
	inc .t
	lda .t
	cmp #12
	bne .l
	jmp $ff52

.t	DC.B 0
