	PROCESSOR 6502

; Standalone bootstrap code for external linking
; Start: $0200, end: $03f1
; No trailing binary file start address

	INCLUDE "tutilscfg.inc"	; global settings

; part 2 at $0200
	ORG $0200
BOOT	SET 2
	include "bootstrap.asm"

	DS $0333-*, 0		; padding zeros
	
; part 1 at $0333
BOOT	SET 1
	include "bootstrap.asm"
