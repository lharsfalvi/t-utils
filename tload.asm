	PROCESSOR 6502

VARTAB	EQU $2d
ST	EQU $90
FNLEN	EQU $ab
FNADR	EQU $af
CHKSUM	EQU $f5

	SUBROUTINE

tbuf	EQU $0333

tstat_e	EQU $d0			; load state (external)
tstat	EQU $d1			; load state (internal)
xstor	EQU $d2			; x register storage
ystor	EQU $d3			; y register storage
sacc	EQU $d4			; serial accu (live)
pacc	EQU $d5			; process accu
pac2	EQU $d6			; process accu 2
gacc	EQU $d7			; GCR accu
tcnt	EQU $d8			; temporary and raw bit counter
polar	EQU $d9			; edge polarity that we're finding
cacc	EQU $da			; counter accu
pstat	EQU $db			; processing status
rcsr	EQU $dc			; read cursor
tbase	EQU $e6			; timebase
tsym	EQU $e7			; timebase rising edge (a)symmetry


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

	ALIGN $0100

tload_init
	jmp .tload_init
tload_start
	jmp .tload_start
tload_stop
	jmp .tload_stop

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
	lda #$1b
	sta $ff06
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
	lda .wcsr		; 4
	inc .wcsr		; 6
	cmp #25			; 2
	bcc .badline		; 2 / 3		26 / 27

	cmp #38
	bne .nobadline
	lda #0			; buffer loop
	sta .wcsr
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

.doprocess
	dec pstat
	stx xstor
	ldx #$c8
	lda #<.tload_fastirq
	sta $fffe
	sty ystor
	stx $ff19

.tlpl	ldy rcsr
	sec
	bcs .tlp1		; pal: bcs / ntsc: bne

	rol .cbuf		; ntsc first chunk len fix
	asl .cbuf
	clc

.tlp1	lda .cbuf,y
	ldy cacc
;	bpl .tlp4
;	pha
;	ldy #$ff
;	bne .tls

.tlp4	bit polar
	bmi .tlfall

	rol
	bcs .tlpr2
.tlpr1	iny
	asl
	bcc .tlpr1
	beq .tlp3		; out of bits

.tlpr2	pha
	lda .quant+$10,y
	ora #$fc
	dec polar
	bmi .tlsh

.tlfall	rol
	bcc .tlpf2
.tlpf1	iny
	asl
	bcs .tlpf1
	bne .tlpf2
	dey
	bcc .tlp3

.tlpf2	pha
	lda .quant,y
	ora #$fc
	inc polar

.tlsh	tay
	lda pacc
.tlsh1	cpy #$ff
	rol
	bcs .tls
.tlsh2	iny
	bne .tlsh1
	sta pacc
	sty cacc
	pla
	bit polar
	bpl .tlpr1
	bmi .tlpf1

.tlp3	sty cacc
	ldy rcsr
	iny
	cpy #39
	bne .tlp2
	ldy #0
.tlp2	sty rcsr
	cpy .wcsr
	bne .tlpl
.tlpe	jmp .irqe


.tls	sty cacc
	bit tstat		; are we pre- or within a gcr field
	bmi .tlgd		; within, go gcr decoding
	jsr .dostate		; call state handler with pacc in A
.tlse	lda #%00001000		; reload pacc
.tlser	ldy cacc		;
	bne .tlsh2

.tlgd	tay			; do gcr decoding
;	lda .gcrtobin,y		; check for GCR code error
;	bmi .gcrerror
	lda gacc
	asl
	asl
	asl
	asl
	ora .gcrtobin,y
	sta gacc
	bcc .tlse

	jsr .dostate		; call state handler with gacc in A
	lda #1
	sta gacc
	bne .tlse

.irqe	ldy ystor
	lda #<.tload_irq
	sta $fffe
	ldx xstor
	lda #$ee
	sta $ff19
	inc pstat
        pla
        rti


; Call current state handler
.dostate
.tjmp	jmp .s_pressplay	; call current state handler

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
	beq .s_c1
	dec tstat
	jmp .setstatvect
.s_c1	dec tcnt
	bne .s_exit
	jmp .incstat		; countlead exits with tcnt=0

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
	pla			; throw return address away
	pla
	lda tstat
	clc
	adc #$81
	sta tstat		; also raise GCR decode strobe
	jsr .setstatvect
	lda pacc
	jmp .tlser		; manually re-enter bit read loop

;04	read lead's trailing $ee byte
.s_r_ee
	cmp #$ee		; gacc in A
	bne .s_lnf		; $ee found?
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
	sta (VARTAB),y
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
	ldx #$a9		; lda #  (2-byte nop)
	lda $ff07
	and #$40		; NTSC bit
	beq .ti1
	ldx #$f0		; beq
.ti1	;stx .ntscsw

.qtabgen
; we can and do overload a few zp's for this current task.
.al	EQU $d0			; accumulator
.ah	EQU $d1
.cl	EQU $d2			; compare value
.ch	EQU $d3

	ldx #0
	clc
	jsr .tgen2		; q table for rising edge
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

	ldy #$00
.tgl1	lda .cl
	cmp .al
	lda .ch
	sbc .ah
	bcs .tg4

	iny
	lda .cl
	clc
	adc tbase
	sta .cl
	bcc .tg4
	inc .ch

.tg4	tya
	sec
	sbc #1
	bcs .tg6
	adc #1
.tg6	eor #$ff
	sta .quant,x
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

	.ALIGN $100
.cbuf	DS 39,0			; circular data buffer


;quantization tables for rising, falling edge time
.quant	DS 32,0

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

.restor DC.B 0,0,0
.tbuf	DS 1+16+4		; block type, filename, start/end

/*
.ntsctrch			; 8 vs. 6 line correction in NTSC
	lda sacc		; 3
	pha			; 3
	and #%00000011		; 2
	ora #%00000100		; 2
	sta sacc		; 3
	cli			; 2		15
	pla
	and #%11111100
	ora #%00000010
	sta pacc
	bcs .nobadline		; number of bits !!!
*/
