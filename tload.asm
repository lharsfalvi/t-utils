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
bitstor	EQU $d9			; various 1-bit storage
delay1	EQU $e4			; delay line jump ptr 1
delay2	EQU $e5			; delay line jump ptr 2
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

; filename length in A, pointer in X/Y
tload_start
	stx FNADR
	sty FNADR+1
	cmp #$10
	bcc .ts1
	lda #$10
.ts1	sta FNLEN
	lda .quantr+15
	bne .ts2
	jsr .qtabgen
.ts2	lda #0
	sta tstat
	sta tstat_e
	sta ST
	jsr .setstatvect
	lda #1
	sta sacc
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
	lda #$08
	sta $ff0a
	sta $ff09
	lda #$0b
	sta $ff06
	jsr .settimers
	cli
	rts

tload_stop
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
	lda #$cf
.st1	cmp $ff1d
	bne .st1
	lda #$d1
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
	rts



.tload_fastirq
				; 0-6 IRQ ack delay
				; 7 IRQ state save + jmp
	stx $ff09		; 4
	cpx $01			; 3
	rol sacc		; 5
	rti			; 6		25

.tload_irq
				; 0-6 IRQ ack delay
				; 7 IRQ state save + jmp
	pha			; 3
	lda #$c8		; 2
	cmp $01			; 3
	sta $ff09		; 4 ACK IRQ
	rol sacc		; 5
.sjmp	bcs .tl2		; 2 / 3
	pla			; 4
	rti			; 6		36

.tl2	lda sacc		; 3
	sta pacc		; 3
	lda #1			; 2
	sta sacc		; 3		11	38

	lsr bitstor		; 5
	lda pacc		; 3
	sta bitstor		; 3
	ror			; 2
	eor pacc		; 3
	sta pacc		; 3		19	57

	stx xstor		; 3
	sty ystor		; 3
	ldx #$c8		; 2
	lda #<.tload_fastirq	; 2
	bit $fffe		; 4		14	71

	bit $ff05		; 4
;	bmi .nobadline		; 2 / 3		6 / 7	77 / 78
	bmi .irqe

	cpx $01			; 3
	rol sacc		; 5
	nop
	nop
	nop
	nop
	nop
	nop
	nop			; 2		22

	cpx $01			; 3
	rol sacc		; 5
	stx $ff09		; 4

	jmp .irqe






.tls	bit tstat		; are we pre- or within a gcr field
	bmi .tlgd		; within, go gcr decoding
	jsr .dostate		; call state handler with pacc in A
	jmp .irqe

.tlgd	lda pac2		; gcr raw bits decoupling
	sec

.tlgl	rol pacc
	beq .tlem		; pacc is out of valid bits, exit
	rol
	bcc .tlgl		; loop until 5 valid bits in pac2

	tay			; do gcr decoding
;	lda .gcrtobin,y		; check for GCR code error
;	bmi .gcrerror
	lda gacc
	asl
	asl
	asl
	asl
	ora .gcrtobin,y
	sta gacc
	bcc .tnext

	jsr .dostate		; call state handler with gacc in A
	lda #1
	sta gacc

.tnext	lda #%00001000
	clc
	bcc .tlgl

.tlem	sta pac2		; store collected but not processed bits

.irqe	lda #0
	sta $ff04
	sta $ff05
	ldy ystor
	lda #<.tload_irq
	sta $fffe
	ldx xstor
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
	lda #$01
	sta bitstor		; zero polarity
	inc tstat_e
	jmp .incstat

;01	searching for a lead
.s_seeklead
	cmp #$ff		; pacc in A
	bne .s_exit
	lda #$a0
	sta tcnt
	jmp .incstat

;02	found lead, counting
.s_countlead
	cmp #$ff
	beq .s_c1
	dec tstat
	jmp .setstatvect
.s_c1	dec tcnt
	bne .s_exit
	jmp .incstat		; countlead exits with tcnt=0

;03	found lead, searching for first 0 bit
.s_findzero
	cmp #$ff
	beq .s_exit

	sec
	rol
	bcc .s_f3
.s_f2	asl
	bcs .s_f2
.s_f3	sta pacc
	pla			; throw return address away
	pla
	lda tstat
	clc
	adc #$81
	sta tstat		; also raise GCR decode strobe
	jsr .setstatvect
	jmp .tnext		; manually redo state machine

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
	lda #$c8		; and stop the datassette
	sta $01			; in any case
	lda gacc
	eor CHKSUM
	beq .s_c0
	lda #$ff
.s_c0	sta ST			; 0 on success, $ff on load error
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
	bcc .tg3
	iny
	bcs .tg3
.tg2	sbc tsym
	bcs .tg3
	dey
.tg3	sta .cl
	sty .ch

	ldy #$80
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
.tg6	sta .quantr,x
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


;quantization tables; rising, falling edge time
.quantr	DS 16,0
.quantf	DS 16,0

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
	DC.V >.s_r_ee
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

