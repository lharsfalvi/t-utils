	PROCESSOR 6502

	SEG text
	ORG $1001

TLOAD_BSS 	SET $1800	; we explicitly set tload's BSS

CINT	EQU $ff81
PRIMM	EQU $ff4f

;ST	EQU $90
;tstat_e	EQU $d0
;tstat	EQU $d1

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
	stx $ff19
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
				; print byte as minute:10secsec
	jsr tload_bin2t		; translate number to digits

	pha
	txa
	pha
	tya
	pha

	ldy #3			; output secs, 10 secs, ':', mins
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

				; print byte as decimal
.dec	jsr tload_bin2dec	; translate number to dec digits

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

				; print byte as hex
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

				; print as string (look up from dict)
.string	and #$7f
	tay
	lda .src,x
	tax
	lda $00,x
	clc
	adc .strb,y
	asl
	tax
	lda .msgadd,x
	sta ptr1
	lda .msgadd+1,x
	sta ptr1+1
	ldy #21
.l0	lda (ptr1),y
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

.strb	DC.B 0, 5
;.strb	DC.W .extmsg
;	DC.W .intmsg

.digits	DC.B '0, '1, '2, '3, '4, '5, '6, '7
	DC.B '8, '9, 'A, 'B, 'C, 'D, 'E, 'F
	DC.B $20		; leading 0 hack

; Primitive ASCII to screen code and shifted PETSCII conversion.
TS	EQM $7f & ( .. + (..>=$60?$a0))
TP	EQM $ff & ((.. + ((..&$60)==$40?$20)) + ((..&$60)==$60?$e0))

.extmsg	DV TS "Press play on tape      "
	DV TS "Searching               "
	DV TS "Loading                 "
	DV TS "Finished with error     "
	DV TS "Finished with success   "

;	       123456789012345678901234		24
.intmsg DV TS "Press play on tape      "
	DV TS "Seeking lead-in         "
	DV TS "Pending validity        "
	DV TS "Seeking header start    "
	DV TS "Reading leadling $ee    "
	DV TS "Reading header          "
	DV TS "Reading data            "
	DV TS "Reading checksum        "
	DV TS "Finished with error     "
	DV TS "Finished with success   "

.msgadd
MR	SET 0
	REPEAT 15
	DC.W .extmsg+MR
MR	SET MR+24
	REPEND

	SUBROUTINE

rstart	jsr CINT
	jsr PRIMM
	DC $0e, $08, $0d
	DV TP "Tloadtest",$0d
	DV TP "Tload V", REL_V
	DC.B $0d,$0d,0

	jsr PRIMM
	DV TP "Timebase: $", $0d
	IFCONST M_GCR
	DV TP "Signal asymmetry: $", $0d
	ENDIF
	IFCONST M_PLE
	DV TP "Time threshold: $", $0d, $0d
	ENDIF
	DV TP "State:     $", $0d, $0d

	DV TP "Int state: $", $0d, $0d

	DV TP "Loading:     $", $0d
	DV TP "Blocks left:", $0d
	DV TP "Time left:", $0d, $0d
	DV TP "Succeeded: $", $0d
	DV TP "Failed:    $", 0

	lda #0
	sta succ
	sta fail
	sta $2d
	sta $2e

	lda $e6
	bne .r0
	IFCONST M_GCR
	lda #T
	sta $e6
	lda #0
	sta $e7
	ENDIF
	IFCONST M_PLE
	lda #<(T*3)
	sta $e6
	lda #>(T*3)
	sta $e7
	ENDIF

.r0	jsr refresh

.rloop0	jsr tload_init
	lda #.fname-.fnam
	ldx #<.fnam
	ldy #>.fnam
	sei
	sta $ff3f
	jsr tload_start
	lda $ff0a
	and #$fe
	sta $ff0a
	lda #$00
	sta $ff0b

.rloop	lda #$02
	bit $ff09
	beq .rloop+2
	sta $ff09

	IFCONST M_GCR
	ldx #2
	ENDIF
	IFCONST M_PLE
	ldx #3
	ENDIF
	jsr refresh
	lda #$ce
	sta $ff19

	jsr tload_getprogress
	sta bll
	ldy #$de
	sty $ff19
	jsr tload_pr2time
	sta blt
	lda #$ee
	sta $ff19

	lda tstat_e
	cmp #3
	bcc .rloop

	lda st
	bpl .succ
	inc fail
	lda #0
	sta st
	beq .rloop

.succ	inc succ

	sei
	jsr tload_stop

	ldx #2
	jsr refresh

	jmp .rloop0

.fnam	DC  "PAYLOAD"
.fname
