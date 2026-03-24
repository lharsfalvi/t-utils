# Tape recording formats

## Legend

* T: common timebase
* L, H: Low and High logic state (respectively)
* Tx: an n-multiple of T
* Pulse: a period of "L" for "Tx", followed by "H" for "Tx"

Words are 16-bit long, unsigned, little endian.

## Commodore 264 series Kernal tape recording

### Timings:

* Ts = 25 T
* Tm = 52 T
* Tl = 105 T

### Symbols

* Lead: a pulse of Ts
* End: a pulse of Tm
* Start: a pulse of Tl, followed by a pulse of Tm
* '0' bit: a pulse of Ts, followed by a pulse of Tm
* '1' bit: a pulse of Tm, followed by a pulse of Ts
* Gap: no logic state change for specified time

### Byte

* 1 Start
* 8 data bits, LSB first
* 1 parity bit calculated from data bits (odd parity)

### Block

Parameters in:

* Number of recording round (Round 1, Round 2)
* Number of lead-in pulses N
  Default:
  * Round 1: 0x4100
  * Round 2: 0x0100
* Block type
* Block data

Format (sequence):

* Lead-in: N Lead pulses
* 8 bytes, values counting down:
  * Round 1: 0x89 down to 0x81
  * Round 2: 0x09 down to 0x01
* if Block type is nonzero, then Block type (1 byte)
* Block payload data
* 1 byte checksum, an xor of Block type and payload bytes
* 1 End pulse
* Lead-out: 0x00f3 Lead pulses

## Custom PLE recording

### Timings:

* Ts = 14 T (Default)
* Tl = 2 * Ts

### Symbols

* '0' bit: a pulse of Tl
* '1' bit: a pulse of Ts

### Byte

* 8 data bits, MSB first

### Block

Parameters in:

* Block type (0: bootstrap, 1: standalone)

Format:

* Lead-in: 800 bytes 0xff
* 1 byte 0xfe
* 1 byte 0xee
* Block type
* If standalone:
  * Filename (16 bytes, padded with 0x20)
  * payload start address ( 1 word)
  * payload end address (1 word)
* Block payload data
* 1 byte checksum, an xor of payload bytes
* Lead-out: 160 bytes 0xff

## Custom GCR recording

### Timings:

* Tb = 24 T (Default)

### Symbols

* '0' bit: a gap of Tb
* '1' bit: a logic state change flip, followed by a gap of Tb

### GCR nybble

* 5 bits, MSB first

### Byte

* 4 bit nybbles translated to 5 bit GCR nybbles, upper nybble first,
  according to conversion table below

### Conversion table

|4-bit nybble|5-bit GCR nybble|
|------------|----------------|
|0x0 |0b01010	|
|0x1 |0b01011	|
|0x2 |0b10010	|
|0x3 |0b10011	|
|0x4 |0b01110	|
|0x5 |0b01111	|
|0x6 |0b10110	|
|0x7 |0b10111	|
|0x8 |0b01001	|
|0x9 |0b11001	|
|0xa |0b11010	|
|0xb |0b11011	|
|0xc |0b01101	|
|0xd |0b11101	|
|0xe |0b11110	|
|0xf |0b10101	|


### Block

Parameters in:

* Block type (0: bootstrap, 1: standalone)

Format:

* Lead-in: 2560 GCR nybbles of '11111'
* 1 GCR nybble '11110'
* 1 byte 0xee
* Block type
* If standalone:
  * Filename (16 bytes, padded with 0x20)
  * payload start address ( 1 word)
  * payload end address (1 word)
* Block payload data
* 1 byte checksum, an xor of payload bytes
* Lead-out: 512 GCR nybbles of '11111'

