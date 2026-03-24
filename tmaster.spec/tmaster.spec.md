# T-master a.k.a. Tape Master

TMaster a.k.a. Tape Master - a single-file Python CLI tool to create
master recording files of custom multi-load software products for
the Commodore 264 series.

## Overview

Tmaster accepts

* global flags
* one or more binary files, with additional arguments on how to record
  them, each
* an output file, with additional arguments on output processing

It encodes the input files according to global and per-file arguments,
and creates one output file with all specified / encoded content merged,
according to output file arguments.

## Additional requirements

* external data (a.k.a. conversion tables, bootstrap code blocks,
  offset tables - data lifted in from tmaster.spec/ and build/) are supposed to be
  interpreted at code generation time, and embedded into tmaster.
  An arbitrary format of internal data structure can be chosen, but
  keep definition concise and tidy. At runtime, no external files
  should be pulled in except formal dependencies, or, those specified
  on the CLI.

## Command line switches and arguments

Byte and word arguments are unsigned, little endian, and can be
specified either in decimal or hexadecimal (0x..) .

Command line is

tmaster [global arguments] first_input_file [arguments] [...] output_file.{raw|tap|wav} [arguments]

Switches not applicable to particular context should generate an error.


### Global switches

|Argument|Definition|Default|mandatory|
|--------|----------|-------|---------|
|-h | Output help text | n/a | no |
|-{gcr\|ple} | Use specified encoding for custom blocks | PLE | no |
|-N x | Use timing of x * T for custom formats | PLE: 14, GCR: 24 | no |
|-C{c\|u\|s}| PETSCII conversion method - convenient, unshifted, shifted| convenient | no|

### Per-input file arguments

Unless started with -h, at least one source file needs to be specified.

|Argument|Definition|Default|mandatory|
|--------|----------|-------|---------|
|Source filename|Source filename (optionally with path)| n/a | yes |
|Recorded filename|Filename to be used for recording| n/a | yes |
|-{b\|s} | Record as bootstrap\|standalone custom| bootstrap | no |

Bootstrap specific arguments (all optional):

|Argument|Definition|Default|Note|
|--------|----------|-------|----|
|-S{y\|n} | Short bootstrap | no | basically omits Round 1 blocks|
|-O{y\|n} | Bootstrap with open screen | no | only applicable for PLE|
|-OR{y\|n} | Restore open screen state | yes ||
|-B{y\|n} | Border striping | yes | no also implies -BIn and -BRn|
|-BI{y\|n} | Increment border colour | yes ||
|-BU{a\|e} | Border colour update method adc/eor | eor ||
|-BUV x | Border colour update value | 0x41 | parameter is a byte|
|-BR{y\|n} | Restore border colour | yes ||
|-BRV x | Restore colour value | 0xee | parameter is a byte|
|-herc | shortcut for -BUe -BUV 0x41 | n/a ||
|-her | shortcut for -BUa -BUV 0x10 | n/a ||
|-axon | shortcut for -BUa -BUV 0x38 | n/a ||
|-nova | shortcut for -BUe -BUV 0x7f | n/a ||
|-E x | execute user code at x | 0x8703 | parameter is a word|
|-run | shortcut for -E 0x8bcd | n/a ||

Warn the user about -gcr and -Oy being in effect at the same time.

### Output file arguments

|Output file type |Argument|Definition|Default|mandatory|
|-----------------|--------|----------|-------|---------|
|wav|-s x| Sampling frequency | -s 44100 | no |
|wav|-c x| number of channels, 1 or 2| -c 1 | no |
|wav|-d x| bit depth per channel, 8 or 16| -d 8 | no |
|wav|-i | invert signal output | - | no |

## Operation

* Eval global switches
* For each input file, eval specified switches, process and encode
  input data accordingly, and concat each resulting bit streams,
  with a gap of 244000 T inbetween.
* Create an output file according to specified output file name and
  implicit type declaration.

### File name conversion

The specified Recorded filename has to be adjusted before using.

* Truncate filename to 16 characters
* Pad filename with spaces up to 16 characters (if needed)
* If specified mode is 'convenient',
  * Convert characters to upcase
  * Look up and convert characters to PETSCII codes using
    tmaster.spec/unicode_petscii_lut_unshifted.txt
* If specified mode is 'unshifted',
  * Look up and convert characters to PETSCII codes using
    tmaster.spec/unicode_petscii_lut_unshifted.txt
* If specified mode is 'shifted',
  * Look up and convert characters to PETSCII codes using
    tmaster.spec/unicode_petscii_lut_shifted.txt

Warn the user if any source characters happen to fail to have the
equivalent PETSCII during conversion.


### Bootstrap generation

* Take bootstrap code and offset values from data that was imported
  from build/bootstrapmod.{ple|gcr}.ext
* Patch Bootstrap block data according to table below:

|Feature| Bootstrap block to patch | Offset within block | Len | Comment|
|-------|--------------------------|---------------------|-----|--------|
|Rec Filename (PETSCII)| BSBLOCK1 | O_FILENAME | 16 byte ||
|User data start | BSBLOCK1 | O_BOOTSTART | 1 word | get it from the first word of the input file|
|User data end | BSBLOCK1 | O_BOOTEND | 1 word | Data start + input filesize -2 |
|Open screen | BSBLOCK1 | O_OPENSCREEN | 1 word | -Oy: 0x2478, -On: 0x6420|
|Restore screen state | BSBLOCK1 | O_OPENSCREEN_RST | 1 byte | -ORy: 0x78, -ORn: 0x81|
|Border striping | BSBLOCK3 | O_BORDER_MODIFY | 1 byte | -By: 0x8d, -Bn: 0x2c|
|Border increment | BSBLOCK1 | O_BORDER_INCR | 1 byte | -BIy: 0xee, -BIn: 0x2c|
|Border update | BSBLOCK3 | O_BORDER_MODIFY_MET | 1 byte | -BUa: 0x69, -BUe: 0x49 |
|Border update value | BSBLOCK3 | O_BORDER_MODIFY_VAL | 1 byte | -BUV x: x |
|Restore border colour | BSBLOCK1 | O_BORDER_RESTORE | 1 byte | -BRy: 0x8d, -BRn: 0x2c |
|Restore colour value | BSBLOCK1 | O_BORDER_RES_VAL | 1 byte | -BRV x: x |
|User code exec address | BSBLOCK1 | O_START | 1 word | -E x: x|

* Record BSBLOCK1-3 as Kernal tape recording blocks with parameters below:

Short bootstrap flag is not in effect:

  1.)
    * Round 1
    * 0x2100 lead-in pulses
    * Block type = 3
    * Block data is BSBLOCK1
  2.)
    * Round 2
    * 0x0100 lead-in pulses
    * Block type = 3
    * Block data is BSBLOCK1
    * Gap of 61440 T
  3.)
    * Round 1
    * 0x0200 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK2
  4.)
    * Round 2
    * 0x0100 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK2
    * Gap of 61440 T
  5.)
    * Round 1
    * 0x0200 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK3
  6.)
    * Round 2
    * 0x0100 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK3
    * Gap of 61440 T

Short bootstrap flag in effect:

  1.)
    * Round 2
    * 0x2100 lead-in pulses
    * Block type = 3
    * Block data is BSBLOCK1
    * Gap of 61440 T
  2.)
    * Round 2
    * 0x0200 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK2
    * Gap of 61440 T
  3.)
    * Round 2
    * 0x0200 lead-in pulses
    * Block type = 0
    * Block data is BSBLOCK3
    * Gap of 61440 T

For both, continue with:

* Record the specified payload file (less leading start address word)
  as the specified GCR or PLE custom recording block as below:

  * Block type 0: bootstrap
  * Payload: supplied file (less leading word)

File format descriptions can be found in tmaster.spec/recording-formats.md .

### Record non-bootstrap data

Record specified input files as GCR / PLE custom standalone blocks
  
* Block type 1: standalone
* Converted / adjusted PETSCII filename
* Payload start address (use leading word of input file)
* Payload end address (= start address + filesize -2)
* Payload (less leading word)

### Output file generation

If specified output file is .raw, output is a simple binary representation
of the generated stream, one logical level one bit, MSB to LSB.

If specified output file is .tap, translate stream to time periods between
logical level changes, or, H to L transitions (tap v2 and v1,
respectively). See: tmaster.spec/c16-tap-format.md

* for GCR in effect, use tap format v2.
* for PLE in effect, use tap format v1.

If specified output file is .wav,
* parse supplied (optional) arguments
* create a riff/wav output file according to common wav header spec and arguments
* as per convention, imply unsigned for -d 8 and signed for -d 16
* convert source bitstream to specified wave as below
  * assume source T = 1/(17734470/20/8) s
  * interpret gaps > 2000T as midpoint level. Below that length,
  * assume logic L = low level
  * assume logic H = high level
  * invert assignment if -i is in effect
  * resample source to target sampling rate, no anti-aliasing.
  * for stereo (-c 2) output, the two channels should be identical

