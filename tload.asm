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
sstat	EQU $d3			; sync status
sacc	EQU $d4			; serial accu (live)
pacc	EQU $d5			; process accu
pac2	EQU $d6			; process accu 2
dacc	EQU $d7			; decode accu
tcnt	EQU $d8			; temporary and raw bit counter
bitstor	EQU $d9			; various 1-bit storage
etmp	EQU $e0			; temp var in sync
delay1	EQU $e4			; delay line jump ptr 1
delay2	EQU $e5			; delay line jump ptr 2
tbase	EQU $e6			; timebase
tsym	EQU $e7			; timebase leading edge (a)symmetry

; tstat
;00	waiting for datasette play button to be pressed
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
	jsr calcdelay
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
	sta sstat
	sta bitstor
	sta ST
	lda #.tl2-.sjmp+2
	sta .sjmp+1
	lda #$08
	sta $ff0a
	sta $ff09
	lda #1
	sta sacc

	lda #$3b
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

tload_irq
				; 0-6 + 0-43
				; 7 IRQ ack + jmp
	pha			; 3
	lda #$c8		; 2
	cmp $01			; 3 --> t=+15, should happen at T/2
	sta $ff09		; 4 ACK IRQ
	rol sacc		; 5
.sjmp	bcs .tl2		; 2
	pla			; 4
	rti			; 6	- worst-case 42

.tl2	lda sacc
        sta pacc
        lda #1
	sta sacc
        cli			; At this point we permit sub IRQ's
				; to happen, to let subsequent
				; data bits to be collected while
				; processing the previously collected
				; raw bit octet.
        txa
        pha
        tya
	pha
        dec $ff19

	lda pacc		; level --> level change conversion
	lsr bitstor
	ror
	rol bitstor
	eor pacc
	sta pacc

.tls	bit bitstor		; are we pre- or within a gcr field
	bpl .tl3		; pre, skip gcr decoup and decode

	lda pac2		; gcr raw bits decoupling
	sec

.tlgl	rol pacc
	beq .tlem		; pacc is out of valid bits, exit
	rol
	bcc .tlgl		; loop until 5 valid bits in pac2

; do gcr decoding et. al. (and return)

	lda #%00001000
	clc
	bcc .tlgl

.tlem	sta pac2

*/

.tl3	ldy tstat		; prepare to call state handler
	lda .sttabl,y
	sta .tjmp+1
	lda .sttabh,y
	sta .tjmp+2

.tjmp	jsr .s_pressplay	; call current state handler
	lda tstat		; handle redo state machine case
	bpl .tsyn
	and #$7f
	sta tstat
	bpl .tls		; redo complete state machine stage

.tsyn	lda sstat		; now do sync if it's time to do a sync
        beq .sync
        dec sstat

.irqe   inc $ff19
        pla			; time to finish and return
	tay
	pla
	tax
        pla
        rti

.sync	sei			; For this deal we're back to single thread
	lda #3			; we try to find sync in max 4 bit times
	sta etmp		; plus exchange

	lda #<.sample
	sta $fffe
	lda #>.sample
	sta $ffff

	lda $ff13
	and #$fd
	sta .soff1
	sta .soff2
	ora #$02
	sta .son

.soff1	=*+1
.sloop3 ldy #0
	sty $ff13
	lda #$c8
	cmp $01
	sbc #$c7
	tay
	lda .branch,y
	sta .foo
	lda delay1,y
	sta .tim2

	lda #$c8
	cli
.son	=*+1
	ldy #0

.sloop	cmp $01			; 3
.foo	bcs .sloop		; 3

.edge	lda $ff1d		; 4
	sei			; 2
	sty $ff13		; 4

	sec			; 2
	sbc #$01		; 2
	cmp #$c4		; 2
	ror			; 2
	ldy $ff1c		; 4
	cpy #$ff		; 2
	ror			; 2
	and #%11000001		; 2		- 18

.tim2	EQU *+1
	bne *+3			; 3
	beq .sloop3		; unsuitable place, quit
	DS 22,$ea		; 22 NOP's, 2 cycles each
ltbase	=*+1
	lda #0			; 2
	sta $ff00		; 4
	lda #0			; 2
	sta $ff01		; 4
.soff2	=*+1
	lda #0
	sta $ff13
	lda #$c8
	sta $ff09
	cmp $01
	rol sacc
	lda #1
	sta sstat
	bne .sampe2

.sample sta $ff09
	cmp $01
	rol sacc
	bmi .sampe
	dec etmp
	bmi .sampe
	rti

.sampe	pla
	pla
	pla
.sampe2	lda #<tload_irq
	sta $fffe
	lda #>tload_irq
	sta $ffff
	jmp .irqe

.branch DC.B $90, $B0		; bcc, bcs

	SUBROUTINE
calcdelay
	lda tbase
	sec
	sbc tsym
	lsr			; (T-A)/2
	pha
	jsr .calc
	sta delay2
	pla
	clc
	adc tsym		; +A
	jsr .calc
	sta delay1
	rts

.calc	cmp #74
	bcs .c1
	lda #74
.c1	cmp #118
	bcc .c2
	lda #118
.c2	clc
	sbc #(74+48)
	eor #$ff
	lsr
	rts


/*
.tl3	cli			; from this on we're async
	lda gcrpol		; 2-phase (2 nybbles per byte)
	eor #$80
	sta gcrpol

	ldy tstat
	cpy #$04		; no GCR decoding, yet unconditional
	bcc .tjmp		; processing below S=$04
	
	ldy pacc		; GCR decode and merge the nybble
	lda gacc
	asl
	asl
	asl
	asl
	ora .gcrtobin-9,y	; and merge it with the previous one
	sta gacc
	bit gcrpol
	bmi .tl4		; skip processing until complete

*/


;00	waiting for datasette key to be pressed
.s_pressplay
	lda #$04
	bit $fd10
	bne .s_p1
	lda #$c0		; motor on
	sta $01
	inc tstat
	inc tstat_e
.s_p1	rts

;01	searching for a lead
.s_seeklead
	lda pacc
	cmp #$ff
	bne .s_sl1
	lda #$a0
	sta tcnt
	inc tstat
.s_sl1	rts

;02	found lead, counting
.s_countlead
	lda pacc
	cmp #$ff
	beq .s_c1
	dec tstat
	rts
.s_c1	dec tcnt
	bne .s_c2
	inc tstat
.s_c2	rts

;03	found lead, searching for first 0 bit
.s_findzero
	lda pacc
	cmp #$ff
	beq .s_f1




	lda tstat
	clc
	adc #$81
	sta tstat
.s_f1	rts





inc tstat

	


/*
	lda #$80
.s_s2	asl
	rol pacc
	bcs .s_s2
	
	
*/	
	
.s_s2	dey
	asl
	bcs .s_s2
	bcc .bele-a-gcr-decode-loopba
	
	
	
	
	
/*	
	ldy tcnt
	bne .s_s1
	lda pacc
	cmp #$1f
	beq .s_s0
	
	ldy #2
	sty tcnt		; 2 dummy
	lsr
	bcc .s_s0		; no shift
	lsr
	bcs .s_s2
	sec
	rol sacc		; 1 shift left
	bne .s_s0
.s_s2	dec tcnt		; from this on, 1 dummy
	lsr
	bcc .s_s3		; 3 shift right
	lsr
	bcc .s_s4		; 2 shift right
	bcs .s_s5		; 1 shift right
.s_s3	lsr sacc
.s_s4	lsr sacc
.s_s5	lsr sacc
.s_s0	rts

.s_s1	lda pacc
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


*/


;04	lead complete, phase corrected, read header, compare filename
.s_rheader
	lda gacc
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
	lda gacc
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
	lda gacc
	eor CHKSUM
	beq .s_c0
	lda #$ff
.s_c0	sta ST			; 0 on success, $ff on load error
	jmp .incstat

;07	complete (idle)
.s_idle
	rts

/*
.incstat
	inc tstat
.setstatvect
	ldy tstat
	lda .sttabl,y
	sta .tjmp+1
	lda .sttabh,y
	sta .tjmp+2
	rts
*/


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

