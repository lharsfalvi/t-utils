	PROCESSOR 6502

	INCLUDE "tutilscfg.inc"	; global defs
	INCLUDE "tloadcfg.inc"	; defs and vars
	INCLUDE "ver.inc"

	SUBROUTINE

	SEG.U bss
	ORG TLOAD_BSS

.ctabl	DS $100			; runlen
.ctabj	DS $100			; jump next
.ctabr	DS $100			; remaining last
.cbuf	DS 39			; circular data buffer
.quant	DS $20			; quantization tables
.restor DS 3			; irq restore temp
.tbuf	DS 1+16+4		; block type, filename, start/end
	SEG text

	IFCONST mod_tload	; if we're building standalone tload
	ORG TLOAD_TEXT-2	; put down file load address word
	DC.W *+2
	ENDIF

; tstat
;00	waiting for datasette play button to be pressed
;01	searching for a lead
;02	found lead, counting
;03	found lead, searching for first 0 bit, correct phase when found
;04	read lead's trailing $ee byte
;05	read header, compare filename
;06	read data
;07	read and compare checksum
;08	complete (idle)

;b7	0 --> raw, 1--> GCR

; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (success in ST)

; bitstor
;b0	LSB of previously read raw octet

; name len in		$ab		FNLEN
; name ptr in		$af/$b0		FNADR

tload_init
	jmp .tload_init
tload_start
	jmp .tload_start
tload_stop
	jmp .tload_stop
; Version string
	DC "V", REL_V

; filename length in A, pointer in X/Y
.tload_start
	stx FNADR
	sty FNADR+1
	cmp #$10
	bcc .ts1
	lda #$10
.ts1	sta FNLEN
	lda #0
	sta tstat
	sta tstat_e
	sta ST
	sta polar
	sta cacc
	sta pstat
	sta .wcsr
	sta rcsr
	jsr .setstatvect
	lda #$80
	sta sacc
	sta $07fc
	lda #%00001000
	sta pacc
	lda #1
	sta gacc

	sei
	lda $ff0a
	ldx $fffe
	ldy $ffff
	sta .restor
	stx .restor+1
	sty .restor+2
	lda #<.tload_irq
	ldx #>.tload_irq
	sta $fffe
	stx $ffff
	jsr .settimers
	lda #$08
	sta $ff0a
	sta $ff09
	cli
	rts

.tload_stop
	php
	sei
	lda #$c8
	sta $01
	lda .restor
	sta $ff0a
	sta $ff09
	lda .restor+1
	sta $fffe
	lda .restor+2
	sta $ffff
	plp
	rts

; load timers
.settimers
	lda #$fc
.st1	cmp $ff1d
	bne .st1
	lda #$fe
.st2	cmp $ff1d
	bne .st2
	lda $ff1e
	sec
	sbc #$d0
	lsr
	sta .stj1
.stj1	=*+1
	bcc .stj1
	cmp #$c9
	cmp #$c9
	cmp #$c5
	nop
	ldx #$08
.st3	dex
	bpl .st3
	cmp $c5
	lda #57
	sta $ff00
	lda #0
	sta $ff01
	lda #$01
.st4	bit $ff1c
	bne .st4
	cmp $ff1d
	bne .st4		; returns on line 1
	rts


; raster line number map
; (line number where .tl2 happens)
; pos			line	line/2
; first char		2	1
; last char		c2	61
; first free		ca	65
; last free, PAL	132	99
; truncated chunk, NTSC	ca	65
; last free, NTSC	100	80

.tload_fastirq
				; 0-6 IRQ ack delay
				; 7 IRQ state save + jmp
	stx $ff09		; 4
	cpx $01			; 3
	rol sacc		; 5
	bcs .tlfast2		; 2 / 3		22
	rti			; 6		27
.tlfast2
	pha			; 3
	bcs .tl2		; 3		28

.tload_irq
				; 0-6 IRQ ack delay
				; 7 IRQ state save + jmp
	pha			; 3
	lda #$c8		; 2
	cmp $01			; 3
	sta $ff09		; 4 ACK IRQ
	rol sacc		; 5
	bcs .tl2		; 2 / 3		27
	pla			; 4
	rti			; 6		36


.tl2	lda sacc		; 3
.wcsr	=*+1					; write cursor
	sta .cbuf		; 4
	lda #1			; 2
	sta sacc		; 3
	inc .wcsr		; 6
	lda .wcsr		; 4
	cmp #26			; 2
	bcc .badline		; 2 / 3		26 / 27

.rset1	=*+1
	cmp #39
	bne .nobadline
	lda #0			; buffer loop
	sta .wcsr
.sset	=*+1
	lda #1			; ntsc line number fix
	sta sacc
	bne .nobadline

.badline
	lda #$c8		; 2
; spend x cycles so that cmp happens at cmp(-1) + 65

	pha
	pla
	pha
	pla
	nop
	bit $ff

	cmp $01			; 3
	rol sacc		; 5
	pha			; 3
	pla			; 4
	pha			; 3
	pla			; 4		22

	cmp $01			; 3
	rol sacc		; 5
	pha
	pla
	pha
	pla

	cmp $01			; 3
	rol sacc		; 5
	sta $ff09		; 4

.nobadline
	cli
	lda pstat
	beq .doprocess

	pla
	rti

; in cbuf: %00abcdef
.ntscfix			; once per frame
	lda #$20
	and .cbuf
	bne .nt1
	lda #$c0
.nt1	ora .cbuf
	sta stmp
;%!a!aabcdef
	and #$3f
	lsr
	bcc .nt2
	ora #$c0
.nt2	rol
	rol
	rol

	bcc .tent

;%abcdefff


.doprocess
	dec pstat
	stx xstor
	ldx #$c8
	lda #<.tload_fastirq
	sta $fffe
	sty ystor
	IFCONST mod_tloadtest
	stx $ff19
	ENDIF

.tlpl	ldy rcsr
.nsw	=*
	bmi .ntscfix		; pal/ntsc switch bmi/beq

.tlpl1	lda .cbuf,y		; load sample
	sta stmp
.tent	tay
	eor polar
	asl
	tya
	bcs .process1		; polarity has flipped on byte boundary

	lda .ctabl,y
	bmi .tp0		; no change
	adc cacc
	bcc .process

.tp0	ldy stmp
	sty ytmp
	lda .ctabr,y
	adc cacc
	sta cacc
	bpl .prend
	lda #$0f
	bcc .process2

.prend	ldy rcsr
	iny
.rset2	=*+1
	cpy #39			; pal: 39, ntsc: 33
	bne .tlp2
	ldy #0
.tlp2	sty rcsr
	cpy .wcsr
	bne .tlpl

.irqe	ldy ystor
	lda #<.tload_irq
	sta $fffe
	ldx xstor
	IFCONST mod_tloadtest
	lda #$ee
	sta $ff19
	ENDIF
	inc pstat
        pla
        rti

.process
	sta cacc
	lda .ctabj,y
.process1
	sta ytmp
	lda cacc
	and #$0f
.process2
	bit polar
	bmi .tp1
	ora #$10
.tp1	tay
	lda .quant,y
	asl
	rol pacc
	bcc .tp2
	pha
	jsr .dostate
	pla
.tp2	asl
	beq .tpe
	rol pacc
	bcc .tp3
	pha
	jsr .dostate
	pla
.tp3	asl
	beq .tpe
	rol pacc
	bcc .tpe
	jsr .dostate

.tpe	ldy ytmp
	sty polar
	lda .ctabj,y
	sta ytmp
	lda .ctabl,y
	bpl .process2
	ldy stmp
	lda .ctabr,y
	sta cacc
	jmp .prend

; Call current state handler
.dostate
	lda pacc
	ldy #%00001000
	sty pacc

	bit tstat		; are we pre- or within a gcr field
	bpl .tjmp		; pre, process raw

	tay			; do gcr decoding
;	lda .gcrtobin,y		; check for GCR code error
;	bmi .gcrerror
	lda gacc
	asl
	asl
	asl
	asl
	ora .gcrtobin,y
	bcc .de

	ldy #1
	sty gacc

.tjmp	jmp .s_pressplay	; call current state handler
				; pacc or gacc in A

.de	sta gacc
	rts


; ---- state machine routines

;00	waiting for play button to be pressed
.s_pressplay
	lda #$04
	bit $fd10
	bne .s_exit
	lda #$c0		; motor on
	sta $01
	lda #$00
	sta polar		; start by finding a rising edge
	inc tstat_e
	jmp .incstat

;01	searching for a lead
.s_seeklead
	cmp #$1f		; pacc in A
	bne .s_exit
	lda #$a0
	sta tcnt
	jmp .incstat

;02	found lead, counting
.s_countlead
	cmp #$1f
	bne .s_c1
	dec tcnt
	beq .s_c2		; countlead exits with tcnt=0
	rts
.s_c1	dec tstat
	jmp .setstatvect
.s_c2	jmp .incstat

;03	found lead, searching for first 0 bit
.s_findzero
	cmp #$1f
	beq .s_exit

	sec			; do sync
	rol			; a.k.a. throw away bits
	asl			; before and including leading 0
.s_f1	asl			; and prepare to read next nybble
	bmi .s_f1		; from this point
	lsr
	lsr
	sec
.s_f2	ror
	bcc .s_f2

	sta pacc
	lda tstat
	clc
	adc #$81
	sta tstat		; also raise GCR decode strobe
	jmp .setstatvect

;04	read lead's trailing $ee byte
.s_r_ee
	cmp #$ee		; gacc in A
	bne .s_lnf		; $ee found?
	lda #0
	sta CHKSUM
	jmp .incstat		; found, next state
.s_lnf	lda #1			; ...not found, go back to seeklead
	sta tstat
	jmp .setstatvect

.s_exit	rts

;05	read header, compare filename
.s_rheader
	ldy tcnt
	sta .tbuf,y
	bne .s_r1		; Y>0, not block type
	cmp #1
	beq .s_r0		; block type=1, we happy
	bne .s_lnf		; unless not so happy, start over
.s_r1	cpy #17
	bcs .s_r0		; Y>16, past filename

	dey			; compare filename byte
	cpy FNLEN		; ...if within specified one's len
	bcs .s_r000
	eor (FNADR),y		; accumulate finding
	ora CHKSUM
	sta CHKSUM

.s_r000 iny
.s_r0	iny
	sty tcnt
	cpy #1+16+4		; block type, fn len, start/end ptr
	bne .s_exit
	lda CHKSUM
	bne .s_lnf		; FN didn't match, start over
	inc tstat_e		; it did, Found!
	ldy #3
.s_r2	lda .tbuf+1+16,y	; copy start/end to $2d-$30
	sta VARTAB,y
	dey
	bpl .s_r2
	jmp .incstat

;06	read data
.s_rdata
	ldy #0
	IFNCONST mod_tloadtest	; skip writing to memory if testing
	sta (VARTAB),y
	ENDIF
	eor CHKSUM
	sta CHKSUM
	inc VARTAB
	bne .s_d1
	inc VARTAB+1
.s_d1	lda VARTAB
	cmp VARTAB+2
	lda VARTAB+1
	sbc VARTAB+3
	bcc .s_exit
	jmp .incstat

;07	read and compare checksum
.s_checksum
	inc tstat_e		; Ready!
	eor CHKSUM
	beq .s_c0
	lda #$ff
.s_c0	sta ST			; 0 on success, $ff on load error
	lda #$c8		; stop the datassette
	sta $01
	jmp .incstat

;08	complete (idle)
.s_idle
	rts

.incstat
	inc tstat
.setstatvect
	lda tstat
	and #$7f
	tay
	lda .sttabl,y
	sta .tjmp+1
	lda .sttabh,y
	sta .tjmp+2
	rts

; --- end of state machine routines

; tload init. Do static setup. Call once.
; - Set PAL/NTSC switch.
; - Build quantization tables according to tbase and tsym.

.tload_init
	lda $ff07
	and #$40		; NTSC bit
	bne .ti1
	lda #39			; PAL parameters, number of chr rows
	ldx #$01		; sacc last reload value
	ldy #$30		; bmi
	bne .ti2
.ti1	lda #33			; NTSC parameters
	ldx #$04		; only 6 bits in the last chr row
	ldy #$f0		; beq
.ti2	sta .rset1		; see: labels in the code
	sta .rset2
	stx .sset
	sty .nsw

.ctabgen			; count table generator

; index		len	remg.	cont. from
; %00000000	8	0	%00000000
; %00000001	7	1	%11111111
; %00000010	6	2	%10000000
; %00000011	6	2	%11111111
; %00000100	5	3	%10000000
; %00000101	5	3	%10111111

; %01111111	1	7	%11111111

; %10000000	1	7	%00000000

; %11111100	6	2	%00000000
; %11111101	6	2	%01111111
; %11111110	7	1	%00000000
; %11111111	8	0	%11111111


; %00000000	8
; %00000001	1
; %00000010	1
; %00000011	2
; %00000100	2
; %00000101	1
; %00000110	1
; %00000111	3
; %00001000	3
; %00001001	1


.thr	EQU tstat_e		; threshold
.val	EQU tstat		; value
.xstor	EQU xstor		; x temp store
.ttmp	EQU ystor		; temp reg
.rem	EQU sacc		; temp remainder

	lda #0
	tax
	tay
	sta .thr
	lda #8
	sta .val
	dex
.ctl1	inx
	dey
	lda .val
	sta .ctabl,x
	sta .ctabl,y
	eor #$ff
	clc
	adc #$09
	sta .rem

	stx .xstor
	stx .ttmp
	ldx #$07
.ctl4	asl .ttmp
	ror
	dex
	bpl .ctl4
	tax
	lda .val
	sta .ctabr,x
	txa
	eor #$ff
	tax
	lda .val
	sta .ctabr,x

	ldx .xstor
	stx .ttmp
	txa
	ldx #0
	and #$01
	beq .ct1
	dex

.ct1	txa
	ldx .rem
	beq .ct2
.ctl2	lsr .ttmp
	ror
	dex
	bne .ctl2
.ct2	ldx .xstor
	sta .ctabj,x
	eor #$ff
	sta .ctabj,y

	cpx .thr
	bne .ctl1
	sec
	rol .thr
	dec .val
	cpx #$7f
	bne .ctl1

	lda #$88
	sta .ctabl
	sta .ctabl+$ff

.qtabgen
.al	EQU tstat_e		; accumulator
.ah	EQU tstat
.cl	EQU xstor		; compare value
.ch	EQU ystor

	ldx #0
	clc
	jsr .tgen2		; quant table for rising edge
	sec			; and for falling edge

.tgen2	php
	ldy #0
	sty .al
	sty .ah
	lda tbase
	lsr
.tg1	plp
	bcs .tg2
	adc tsym
	bne .tg3
.tg2	sbc tsym
.tg3	sta .cl
	sty .ch

	ldy #$c0
.tgl1	lda .cl
	cmp .al
	lda .ch
	sbc .ah
	bcs .tg4

	tya
	lsr
	tay
	lda .cl
	clc
	adc tbase
	sta .cl
	bcc .tg4
	inc .ch

.tg4	tya
	asl
	bcc .tg6
	ror			; x < min --> x := min
.tg6	cmp #$18
	bne .tg7
	lda #$40		; override len>3
.tg7	sta .quant,x

	inx
	lda .al
	clc
	adc #57
	sta .al
	bcc .tg5
	inc .ah
.tg5	cmp #$90		; low byte of 16*57 = $0390
	bne .tgl1

	rts

;state handler address tables
.sttabl
	DC.B <.s_pressplay
	DC.B <.s_seeklead
	DC.B <.s_countlead
	DC.B <.s_findzero
	DC.B <.s_r_ee
	DC.B <.s_rheader
	DC.B <.s_rdata
	DC.B <.s_checksum
	DC.B <.s_idle

.sttabh
	DC.B >.s_pressplay
	DC.B >.s_seeklead
	DC.B >.s_countlead
	DC.B >.s_findzero
	DC.B >.s_r_ee
	DC.B >.s_rheader
	DC.B >.s_rdata
	DC.B >.s_checksum
	DC.B >.s_idle

;gcr to bin conversion table
.gcrtobin
	DC.B $ff		; invalid GCR nybbles = $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
	DC.B $ff
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
	DC.B $ff
