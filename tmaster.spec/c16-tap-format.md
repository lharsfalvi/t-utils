# Commodore 264 series specific TAP container format

The TAP format is a container format to represent tape data recordings.

All words are unsigned and little endian.

TAP format assumes that the media's initial logic state is L (0).

## Head

* id string, 12 bytes "C16-TAPE-RAW"
* TAP version, 1 byte, 0x01 (v1) or 0x02 (v2)
* Platform, 1 byte 0x02 (C16)
* Video Standard, 1 byte 0x00 (PAL)
* reserved, 1 byte 0x00
* Payload size in bytes, dword

## Data

* Payload is a series of bytes and 24-bit words that represent time
  spanning between subsequent logic level flips (v2), or, subsequent
  H to L transition points (v1) of the source stream, respectively.
* if time to be stored is less or equal to 255 T, then time is
  represented by a single byte
* if time to be stored is above 255 T, then a zero byte marker is
  added, which is followed by a 24-bit word of number of T ticks * 8.

