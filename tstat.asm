	PROCESSOR 6502

	SEG text
	ORG $1001

/*

Tstat is intended to create stats and deduce "how well"
tload actually works in some particular setup.

Let's define a few things.

Transition detection time:

- the timestamp of a signal transition detection in a particular
sampling setup.

Bit time quantization window:

- the time period where signal transitions are quantized as the
same data bit.

Low threshold time:

- the lower timestamp of the quantization window

High threshold time:

- the higher timestamp of the quantization window

Margin of decoding:

- the transition detection time minus the low threshold time, or
- the high threshold time minus the transition point,

whichever is smaller.


What we ultimately want is statistics of margins encountered
during the simulation of loading particular turbo data blocks.


*/

; Vars "inherited" from standard Kernal and var space
CINT	EQU $ff81
CHROUT	EQU $ffd2
PRIMM	EQU $ff4f

REL_T	SET "N/A"
	INCLUDE "ver.inc"
	INCLUDE "basicstub.asm"


	SUBROUTINE

	jsr CINT
	jsr sample

; shift stats "back" by asymmetry factor
	lda $e7
	eor #$ff
	tay
	iny
	lda #>pr0
	ldx #>pf0
	jsr shift

	lda #>pf0
	ldx #>pf_end
	ldy $e7
	jsr shift

	jsr stat_dev

	jsr show_stat1

	rts

.l	jmp .l



	SUBROUTINE
sample
	jsr $e31b		; press play on tape
	jsr $e364		; Screen off, T1, sei

	lda #$00
	sta $e0
	lda #>bss_start
	ldx #>bss_end
	jsr zerofill

	jsr $e38d

	ldx #$ff		; "a bit of" delay + off screen
.ri1	cpx $ff1d
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

	jsr readraw
	cmp #$1e
	bne .l2

	inc $ff19

.l4	jsr readraw
	cmp #$1f
	bne .l4			; until non-$1f GCR

.le	lda #$ee
	sta $ff19

	clc
	jsr $e3b0
	jmp $e378

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
	sta $e6
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
.w2	beq .w1			; an (in)accuracy of ~3 single clock
				; cycles
	asl $ff13
	lda $ff02		; read timestamp
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


	bit $e6
	bpl .w4

	ldy $d4,x
	cmp #$04
	bcc .w3
	ldy #$ff
	lda #$03
.w3	clc
	adc .wwind,x
	sta $e1
	lda ($e0),y
	adc #$01
	sta ($e0),y
	bcc .w4
	lda #2
	adc $e1
	sta $e1
	lda ($e0),y
	adc #$01
	sta ($e0),y
	bcc .w4
	lda #2
	adc $e1
	sta $e1
	lda ($e0),y
	adc #$01
	sta ($e0),y

.w4	lda $d6,x
	rts

.wcode	DC.B $f0, $d0		; beq, bne
.wwind	DC.B >pr0, >pf0		; rising, falling

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
;	bcs .rp2

;	stx $40
;	lda $d4,x
;	tax
;	inc remns,x
;	bne .rp3
;	inc remns+$100,x
;	bne .rp3
;	inc remns+$200,x
;.rp3	ldx $40

.rp2	lda $b6			; if still above 0, we have a 0
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
	php
	ldy $e4			; pull y
	and #$0f
	ora $b7
	plp
	rts

.readgcrnybble
	lda #%00001000
	sta $b6
.rgn	jsr readpulse
	bcc .rgn
	and #$1f
	tay
	lda gcrtobin,y
	rts

readraw
	lda #%00001000
	sta $b6
.rwn	jsr readpulse
	bcc .rwn
	rts




gcrtobin
	DC.B $7f		; 0-8, aren't valid GCR nybbles
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $7f
	DC.B $08		; $09 %01001
	DC.B $00		; $0a %01010
	DC.B $01		; $0b %01011
	DC.B $7f
	DC.B $0c		; $0d %01101
	DC.B $04		; $0e %01110
	DC.B $05		; $0f %01111
	DC.B $7f
	DC.B $7f
	DC.B $02		; $12 %10010
	DC.B $03		; $13 %10011
	DC.B $7f
	DC.B $0f		; $15 %10101
	DC.B $06		; $16 %10110
	DC.B $07		; $17 %10111
	DC.B $7f
	DC.B $09		; $19 %11001
	DC.B $0a		; $1a %11010
	DC.B $0b		; $1b %11011
	DC.B $7f
	DC.B $0d		; $1d %11101
	DC.B $0e		; $1e %11110
	DC.B $ff		; $1f invalid GCR nybble


	SUBROUTINE

; start page in A
; end page+1 in X

zerofill
	stx $d2
	sta $d1
	ldy #0
	sty $d0
.z1	tya
.z0	sta ($d0),y
	iny
	bne .z0
	inc $d1
	lda $d1
	cmp $d2
	bne .z1
	rts

	SUBROUTINE

; start page in A
; end page +1 in X
; shift in Y

shift	cpy #0
	beq .end
	bpl shup
	jmp shdown

shup	sta $d4
	dex
	stx $d1
	stx $d3
	sty $d5

	lda #0
	sta $d2
	sec
	sbc $d5
	sta $d0
	lda $d1
	sbc #$00
	sta $d1

	lda $d3
	cmp $d4
	beq .lastpage

	ldy #$ff
.l1	lda ($d0),y
	sta ($d2),y
	dey
	bne .l1
	lda ($d0),y
	sta ($d2),y
	dey

	dec $d1
	dec $d3
	lda $d3
	cmp $d4
	bne .l1

.lastpage
.l2	lda ($d0),y
	sta ($d2),y
	dey
	cpy $d5
	bne .l2
	lda ($d0),y
	sta ($d2),y

.end	rts

	SUBROUTINE
shdown	sta $d1
	sta $d3
	dex
	stx $d4
	sty $d6
	dey
	tya
	eor #$ff
	sta $d5
	sta $d0
	ldy #0
	sty $d2

	cpx $d1
	beq .lastpage

.l1	lda ($d0),y
	sta ($d2),y
	iny
	bne .l1

	inc $d1
	inc $d3

	lda $d1
	cmp $d4
	bne .l1

.lastpage
.l2	lda ($d0),y
	sta ($d2),y
	iny
	cpy $d6
	bne .l2
	rts

	SUBROUTINE
stat_dev			; max deviations from nominal
	lda $e6
	lsr
	sta $d0
	sta $d2
	sta $d4
	sta $d6
	lda #>pr0
	sta $d1
	clc
	adc #$03
	sta $d3
	adc #$03
	sta $d5

	ldx #0
.l2	ldy #0
.l1	lda ($d0),y
	ora ($d2),y
	ora ($d4),y
	bne .s1
	iny
	cpy $d6
	bne .l1

.s1	sty $d7
	sec
	lda $d6
	sbc $d7
	sta max_dev,x
	inx

	ldy $e6
.l3	lda ($d0),y
	ora ($d2),y
	ora ($d4),y
	bne .s2
	dey
	cpy $d6
	bne .l3

.s2	tya
	sec
	sbc $d6
	sta max_dev,x
	inx
	cpx #$06
	beq .p2
	cpx #$0c
	beq .end

	lda $d0
	clc
	adc $e6
	sta $d0
	sta $d2
	sta $d4
	lda $d1
	adc #$00
	sta $d1
	adc #$03
	sta $d3
	adc #$03
	sta $d5
	bne .l2

.p2	lda $d6
	sta $d0
	sta $d2
	sta $d4
	lda #>pf0
	sta $d1
	clc
	adc #$03
	sta $d3
	adc #$03
	sta $d5
	bne .l2

.end	rts

	SUBROUTINE
show_stat1
	jsr PRIMM
	DC $0d, $0d, "MEASURED TIMING: ", $00
	lda #$00
	ldx $e6
	jsr $a45f

	jsr PRIMM
	DC $0d, "ASYMMETRY (RISING EDGE): ", $00
	lda #$00
	ldx $e7
	jsr $a45f

	jsr PRIMM
	DC $0d, $0d, "MAX DEVIATIONS (-,+):", $0d, $0d, $00

	ldx #0
	stx $d0
	stx $d2
	lda $e6
	sta $d1
	jsr PRIMM
	DC "RISING:", $0d, $00
.l1	lda $d2
	ldx $d1
	jsr $a45f
	jsr PRIMM
	DC ": ", $00
	ldx $d0
	lda max_dev,x
	tax
	lda #0
	jsr $a45f
	inc $d0
	jsr PRIMM
	DC ", ", $00
	ldx $d0
	lda max_dev,x
	tax
	lda #0
	jsr $a45f
	lda #$0d
	jsr CHROUT
	lda $d1
	clc
	adc $e6
	sta $d1
	lda $d2
	adc #$00
	sta $d2
	inc $d0
	lda $d0
	cmp #$0c
	beq .end
	cmp #$06
	bne .l1
	jsr PRIMM
	DC $0d, "FALLING:", $0d, $00
	lda $e6
	sta $d1
	lda #$00
	sta $d2
	beq .l1

.end	rts


t_end

	SEG.U bss
	ORG t_end

	ALIGN $100
bss_start
;remns	DS $300			; remainders

pr0	DS $300
pr1	DS $300
pr2	DS $300

pf0	DS $300
pf1	DS $300
pf2	DS $300
pf_end

max_dev	DS 3*2*2		; 3 len, +/-, r/f

bss_end

	SEG text


