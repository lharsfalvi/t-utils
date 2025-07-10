	PROCESSOR 6502

	SEG text
	ORG $1001

	INCLUDE "basicstub.asm"

T	EQU $C0			; Default T = $C0


	SUBROUTINE
tsinst	lda #<tsave
	sta $0330		; ISAVE vector
	lda #>tsave
	sta $0331
	jsr $ff81
	ldx #$00
.l0	lda res1_s,x
	sta $0800,x
	lda res1_s+$100,x
	sta $0900,x
	lda res2_s,x
	sta $0c00,x
	inx
	bne .l0
.l1	lda res1_s+$0200,x
	sta $0a00,x
	inx
	cpx #<res1_e
	bne .l1
	ldx #0
.l2	lda res2_s+$0100,x
	sta $0d00,x
	inx
	cpx #<res2_e
	bne .l2
	
	ldx #$0f
	ldy #0
	clc
	jsr $fff0
	jsr $ff4f
	DC.B $1b, $54
	DC  "T-SAVE"
	DC.B 13,0
	rts


; Secondary address
; b0 - don't want border striping
; b1 - don't want an I/O init at the end of bootstrap
; b2 - want autostart (to AUTOSTART) at the end of bootstrap
; b3 - payload is at BUFSTART (rather than STAL/STAH)
; b4
; b5
; b6
; b7 - don't want a bootstrap

; type
; 0: bootstrap: long lead, 0, no filename, no start/end
; 1: standard: short lead, 1, filename, start/end addr

	ALIGN $100

res1_s

	RORG $0800
	SUBROUTINE
tsave	ldx $ae			; FA; current device number
	cpx #$07
	beq .t1
	jmp $f1a4		; Kernal Save chain

; At this point we have
; logical file in	$ac		LA
; device in		$ae		FA
; secondary address in	$ad		SA
; name len in		$ab		FNLEN
; name ptr in		$af/$b0		FNADR
; start address in	$b2/$b3		STAL/STAH
; end address in	$9d/$9e		EAL/EAH


.t1	lda #$10
	cmp $ab
	bcs .t2
	sta $ab	
.t2	lda $b2
	sta blstal+2
	sta b_fsta
	lda $b3
	sta blstah+2
	sta b_fsta+1
	lda $9d
	sta blendl+2
	sta b_fend
	lda $9e
	sta blendh+2
	sta b_fend+1

	lda #$af
	sta $07df
	ldy #0
.t5	lda #$20
	cpy $ab
	bcs .t6
	jsr $07d9
.t6	sta fnam,y
	iny
	cpy #$10
	bne .t5
	
	jsr $e319		; press play & record
	bcc .t7
	php
	jmp $8ccc		; break error
.t7	jsr $f22c		; Saving <filename>
	jsr $e364		; Screen off, T1, sei
	jsr $e38d		; Motor on

	bit $ad
	bmi .nobootstrap
	
	ldx #0
	jsr loadblockparams
	jsr sblkout
	
	ldx #1
	jsr loadblockparams
	jsr sblkout
	
.nobootstrap

	ldx #2
	jsr loadblockparams
	jsr tblkout

	lda #$ee
	sta $ff19
	ldx #12
	jsr delay
	jsr $e8c8		; Motor off, screen on etc.
	lda #0
	sta $90			; ST
	clc
	rts


; sblkout
; Write out standard tape block (single / second run)
; Partly follows the original Kernal routine at $e4ba
; TYPE = $f8
; WRBASE = $ba/$bb
; EAL/EAH = $9d/$9e
; TYPE != 0 --> long lead, TYPE == 0 --> short lead
; Start of block --> WRBASE
; End of block --> EAL / EAH
; 0840

	SUBROUTINE
sblkout	tsx
	stx $07be		; SRECOV; store SP for STOP handling
	lda $01
	ora #$02
	sta $01			; CST WRT = 1
	jsr $e452		; pulse = #$d0
	ldy #$01
	sty $ff03		; kick timer 2
	lda #$10
	sta $ff09		; clear pending T2 interrupts
	ldx #$fe
	lda $f8			; TYPE != 0 --> head block
	beq .l1			
	ldy #$20
.l1	jsr $e413		; write out one pulse
	dex
	bne .l1
	dey
	bne .l1
	ldy #$09
.l2	tya
	jsr $e48c		; write out one byte
	dey			; 9, 8, 7, ..., 1
	bne .l2			; until 0
	lda $f8
	sta $f5
	beq .l3
	jsr $e48c		; Write out TYPE (if nonzero)
.l3	ldy #0
	sta $ff3f
	lda ($ba),y
	sta $ff3e
	tax
	eor $f5
	sta $f5
	txa
	jsr $e48c		; Write out byte
	inc $ba
	bne .l4
	inc $bb
.l4	lda $ba
	cmp $bc
	bne .l3
	lda $bb
	cmp $bd
	bne .l3
	lda $f5
	jsr $e48c		; Write out CHKSUM
	jsr $e45d		; Set up pulse = 01a4
	jsr $e413		; Write out pulse
	jsr $e452		; Set up pulse = 00d0
	ldy #$01
	ldx #$c2
.l5	jsr $e413		; Write out $00c2 pulses
	dex 
	bne .l5 
	dey 
	bne .l5 
	ldx #3

delay	ldy #$40
	tya
	sec
.d1	sbc #1
	bne .d1
	dey
	bne .d1
	dex
	bne .d1
	rts

tblkout
	SUBROUTINE
	lda #$d2
.l1	cmp $ff1d
	bne .l1

	lda #T
	sta $ff00
	lda #0
	sta $ff01
	dec $ff09

	ldy #$05		; $0500*2 lead quintuples
;	bit $ad
;	bpl .l0
;	ldy #$02		; except for regular files
.l0	jsr .writelead

	lda #%11110
	jsr .writegcrquintuple	; $eee
	lda #$ee		; a.k.a
	jsr .writegcrbyte	; %111101111011110
	
	lda #0
	bit $ad
	bpl .l01
	lda #1
.l01	jsr .writegcrbyte	; block type

	bit $ad
	bpl .l02

	ldy #0			; filename
.l6	lda fnam,y
	jsr .writegcrbyte
	iny
	cpy #$10
	bne .l6

	ldy #0			; start/end addr
.l5	lda $00ba,y
	jsr .writegcrbyte
	iny
	cpy #4
	bne .l5

.l02	ldy #0
	tya
	sta $f5
	
.l3	sta $ff3f
	lda ($ba),y
	sta $ff3e
	tax
	eor $f5
	sta $f5
	txa
	jsr .writegcrbyte
	
	inc $ba
	bne .l4
	inc $bb
.l4	lda $ba
	cmp $bc
	lda $bb
	sbc $bd
	bcc .l3
	
	lda $f5
	jsr .writegcrbyte
	
	ldy #$01		; $0100*2 lead-out quintuples
	jmp .writelead
	
		
; Write out one pulse from C.
; C=0 --> wait until T1 expires
; C=1 --> wait, then invert CST WRT
.writepulse			; One pulse, in C
	pha
	lda #0
	rol
	asl
	eor $01
	tax
	lda #$08
	asl $ff13
.wp1	bit $ff09
	beq .wp1
	sta $ff09
	lda $ff00
	eor #$ff
	sec
	sbc #$0b+~(T)
	sta .wp2
.wp2	EQU *+1
	bcs .wp2 
	lda #$a9
	lda #$a9
	lda #$a5
	nop
	stx $01
	stx $ff19
	ror $ff13
	pla
	rts

.writegcrbyte
	pha
	lsr
	lsr
	lsr
	lsr
	jsr .writegcrnybble
	pla
	and #$0f

.writegcrnybble
	tax
	lda bintogcr,x

.writegcrquintuple
; write out one raw GCR quintuple
	sec
	rol
	asl
	asl
	asl
.wg1	jsr .writepulse
	asl
	bne .wg1
	rts

.writelead
; write out:
; ((Y-1)*256) *2 lead quintuples (%11111)

	tya
	asl
	tay
	sta $90
.wl1	lda #%11111
	jsr .writegcrquintuple
	dec $90			; dummy
	bne .wl1
	dey
	bne .wl1
	rts

bintogcr
	DC.B %01010		; 0
	DC.B %01011		; 1
	DC.B %10010		; 2
	DC.B %10011		; 3
	DC.B %01110		; 4
	DC.B %01111		; 5
	DC.B %10110		; 6
	DC.B %10111		; 7
	DC.B %01001		; 8
	DC.B %11001		; 9
	DC.B %11010		; A
	DC.B %11011		; B
	DC.B %01101		; C
	DC.B %11101		; D
	DC.B %11110		; E
	DC.B %10101		; F


	SUBROUTINE
loadblockparams
	lda bltyp,x
	sta $f8
	lda blstal,x
	sta $ba
	lda blstah,x
	sta $bb
	lda blendl,x
	sta $bc
	lda blendh,x
	sta $bd
	rts

; block tabs
; tape buffer (stage 1, standard)
; custom bootstrap at $0200 (stage 2, standard)
; user payload (part 3, custom)
; block type, (real) start, (real) end

bltyp	DC.B 3, 0, 1

blstal	DC.B <bootstrap_1_start
	DC.B <bootstrap_2_start
	DC.B 0
	
blstah	DC.B >bootstrap_1_start
	DC.B >bootstrap_2_start
	DC.B 0
	
blendl	DC.B <bootstrap_1_end
	DC.B <bootstrap_2_end
	DC.B 0
	
blendh	DC.B >bootstrap_1_end
	DC.B >bootstrap_2_end
	DC.B 0

	REND
res1_e

	ALIGN $100
res2_s
	
; bootstrap code, part 1
; loads and runs in the tape buffer
; pre arranged setup of the tape buffer to be written out
	RORG $0c00
bootstrap_1_start
fnam	EQU *+4
	REND
	
	RORG $0333
	
	DC.W $0200		; will load to $0200
	DC.W $0326		; and end at $0326-1 i.e. IBSOUT
	DS 17,$20		; filename + 1 space
;$0348	
	SUBROUTINE
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
	REND
	
	RORG *-res2_s+$0c00
bootstrap_1_end
b_fsta	EQU *-4
b_fend	EQU *-2
	
; bootstrap code, part 2
; loads to $0200+...
; code derives timebase and polarity asymmetry factors
; and loads "part 4"
; which is user supplied data / with the IRQ loader embedded

bootstrap_2_start
	REND

	RORG $0200
bootstrap_2_rstart

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

bootstrap_2_rend
	REND

	RORG *-res2_s+$0c00
bootstrap_2_end
	REND

res2_e 
	
_textend
	SEG.U bss
_bssend
