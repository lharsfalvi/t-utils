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

; Code is split into two parts.

; First part loads into the tape buffer ($0333-$03f2) with the
; tape file header, and contains init, controls, main loop, and
; end-of-load logic, execution control.

; Second part loads to $0200 up until the IBSOUT vector ($0324-$0325),
; which in turn autostarts "part 1" at $0348. It contains
; specific routines for signal handling.

; The parts need to be included / merged from a third, external
; asm file (see tsave.asm and bootstrapmod.asm).

	IF BOOT == 1

; part 1 ($0333)

	SUBROUTINE

	DC.W $0200		; load part 2 to $0200
	DC.W $0326		; up until $0326-1 i.e. IBSOUT
;$0337	DS 17,$20		; filename + 1 space
;$0348
	jsr $e364		; Screen off, T1, sei
	lda #$c0
	sta $01
	jsr $ff8a

	ldx #3
.bs5	lda .dat,x
	sta $2d,x
	dex
	bpl .bs5

	txa			; "a bit of" delay + off screen
.ri1	cmp $ff1d
	bne .ri1
	dex
	bne .ri1

	asl $ff13
	stx $ff02
	stx $ff04
	stx $ff03
	stx $ff05
	ror $ff13

.l2	jsr readlead		; find $ff lead, get T

	lda #$ff
	sta $b6
	sta $d7			; init
.l3	jsr readpulse
	cmp #$ff
	beq .l3

	jsr readgcrbyte
	cmp #$ee
	bne .l2

	jsr readgcrbyte

	ldy #0
	sty $f5
.l8	jsr readgcrbyte
	sta ($2d),y
	eor $f5
	sta $f5

	inc $2d
	bne .l9
	inc $2e
	inc $ff19
.l9	lda $2d
	cmp $2f
	lda $2e
	sbc $30
	bcc .l8

	jsr readgcrbyte
	pha

	lda #$ee
	sta $ff19
	jsr $802e		; Basic reset
	jsr $e8c8		; Motor off, screen on, irq on
	pla
	cmp $f5
	beq .bs3
	jmp $a82b		; load error
.bs3	jsr $8a9a		; Basic clr
	clc
	bit $8bbe
	jmp $8703

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

	DS $03ee-*, 0
.dat	DC.W 0
	DC.W 0
;$03f2
	ENDIF

; part 2 ($0200)
	IF BOOT == 2

	SUBROUTINE

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
	eor #$41
	sta $ff19

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


readpulse
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


readgcrbyte
	sty $e4			; push Y
	jsr .readgcrnybble
	asl
	asl
	asl
	asl
	sta $b7
	jsr .readgcrnybble
	ldy $e4			; pull y
	and #$0f
	ora $b7
	rts

.readgcrnybble
	lda #%00001000
	sta $b6
.rgn	jsr readpulse
	bcc .rgn
	and #$1f
	tay
	lda gcrtobin-9,y
	rts


	DS $0300-*, 0

	DC.B $86, $86, $12, $87, $56, $89, $6e, $8b
	DC.B $d6, $8b, $17, $94, $6a, $89, $88, $8b
	DC.B $8b, $8c, $42, $ce, $0e, $ce, $4c, $f4
	DC.B $53, $ef, $5d, $ee, $18, $ed, $60, $ed
	DC.B $0c, $ef, $e8, $eb

	DC.W $0348		; IBSOUT, $0324
				; execs bootstrap part 1 at $0348

	ENDIF
