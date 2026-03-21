	IFCONST mod_bootstrap
	PROCESSOR 6502
	ENDIF

; Could as well be called the tload "polling mode loader". Though,
; there's no standalone full-fledged polling-mode tload (yet?).

; T-load bootstrap loader, with
; - inits
; - generating stats (by measuring the header's timings)
; - polling loader (with a minimal feature set)
; - autostart control

; Code is split into three parts.

; First part loads into the tape buffer ($0333-$03f2) with the
; tape file header, and contains init, controls, main loop, and
; end-of-load logic, execution control.

; Second part loads to $0324-$0326 (IBSOUT) and autostarts "part1"
; at $0348.

; Third part loads to $0609 and contains specific routines for
; signal handling.

; The parts need to be included / merged from an external asm
; file (see tsave.asm and bootstrapmod.asm).

	IF BOOT == 1

; part 1 ($0333)

	SUBROUTINE

	DC.W B2S		; load part 2 to $0324
	DC.W B2E		; up until $0326-1 i.e. IBSOUT
;$0337
.o_fnam
	DS 17,$20		; filename + 1 space
;$0348
	jsr $e364		; Screen off, T1, sei
	jsr $ff8a		; RESTOR (kernal vector table)

	ldx #3
.bs5	lda .dat-4,x
	sta $07c0,x
	lda .dat,x
	sta $2d,x
	dex
	bpl .bs5
	
	jsr $e910		; load part 3
	bcs .bs4

.o_oscr				; open screen switch offset
	IFCONST M_PLE
	IFCONST OPENSCREEN
	sei			; 78 24 e3
	bit $e3
	ELSE
	jsr $e364		; Screen off, T1, sei
	ENDIF			; 20 64 e3
	ELSE
	jsr $e364		; Screen off, T1, sei
	ENDIF
	jsr $e38d		; Tape start, wait 600ms

.l2	jsr readlead		; find $ff lead, get T

	dec $ff09
	lda #$ff
	sta $b6
	IFCONST M_GCR
	sta $d7
	ENDIF
.l3	jsr readbit
	cmp #$ff
	beq .l3

	jsr readbyte
	cmp #$ee
	bne .l2

	jsr readbyte		; skip type byte

	ldy #0
	sty $f5
.l8	jsr readbyte
	ldy #0
	sta ($2d),y
	eor $f5
	sta $f5

	inc $2d
	bne .l9
	inc $2e
.o_binc
	IFCONST BORDER_STR
	IFCONST BORDER_INC
	inc $ff19		; ee 19 ff
	ELSE
	bit $ff19		; 2c 19 ff
	ENDIF
	ENDIF
.l9	lda $2d
	cmp $2f
	lda $2e
	sbc $30
	bcc .l8

	jsr readbyte
	pha

.o_bresv 	EQU *+1
	lda #BORDER_RES		; a9 ee
.o_bres
	IFCONST BORDER_STR
	sta $ff19		; 8d 19 ff
	ELSE
	bit $ff19		; 2c 19 ff
	ENDIF
	jsr $e3b0		; motor off
.o_osrs	EQU *+1			; 78, 81
	IFCONST OPENSCREENRST
	jsr $e378		; screen on, irq on
	ELSE
	jsr $e381		; irq on
	ENDIF
	pla
	cmp $f5
	beq .bs3
.bs4	jmp $a82b		; load error
.bs3	jsr $8a93		; Basic start load, clr
	clc
.o_sta	EQU *+1
	jmp $8703		; 03 87 / cd 8b / yy xx

	IFCONST M_GCR
gcrtobin
;	DC.B $ff		; 0-8, aren't valid GCR nybbles
;	DC.B $ff		; so we get rid of them
;	DC.B $ff
;	DC.B $ff
;	DC.B $ff
;	DC.B $ff
;	DC.B $ff
;	DC.B $ff
;	DC.B $ff
	DC.B $08		; $09 %01001
	DC.B $00		; $0a %01010
	DC.B $01		; $0b %01011
	DC.B $ff
	DC.B $0c		; $0d %01101
	DC.B $04		; $0e %01110
	DC.B $05		; $0f %01111
	DC.B $ff
	DC.B $ff
	DC.B $02		; $12 %10010
	DC.B $03		; $13 %10011
	DC.B $ff
	DC.B $0f		; $15 %10101
	DC.B $06		; $16 %10110
	DC.B $07		; $17 %10111
	DC.B $ff
	DC.B $09		; $19 %11001
	DC.B $0a		; $1a %11010
	DC.B $0b		; $1b %11011
	DC.B $ff
	DC.B $0d		; $1d %11101
	DC.B $0e		; $1e %11110
;	DC.B $ff
	ENDIF
	
	DS B1E-8-*, 0		; zero padding

	DC.W B3S		; part 3 start / len
	DC.W ~(B3E-B3S-1)
.o_stradd
.dat	DC.W 0			; payload (part 4) start / end
.o_endadd
	DC.W 0
;$03f2
	ENDIF

; part 2 ($0324)
	IF BOOT == 2

	DC.W B1S+$15		; IBSOUT $0324 --> $0348
				; execs bootstrap part 1 at $0348

	ENDIF

; part 3 ($0609)
	IF BOOT == 3

	IFCONST M_GCR		; GCR mode bit / byte read

;X=0 --> rising
;X=1 --> falling

; d0	edge time, low
; d2	edge time, high
; d4	current T, low
; d6	current T, high
; d8	cumulated T, b1
;	and temporary time threshold factor, low
; da	cumulated T, b2
; dc	cumulated T, b3

; $e4	pulse counter
; $e6	Measured timebase
; $e7	Positive edge delay correction (from $db)

readlead
	asl $ff13
	stx $ff02
	stx $ff04
	stx $ff03
	stx $ff05
	ror $ff13

.rl0	lda #$80		; rounding bias
	sta $da
	sta $db
	lda #0
	sta $d8			; cumulators
	sta $d9
	sta $dc
	sta $dd
	sta $e4
	lda #$10		; >number of lead pulses
	sta $e5

.rl1	ldx #0
	jsr .waitflip		; rising edge
	jsr .cumulate
	inx
	jsr .waitflip		; falling edge
	bne .rl0		; T > $0100, see ya
	jsr .cumulate
	lda $d6
	bne .rl0		; T > $0100, see ya

	lda $d4
	sbc $d5
	bcs .rl2
	eor #$ff
.rl2	cmp #$40		; has to be roughly symmetric
	bcs .rl0		; or see ya

	dec $e4
	bne .rl1
	dec $e5
	bne .rl1

	clc
	lda $dc
	adc $dd
	ror
	sta $e6			; store timebase
	tay

	sec
	sbc $dd
	sta $e7			; rising edge asymmetry delay

	tya
	lsr
	tay
	adc $e7
	sta $d8			; precalc correction for read
	tya
	sbc $e7
	sta $d9			; and for the opposite pulse
	rts

.waitflip
	lda .wcode,x
	sta .w2

	lda #$10
.w1	bit $01			; wait CST_RD' to flip
.w2	beq .w1

	asl $ff13		; read timestamp
	lda $ff02
	ldy $ff05
	ror $ff13

	sta $d0,x
	sty $d2,x

	txa			; opposite phase index
	eor #$01
	tay

	lda $ff19
	clc
.o_brmod
	IFCONST BORDER_EOR
	eor #BORDER_MOD		; 49 xx
	ELSE
	adc #BORDER_MOD		; 69 xx
	ENDIF
.o_brsta	
	IFCONST BORDER_STR
	sta $ff19		; 8d 19 ff
	ELSE
	bit $ff19		; 2c 19 ff
	ENDIF

	lda $00d0,y		; derive T
	sbc $d0,x
	sta $d4,x
	lda $00d2,y
	sbc $d2,x
	sta $d6,x
	rts

.wcode	DC.B $f0, $d0		; beq, bne

.cumulate
	clc
	lda $d4,x
	adc $d8,x
	sta $d8,x
	bcc .cu1
	lda #$0f
	adc $da,x
	sta $da,x
	bcc .cu1
	inc $dc,x
.cu1	rts

readbit
	lda $d6,x		; do we have time left?
	bpl .rp1		; pos, yes we do.

	txa			; flip edge polarity
	eor #$01
	tax
	jsr .waitflip		; #findnext

	lda $d4,x
	sbc $d8,x		; sub T/2 +- edge corr.
	sta $d4,x
	bcs .rp1
	dec $d6,x

.rp1	lda $d4,x
	sec
	sbc $e6
	sta $d4,x
	lda $d6,x
	sbc #0
	sta $d6,x

	lda $b6			; if still above 0, we have a 0
	rol
	eor #$01
	sta $b6
	rts

readbyte
	jsr .readgcrnybble
	asl
	asl
	asl
	asl
	sta $b7
	jsr .readgcrnybble
	and #$0f
	ora $b7
	rts

.readgcrnybble
	lda #%00001000
	sta $b6
.rgn	jsr readbit
	bcc .rgn
	and #$1f
	tay
	lda gcrtobin-9,y
	rts
	ENDIF

	IFCONST M_PLE		; PLE mode bit / byte read

; $dd	last timestamp
; $de	last timestamp, buffer
; $df	last full pulse T, low
; $e0	last full pulse T, high
; $e1	cumulated T, b1
; $e2	cumulated T, b2
; $e3	cumulated T, b3

; $e4	pulse counter, low
; $e5	pulse counter, high

; --> should be preserved
; $e6	measured threshold, low
; $e7	measured threshold, high

readlead
.rl0	lda #0
	sta $e1			; cumulators
	sta $e2
	sta $e3
	sta $e4
	lda #<(T*3-6)
	sta $e6
	lda #>(T*3-6)
	sta $e7			; initial threshold
	lda #$80
	sta $e4
	lda #$01		; number of lead pulses
	sta $e5

.rl1	jsr .waitfall

	lda $dd
	sec
	sbc $de
	stx $dd
	sta $df
	lda $de
	sec
	sbc $dd
	clc
	adc $df
	sta $df
	lda #0
	rol
	sta $e0

	lsr
	lda $df
	ror
	cmp #(T+T/2)
	bcs .rl0		; >T+50%, retry

	jsr .cumulate

	dec $e4
	bne .rl1
	dec $e5
	bpl .rl1

	lda $e3
	cmp #$02
	bcs .rl0
	sta $e7
	lda $e2
	sbc #$05		; threshold adjustment
	sta $e6
	rts

readbyte
	lda #$01
	sta $b6
readbit
.rb1	jsr .waitfall
	lda #$10
	and $ff09
	sta $ff09
	sbc #$02
	asl
	rol $b6
	bcc .rb1
	lda $b6
	rts
	
.cumulate
	clc
	lda $df
	adc $e1
	sta $e1
	lda $e0
	adc $e2
	sta $e2
	bcc .cu1
	inc $e3
.cu1	rts

.waitfall
	lda #$10		; wait for CST_RD to make a full cycle
.rrb1	bit $01
	beq .rrb1
	ldx $ff04
	stx $de
	ldx $e6
	ldy $e7
.rrb2	bit $01
	bne .rrb2		; until falling edge
	stx $ff02
	sty $ff03
	ldx $ff04
	lda $ff19		; border striping
	clc
.o_brmod
	IFCONST BORDER_EOR
	eor #BORDER_MOD		; 49 xx
	ELSE
	adc #BORDER_MOD		; 69 xx
	ENDIF
.o_brsta	
	IFCONST BORDER_STR
	sta $ff19		; 8d 19 ff
	ELSE
	bit $ff19		; 2c 19 ff
	ENDIF
	rts

	ENDIF

B3E	SET *

	ENDIF
