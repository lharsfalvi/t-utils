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
tlpol	EQU $d2			; polarity
syncnt	EQU $d3			; sync counter
tla1	EQU $d4			; accu 1 (live)
tla2	EQU $d5			; accu 2 (live's buffer)
tla3	EQU $d6			; accu 3 (GCR decoded)
tcnt	EQU $d7			; temporary counter
gcrpol	EQU $d8			; gcr nybble polarity
del1	EQU $d9			; sync delay, rising edge
del2	EQU $da			; sync delay, falling edge

xstor	EQU $e4			; x store
ystor	EQU $e5			; y store
tbase	EQU $e6			; timebase
tsym	EQU $e7			; timebase leading edge (a)symmetry

; tstat
;00	waiting for datasette key to be pressed
;01	searching for a lead
;02	found lead, counting
;03	found lead, searching for first 0 bit
;04	lead complete, phase corrected, read header, compare filename
;05	read data
;06	read and compare checksum
;07	complete (idle)

; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (success in ST)

; name len in		$ab		FNLEN
; name ptr in		$af/$b0		FNADR


; filename length in A, pointer in X/Y
tload_start
	stx FNADR
	sty FNADR+1
	cmp #$10
	bcc .ti1
	lda #$10
.ti1	sta FNLEN
	sei
	lda $ff0a
	ldx $fffe
	ldy $ffff
	sta .restor
	stx .restor+1
	sty .restor+2
	lda #<tload_irq
	ldx #>tload_irq
	sta $fffe
	stx $ffff
	lda tbase
	sta $ff00
	lda #0
	sta $ff01
	sta tstat
	sta tstat_e
	sta tlpol
	sta syncnt
	sta ST
	ldx #tla1
	stx .acadr
	inx
	stx .acadrb
	lda #.tl2-.sjmp+2
	sta .sjmp+1
	lda #$08
	sta $ff0a
	sta $ff09
	sta tla1
	jsr .setstatvect
	
	lda #$0b
	sta $ff06
	
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

; For the sampling to happen with the least maximum error around T/2,
; IRQ has to hit at t = T/2 - known delay - max(random delay) / 2
; where known delay is IRQ code runtime until sampling, and
; random delay is that of badlines, IRQ acceptance, and single/double
; clock (where applicable).
; That is, nominally
; t(IRQ) = 192/2 - 13/2 - 13/2/2 - 7/2 - 43/2 =~ 61
; that is, the "magic offset" is -35
; and predictable random offset is within -28..+28.
	
tload_irq
				; 0-6 + 0-43
				; 7 IRQ ack + jmp
	pha			; 3
	lda $01			; 3 --> t=+13, should happen at T/2
	cmp #$c8		; 2 CST RD in C
	lda #$08		; 2
	sta $ff09		; 4 ACK IRQ
.acadr	EQU *+1
	rol tla1		; 5
.sjmp	bcs .tl2		; 2
	pla			; 4
	rti			; 6

				; 38
.acadrb EQU *+1	
.tl2	lda #tla2		; 2
	sta .acadr		; 4
	stx xstor		; 3
	sty ystor		; 3
				; 41 



	dec syncnt
	bpl .tl3		; skip sync

	ldy #0
;	lda #delay
	sta $ff04

.tl14	lda #$08
	bit $ff09
;	bne nullabit

	lda $01
	eor tlpol
	and #$10
	beq .tl14		; no flip
	sty $ff05		; start T3
	lda #$40
	sta $ff09
	
	sec
	rol tla1
	lda #$10
	eor tlpol
	sta tlpol
	lda tbase
	sta $ff00		; set T1

.tl15	bit $ff09
	bvc .tl15
	sty $ff01		; start T1
	lda #$08
	sta $ff09

	lda #3
	sta syncnt

.tl3	cli			; from this on we're async
	lda gcrpol		; 2-phase (2 nybbles per byte)
	eor #$80
	sta gcrpol
	
	ldy tstat
	cpy #$04		; no GCR decoding, yet unconditional
	bcc .tjmp		; processing below S=$04
	
	ldy tla2		; GCR decode and merge the nybble
	lda tla3
	asl
	asl
	asl
	asl
	ora .gcrtobin-9,y	; and merge it with the previous one
	sta tla3
	bit gcrpol
	bmi .tl4		; skip processing until complete
	
.tjmp	jsr .s_pressplay

	bit gcrpol		; no attempt to sync on low nybbles
	bpl .tl5

.tl4	bit tla1		; no further attempts to sync if
	bmi .tl5		; there's only one bit left to load



	
.tl5	ldx xstor
	ldy ystor
	pla
	rti

;00	waiting for datasette key to be pressed
.s_pressplay
	lda #$04
	bit $fd10
	bne .s_p1
	inc tstat_e
	lda #$c0
	sta $01
	jmp .incstat
.s_p1	rts

;01	searching for a lead
.s_seeklead
	lda tla2
	cmp #$1f
	bne .s_sl1
	lda #0
	sta tcnt
	jmp .incstat
.s_sl1	rts
	
;02	found lead, counting
.s_countlead
	lda tla2
	cmp #$1f
	beq .s_c1
	dec tstat
	jmp .setstatvect
.s_c1	inc tcnt
	bne .s_c2
.s_c3	jmp .incstat
.s_c2	rts

;03	found lead, searching for first 0 bit
.s_findzero
	ldy tcnt
	bne .s_s1
	lda tla2
	cmp #$1f
	beq .s_s0
	
	ldy #2
	sty tcnt		; 2 dummy
	lsr
	bcc .s_s0		; no shift
	lsr
	bcs .s_s2
	sec
	rol tla1		; 1 shift left
	bne .s_s0
.s_s2	dec tcnt		; from this on, 1 dummy
	lsr
	bcc .s_s3		; 3 shift right
	lsr
	bcc .s_s4		; 2 shift right
	bcs .s_s5		; 1 shift right
.s_s3	lsr tla1
.s_s4	lsr tla1
.s_s5	lsr tla1
.s_s0	rts

.s_s1	lda tla2
	and #$1f
	cmp #$1f		; at this point the dummy has to have
	bne .s_s6		; some zero bits
.s_s7	lda #1			; if not, start over
	sta tstat
	jmp .setstatvect
.s_s6	dec tcnt
	bne .s_s0
	lda #0
	sta gcrpol
	sta CHKSUM
	beq .s_c3		; no dummies left, cont
	
; 11110 11110 11110	0	2d	v
; 1e	1e    1e
; 11101 11101 1110x	1l	2d	v
;
; 11011 11011 110xx	3r	1d	v
;
; 10111 10111 10xxx	2r	1d	v
;
; 01111 01111 0xxxx	1r	1d	v

;04	lead complete, phase corrected, read header, compare filename
.s_rheader
	lda tla3
	ldy tcnt
	sta .tbuf,y
	bne .s_r1		; Y>0, not block type
	cmp #1
	beq .s_r0		; block type=1, we happy
	bne .s_s7		; unless not so happy, start over
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
	bne .s_r00
	lda CHKSUM
	bne .s_s7		; FN didn't match, start over
	inc tstat_e		; it did, see ya
	ldy #3
.s_r2	lda .tbuf+1+16,y	; copy start/end to $2d-$30
	sta VARTAB,y
	dey
	bpl .s_r2
	jmp .incstat
.s_r00	rts
	
;05	read data
.s_rdata
	ldy #0
	lda tla3
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
	bcc .s_r00
	jmp .incstat

;06	read and compare checksum
.s_checksum
	inc tstat_e		; we step the state
	lda #$c8		; and stop the datassette
	sta $01			; in any case
	lda tla3
	eor CHKSUM
	beq .s_c0
	lda #$ff
.s_c0	sta ST			; 0 on success, $ff on load error
	jmp .incstat

;07	complete (idle)
.s_idle
	rts

.incstat
	inc tstat
.setstatvect
	ldy tstat
	lda .sttabl,y
	sta .tjmp+1
	lda .sttabh,y
	sta .tjmp+2
	rts

.sttabl
	DC.B <.s_pressplay
	DC.B <.s_seeklead
	DC.B <.s_countlead
	DC.B <.s_findzero	
	DC.B <.s_rheader
	DC.B <.s_rdata
	DC.B <.s_checksum
	DC.B <.s_idle
	
.sttabh
	DC.B >.s_pressplay
	DC.B >.s_seeklead
	DC.B >.s_countlead
	DC.B >.s_findzero	
	DC.B >.s_rheader
	DC.B >.s_rdata
	DC.B >.s_checksum
	DC.B >.s_idle

.gcrtobin
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
;	DC.B $ff		; and neither is $1f

.restor DC.B 0,0,0
.tbuf	DS 1+16+4		; block type, filename, start/end

