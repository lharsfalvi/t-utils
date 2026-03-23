	PROCESSOR 6502

; Standalone bootstrap code for external linking
; Start: $0324, end: ? (somewhere $06-top)
; No trailing binary file start address
; Generally only pulled in by bootstrapmod.{encoding}.asm

	INCLUDE "tutilscfg.inc.template"	; pull global settings

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

; Exported symbols, all of them offsets

; Only internally used in build.sh

I_B1S			EQU B1S-B2S
I_B1E			EQU B1E-B2S
I_B2S			EQU B2S-B2S
I_B2E			EQU B2E-B2S
I_B3S			EQU B3S-B2S
I_B3E			EQU B3E-B2S

; Externals

O_FILENAME		EQU .o_fnam - B1S
; bootstrap filename
; filename $10 byte padded with $20

O_BOOTSTART		EQU .o_stradd - B1S
; bootstrap user data start in memory

O_BOOTEND		EQU .o_endadd - B1S
; bootstrap user data end+1 n memory

O_OPENSCREEN		EQU .o_oscr - B1S
; bootstrap with open screen
; 20 64		no
; 78 24		yes

O_BORDER_INCR		EQU .o_binc - B1S
; increment border colour with each 256 bytes loaded
; ee		yes
; 2c		no

O_BORDER_RESTORE	EQU .o_bres - B1S
; restore border colour when bootstrap loading concludes
; 8d		yes
; 2c		no

O_BORDER_RES_VAL	EQU .o_bresv - B1S
; border restore colour value
; ee		$ee
; xx		supplied

O_OPENSCREEN_RST	EQU .o_osrs - B1S
; restore open screen when bootstrap loading concludes
; 78		yes
; 81		no

O_START			EQU .o_sta - B1S
; start method of custom code when bootstrap loading concludes
; 03 87		Return to Basic
; cd 8b		Basic RUN
; yy xx		Jump to $xxyy

O_BORDER_MODIFY		EQU .o_brsta - B3S
; Border modification while bootstrap loading
; 8d		yes
; 2c		no

O_BORDER_MODIFY_MET	EQU .o_brmod - B3S
; Border colour modification method
; 49		EOR
; 69		ADC

O_BORDER_MODIFY_VAL	EQU .o_brmod+1 - B3S
; Border colour modification value
; 41
; xx		supplied value

