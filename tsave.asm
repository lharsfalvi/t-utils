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

	IF (res1_e-res1_s) > (res2_e-res2_s)
.ws	SET (res1_e-res1_s+39)/40
	ELSE
.ws	SET (res2_e-res2_s+39)/40
	ENDIF

	ldx #.ws
	ldy #0
	clc
	jsr $fff0			; PLOT, set cursor pos
	jsr $ff4f
	DC.B $1b, $54
	DC  "T-SAVE ", MODE, " V", REL_V
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

; this all is still just partly implemented.

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
	sta blstal+3
	sta b_fsta
	lda $b3
	sta blstah+3
	sta b_fsta+1
	lda $9d
	sta blendl+3
	sta b_fend
	lda $9e
	sta blendh+3
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

	ldx #$00
.t8	stx $b1			; misusing $b1 as counter

	IFCONST PLAYITSAFE	; use two normal blocks
	lda #$80
	sta $f7			; first copy
	jsr loadblockparams
	sec
	jsr sblkout
	ldx $b1
	ENDIF

	lda #0
	sta $f7			; second copy
	jsr loadblockparams
	IFCONST PLAYITSAFE
	clc
	ELSE
	sec
	ENDIF
	jsr sblkout

	ldx $b1
	inx
	cpx #$03
	bne .t8

.nobootstrap

	ldx #3
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
; Write out standard tape block
; Partly follows the original Kernal routine at $e4ba
; PASS = $f7
; TYPE = $f8
; WRBASE = $ba/$bb
; EAL/EAH = $9d/$9e
; C = 1 --> long lead, == 0 --> short lead
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
	ldx #$fe
	ldy #$01
	sty $ff03		; kick timer 2
	dec $ff09		; clear pending interrupts
	lda $f8			; TYPE != 0 --> head block
	bcc .l1			; short lead-in on second run
	iny
	lda $f8
	beq .l1
	ldy #$20
.l1	jsr $e413		; write out one pulse
	dex
	bne .l1
	dey
	bne .l1
	ldy #$09
.l2	tya
	ora $f7
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
	ldx #$c2
.l5	jsr $e413		; Write out $00c2 pulses
	dex
	bne .l5
	bit $f7
	bmi .l6

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
.l6	rts

tblkout
	SUBROUTINE
	lda #$d2
.l1	cmp $ff1d
	bne .l1

	IFCONST M_GCR
	lda #T
	sta $ff00
	lda #0
	sta $ff01
	ENDIF
	IFCONST M_PLE
	lda #$ff
	sta $ff02
	sta $ff03
	ENDIF
	dec $ff09

	lda #$05		; $0500*2 lead quintuples
	jsr .writelead

	IFCONST M_GCR		; lead-in end in GCR mode
	lda #%11110
	jsr .writegcrquintuple	; $eee
	lda #$ee		; a.k.a
	jsr .writecbyte	; %111101111011110
	ENDIF

	IFCONST M_PLE		; lead-in end in PLE mode
	lda #$fe
	jsr .writecbyte
	lda #$ee
	jsr .writecbyte
	ENDIF

	lda #0
	bit $ad
	bpl .l01
	lda #1
.l01	jsr .writecbyte		; block type

	bit $ad
	bpl .l02

	ldy #0			; filename
.l6	lda fnam,y
	jsr .writecbyte
	iny
	cpy #$10
	bne .l6

	ldy #0			; start/end addr
.l5	lda $00ba,y
	jsr .writecbyte
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
	jsr .writecbyte

	inc $ba
	bne .l4
	inc $bb
.l4	lda $ba
	cmp $bc
	lda $bb
	sbc $bd
	bcc .l3

	lda $f5
	jsr .writecbyte

	lda #$01		; $0100*2 lead-out quintuples
	jmp .writelead



	IFCONST M_GCR		; GCR low level

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

.writecbyte
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
; ((Y*2-1)*256)+Y*2-1 lead quintuples (%11111)

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

	ENDIF

	IFCONST M_PLE

; Bit to be written in C
.writepulse
	ldy #T-39
	bcs .wp1
	ldy #(T*2)-39
.wp1	ldx #$80

.wrhalf	lda #$10
	sta $ff09
	asl $ff13
.wp2	bit $ff09
	beq .wp2
	lda $ff02
	eor #$ff
	sbc #$06
	sta .wp3
.wp3	EQU *+1
	bcs .wp3
	lda #$a9
	lda #$a9
	lda #$a5
	nop
	stx $01
	sty $ff02
	lda #0
	sta $ff03
	ror $ff13
	stx $ff19
	dex
	bpl .wp4
	rts
.wp4	ldx #$c2
	bne .wrhalf
	
.writecbyte
	sty $a8			; push y
	sec
	rol
	sta $a7			; byte to be written out
.wc1	jsr .writepulse
	asl $a7
	bne .wc1
	ldy $a8			; pull y
	rts

.writelead
	sta $90
	asl
	asl
	adc $90			; *5
	sta $90
	lda #0
	sta $a7
.wl1	sec
	jsr .writepulse		; write "1"
	dec $a7
	bne .wl1		; * 256
	dec $90
	bne .wl1		; *(Y*10-1)
	rts

	ENDIF

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
; tape buffer (part 1, standard)
; IBSOUT vector at $0324 (part 2, standard)
; custom bootstrap code at $0609 (part 3, standard)
; user payload (part 4, custom)
; block type, content start, content end

bltyp	DC.B 3, 0, 0, 1

blstal	DC.B <bootstrap_1_start
	DC.B <bootstrap_2_start
	DC.B <bootstrap_3_start
	DC.B 0

blstah	DC.B >bootstrap_1_start
	DC.B >bootstrap_2_start
	DC.B >bootstrap_3_start
	DC.B 0

blendl	DC.B <bootstrap_1_end
	DC.B <bootstrap_2_end
	DC.B <bootstrap_3_end
	DC.B 0

blendh	DC.B >bootstrap_1_end
	DC.B >bootstrap_2_end
	DC.B >bootstrap_3_end
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

; pull in part 1
	RORG B1S		; $0333
BOOT	SET 1			; select part to be assembled in
	INCLUDE "bootstrap.asm"
	REND

	RORG *-res2_s+$0c00
bootstrap_1_end
b_fsta	EQU *-4
b_fend	EQU *-2
	REND

	RORG *-res2_s+$0c00
bootstrap_2_start
	REND
	
	RORG B2S		; $0324
; pull in part 2
BOOT	SET 2			; select part to be assembled in
	INCLUDE "bootstrap.asm"
	REND
	
	RORG *-res2_s+$0c00
bootstrap_2_end
	REND
	
; bootstrap code, part 3
; loads to $0609+...
; code derives timebase and polarity asymmetry factors
; and loads "part 4" which is user supplied data

	RORG *-res2_s+$0c00
bootstrap_3_start
	REND

	RORG B3S
;bootstrap_3_rstart

; pull part 3 in
BOOT	SET 3			; select part to be assembled in
	INCLUDE "bootstrap.asm"
;bootstrap_3_rend
	REND

	RORG *-res2_s+$0c00
bootstrap_3_end
res2_e
	REND

_textend
	SEG.U bss
_bssend
