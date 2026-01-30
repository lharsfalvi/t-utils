	PROCESSOR 6502

	SEG text
	ORG $1001

	INCLUDE "tutilscfg.inc"
	INCLUDE "ver.inc"

	INCLUDE "basicstub.asm"

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
	DC  "T-SAVE V", REL_V
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
	ldy #$02
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
	RORG $0c00
bootstrap_1_start
fnam	EQU *+4
	REND

	RORG $0333
; part 1
BOOT	SET 1			; select part to be assembled in
	INCLUDE "bootstrap.asm"

	REND

	RORG *-res2_s+$0c00
bootstrap_1_end
b_fsta	EQU *-4
b_fend	EQU *-2

; bootstrap code, part 2
; loads to $0200+...
; code derives timebase and polarity asymmetry factors
; and loads "part 3"
; which is user supplied data

bootstrap_2_start
	REND

	RORG $0200
bootstrap_2_rstart

; should include part 2 here
BOOT	SET 2			; select part to be assembled in
	INCLUDE "bootstrap.asm"

bootstrap_2_rend
	REND

	RORG *-res2_s+$0c00
bootstrap_2_end
	REND

res2_e

_textend
	SEG.U bss
_bssend
