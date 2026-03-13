	PROCESSOR 6502

; Standalone bootstrap code for external linking
; Start: $0324, end: ? (somewhere $06-top)
; No trailing binary file start address

	INCLUDE "tutilscfg.inc"	; global settings

	SUBROUTINE

; parts in the order of their memory location

; part 2 at $0324 (IBSOUT vector)
	ORG B2S
BOOT	SET 2
	include "bootstrap.asm"
	DS B1S-*, 0		; padding zeros

; part 1 at $0333 (tape buffer)
BOOT	SET 1
	include "bootstrap.asm"
	DS B3S-*, 0		; padding zeros

; part 3 at $0609 (free space in the sys var area)
BOOT	SET 3
	include "bootstrap.asm"

