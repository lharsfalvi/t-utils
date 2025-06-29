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
sstat	EQU $d3			; sync status
sacc	EQU $d4			; serial accu (live)
pacc	EQU $d5			; process accu
pac2	EQU $d6			; process accu 2
gacc	EQU $d7			; GCR accu
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


; filename length in A, pointer in X/Y
tload_start
	stx FNADR
	sty FNADR+1
	cmp #$10
	bcc .ti1
	lda #$10
.ti1	sta FNLEN
	lda #0
	sta tstat
	sta tstat_e
	sta sstat
	sta bitstor
	sta ST
	jsr .setstatvect
	lda #1
	sta sacc
	sta gacc
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
	lda #$08
	sta $ff0a
	sta $ff09
	lda #$1b
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

.tls	bit tstat		; are we pre- or within a gcr field
	bmi .tlgd		; within, go gcr decoding
	jsr .dostate		; call state handler with pacc in A
	jmp .tsync

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

.tsync	lda sstat		; now do sync if it's time to do a sync
        beq .sync
        dec sstat

.irqe   inc $ff19
        pla			; and now time to finish and return
	tay
	pla
	tax
        pla
        rti

.sync	sei			; For this deal we're back to single thread
	lda #3			; we try to find sync in max 4 bit times
	sta etmp		; plus exchange

	lda #<.sample		; set up local / sampling IRQ
	sta $fffe
	lda #>.sample
	sta $ffff

	lda $ff13		; precalc $ff13 values
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
.ltbase	=*+1
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

calcdelay
	lda tbase
	sta .ltbase
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

; Call current state handler
.dostate
.tjmp	jmp .s_pressplay	; call current state handler

;00	waiting for datasette key to be pressed
.s_pressplay
	lda #$04
	bit $fd10
	bne .s_exit
	lda #$c0		; motor on
	sta $01
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

