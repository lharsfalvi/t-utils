	IFCONST mod_basicstub
	PROCESSOR 6502
	ORG $1001
	ENDIF

; Stub is generated relative to current TEXT address
; Release year i.e. used basic line number can be defined in REL_Y

	INCLUDE "ver.inc"

	SUBROUTINE basicstub

	ORG *-2
	DC.W *+2

.ra	SET * + 8 + 1				; precalc length hack
	IF .ra >=10				; to avoid multiple
.ra	SET .ra +1				; assembly passes
	ENDIF
	IF .ra >=100
.ra	SET .ra +1
	ENDIF
	IF .ra >=1000
.ra	SET .ra +1
	ENDIF
	IF .ra >=10000
.ra	SET .ra +1
	ENDIF

.st	SET .ra					; addr to string
.d5	EQU .st / 10000
.st	SET .st - (.d5*10000)
.d4	EQU .st / 1000
.st	SET .st - (.d4*1000)
.d3	EQU .st / 100
.st	SET .st - (.d3*100)
.d2	EQU .st / 10
.st	SET .st - (.d2*10)
.d1	EQU .st

	DC.W .ra - 2				; next basic line chain
	DC.W REL_Y				; basic line # (year)
	DC.B $9e				; basic 'sys'

	IF .ra >= 10000				; start addr string
	DC.B $30 | .d5
	ENDIF
	IF .ra >= 1000
	DC.B $30 | .d4
	ENDIF
	IF .ra >= 100
	DC.B $30 | .d3
	ENDIF
	IF .ra >= 10
	DC.B $30 | .d2
	ENDIF
	DC.B $30 | .d1

	DC.B 0					; basic line end
	DC.W 0					; basic program end

