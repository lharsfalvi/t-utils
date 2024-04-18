;			I/O DEVICES
PDIR	EQU $0000
PORT	EQU $0001
ACIA	EQU $FD00
XPORT	EQU $FD10
BNKSEL	EQU $FDD0
TED	EQU $FF00

ROMON	EQU $FF3E
ROMOFF	EQU $FF3F

;			BANKING JUMP TABLE
GOBVEC	EQU $FCF1	;JMP to cartridge IRQ routine
PHENIX	EQU $FCF4	;JMP to PHOENIX routine
FETCHL	EQU $FCF7	;JMP to LONG FETCH routine
LONG	EQU $FCFA	;JMP to LONG JUMP routine
LNGIRQ	EQU $FCFD	;JMP to LONG IRQ routine

;			UNOFFICIAL JUMP TABLE
KEY	EQU $FF49	;Define function key routine
PRINT	EQU $FF4C	;PRINT routine
PRIMM	EQU $FF4F	;PRIMM routine
ENTRY	EQU $FF52	;ENTRY routine

;			KERNAL JUMP TABLE
CINT	EQU $FF81	;Initialize screen editor
IOINIT	EQU $FF84	;Initialize I/O devices
RAMTAS	EQU $FF87	;Ram test
RESTOR	EQU $FF8A	;Restore vectors to initial values
VECTOR	EQU $FF8D	;Change vectors for user
SETMSG	EQU $FF90	;Control O.S. messages
SECOND	EQU $FF93	;Send SA after LISTEN
TKSA	EQU $FF96	;Send SA after TALK
MEMTOP	EQU $FF99	;Set/Read top of memory
MEMBOT	EQU $FF9C	;Set/Read bottom of memory
SCNKEY	EQU $FF9F	;Scan keyboard
SETTMO	EQU $FFA2	;Set timeout in DMA disk
ACPTR	EQU $FFA5	;Handshake serial bus or DMA disk byte in
CIOUT	EQU $FFA8	;Handshake serial bus or DMA disk byte out
UNTLK	EQU $FFAB	;Send UNTALK out serial bus or DMA disk
UNLSN	EQU $FFAE	;Send UNLISTEN out serial bus or DMA disk
LISTEN	EQU $FFB1	;Send LISTEN out serial bus or DMA disk
TALK	EQU $FFB4	;Send TALK out serial bus or DMA disk
READST	EQU $FFB7	;Return I/O STATUS byte
SETLFS	EQU $FFBA	;Set LA, FA, SA
SETNAM	EQU $FFBD	;Set length and FN address
OPEN	EQU $FFC0	;Open logical file
CLOSE	EQU $FFC3	;Close logical file
CHKIN	EQU $FFC6	;Open channel in
CHKOUT	EQU $FFC9	;open channel out
CLRCHN	EQU $FFCC	;Close I/O channels
CHRIN	EQU $FFCF	;Input from channel
CHROUT	EQU $FFD2	;output to channel
LOAD	EQU $FFD5	;Load from file
SAVE	EQU $FFD8	;Save to file
SETTIM	EQU $FFDB	;Set internal clock
RDTIM	EQU $FFDE	;Read internal clock
STOP	EQU $FFE1	;Scan STOP key
GETIN	EQU $FFE4	;Get character from queue
CLALL	EQU $FFE7	;Close all files
UDTIM	EQU $FFEA	;Increment clock
SCREEN	EQU $FFED	;Screen org.
PLOT	EQU $FFF0	;Read/Set X,Y coord of cursor
IOBASE	EQU $FFF3	;Return location of start of I/O

