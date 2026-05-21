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

bll	EQU $e3
blt	EQU $e2

	INCLUDE "tutilscfg.inc"	; global defs
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
	lsr
	ldy .src,x
	tax
	lda $0000,y
	bcc .hex

	cpx #0
	beq .dec

	jsr tload_bin2t

	pha
	txa
	pha
	tya
	pha

	ldy #3
.rt1	pla
	tax
	lda .digits,x
	sta (ptr2),y
	dey
	cpy #1
	bne .rt1

	lda #':
	sta (ptr2),y

	dey
	pla
	tax
	lda .digits,x
	sta (ptr2),y
	jmp .loop

.dec	jsr tload_bin2dec

	cmp #0			; Translate leading 0's to spaces
	bne .rd1
	lda #$10
	cpx #0
	bne .rd1
	tax
	cpy #0
	bne .rd1
	tay
.rd1	pha
	txa
	pha
	tya
	pha

	ldy #2
.rd2	pla
	tax
	lda .digits,x
	sta (ptr2),y
	dey
	bpl .rd2
	bmi .loop

.hex	pha
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
	pha
	asl
	rol ptr1+1
	sta ptr1
	pla
	clc
	adc ptr1
	sta ptr1
	bcc .l00
	inc ptr1+1
.l00	pla
	tay
	lda .strb,y
	clc
	adc ptr1
	sta ptr1
	lda .strb+1,y
	adc ptr1+1
	sta ptr1+1
	ldy #21
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
	cpx #(.dst-.src)/2
	beq .e
	jmp refresh
.e	rts

.src
	IFCONST M_GCR
	DC.W $00e6		; timebase
	DC.W $00e7		; signal (a)symmetry
	ENDIF
	IFCONST M_PLE
	DC.W $00e5		; timebase
	DC.W $00e7		; time threshold hi
	DC.W $00e6		; time threshold lo
	ENDIF
	DC.W $00d0		; state ext (num)
	DC.W $80d0		; state ext (string)
	DC.W $00d1		; state int (num)
	DC.W $81d1		; state int (string)
	DC.W $002e		; loading address hi
	DC.W $002d		; loading address lo
	DC.W $01e3		; blocks left
	DC.W $03e2		; time left
	DC.W $009d		; # succeeded
	DC.W $009e		; # failed

.dst
	DC.W $0cab		; timebase
	IFCONST M_GCR
	DC.W $0cdb		; signal (a)symmetry
	ENDIF
	IFCONST M_PLE
	DC.W $0cd9		; time threshold hi
	DC.W $0cdb		; time threshold lo
	ENDIF
	DC.W $0d24		; state ext (num)
	DC.W $0d28		; state ext (string)
	DC.W $0d74		; state int (num)
	DC.W $0d78		; state int (string)
	DC.W $0dc6		; loading address hi
	DC.W $0dc8		; loading address lo
	DC.W $0dee		; blocks left
	DC.W $0e16		; time left
	DC.W $0e64		; # succeeded
	DC.W $0e8c		; # failed

.strb	DC.W .extmsg
	DC.W .intmsg

.digits	DC.B '0, '1, '2, '3, '4, '5, '6, '7
	DC.B '8, '9, 'A, 'B, 'C, 'D, 'E, 'F
	DC.B $20		; leading 0 hack
.conv	DC.B $80, 0, 0, $a0

.extmsg	DC "Press play on tape      "
	DC "Searching               "
	DC "Loading                 "
	DC "Finished with error     "
	DC "Finished with success   "

;	    123456789012345678901234		24
.intmsg DC "Press play on tape      "
	DC "Seeking lead-in         "
	DC "Pending validity        "
	DC "Seeking header start    "
	DC "Reading leadling $ee    "
	DC "Reading header          "
	DC "Reading data            "
	DC "Reading checksum        "
	DC "Finished with error     "
	DC "Finished with success   "


	SUBROUTINE
rstart	jsr CINT
	jsr PRIMM
	DC $0e, $08, $0d
	DC "tLOADTEST",$0d
	DC "tLOAD v", REL_V
	DC.B $0d,$0d,0

	jsr PRIMM
	DC "tIMEBASE: $", $0d
	IFCONST M_GCR
	DC "sIGNAL ASYMMETRY: $", $0d
	ENDIF
	IFCONST M_PLE
	DC "tIME THRESHOLD: $", $0d, $0d
	ENDIF
	DC "sTATE:     $", $0d, $0d

	DC "iNT STATE: $", $0d, $0d

	DC "lOADING:     $", $0d
	DC "bLOCKS LEFT:  ", $0d
	DC "tIME LEFT: ", $0d, $0d
	DC "sUCCEEDED: $", $0d
	DC "fAILED:    $", 0

	lda #0
	sta succ
	sta fail
	sta $2d
	sta $2e

	lda $e6
	bne .r0
	IFCONST M_GCR
	lda #$c0
	sta $e6
	lda #0
	sta $e7
	ENDIF
	IFCONST M_PLE
	lda #$50
	sta $e6
	lda #$01
	sta $e7
	ENDIF

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

	jsr tload_getprogress
	sta bll
	jsr tload_pr2time
	sta blt

	lda $d0
	cmp #3
	bcc .rloop
	bne .succ

	lda ST
	bpl .rloop
	inc fail
	lda #0
	sta ST
	beq .rloop

.succ	inc succ

	sei
	jsr tload_stop

	ldx #2
	jsr refresh

	jmp .rloop0

.fnam	DC  "PAYLOAD"
.fname
