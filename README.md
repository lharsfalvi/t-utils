# t-utils

A.k.a. "Tape-Utils".

## Overview
T-utils is a set of utilities to assist producing cassette tape based software releases for the [Commodore 264 series](https://en.wikipedia.org/wiki/Commodore_Plus/4).

It consists of:

* tload - a resident tape IRQ loader routine that can be linked into software products
* tsave - a standalone save routine that produces tload's custom recording format
* tmaster - a utility to create tape master recordings for production (WIP yet)

## How to build

Use [build.sh](build.sh) from the software bundle.

* `build.sh` - build everything
* `build.sh somefile.asm` - build somefile.asm
* `build.sh clean` - clean up generated files

To build the binaries, you'll need a Posix compatible environment, bash, and [dasm](https://github.com/dasm-assembler/dasm) (V2.0 or above).

## How to use

### tsave

This is a standalone utility in the form of a classic "tape turbo". When you run the utility, the code is relocated to the system variable and screen memory area, leaving Basic
memory free.

The code hooks into the Kernal Save vector chain, and listens on device #7 (as usual).

Data can be recorded either in a "bootstrapped", or a "standalone" turbo mode. A "bootstrapped" recording consists of a standard Kernal header + a polling mode custom tape loader + the payload in the custom turbo format (similarly to standard turbo schemas known on the Plus/4). The "standalone" recording consists of a single custom turbo recording with a header. (Moral of the story: you'll usually want one single "bootstrapped" recording to bootstrap your product, and further "standalone" recordings to contain parts of your multi-load product, all of them loaded by the embedded tload routine later on.)

To save files, you can use the usual notations, like

```
SAVE"FILENAME",7[,SA]
```
from Basic, and
```
S"FILENAME",7,start,end+1
```
from Tedmon.

Tsave's recording parameters are controlled by bits of the secondary address (some of these options still to be implemented).

```
; Secondary address
; b0 - don't want border striping (during bootstrap load)
; b1 - don't want an I/O init at the end of bootstrap
; b2 - want autostart (to AUTOSTART) at the end of bootstrap
; b3 - payload is at BUFSTART (rather than STAL/STAH)
; b4
; b5
; b6
; b7 - don't want a bootstrap, record a bare custom turbo file
```

(Consequently, by default (i.e. secondary address = 0 or absent), tsave creates a bootstrapped turbo recording, where the border is striped during loading, I/O init is executed after loading had finished, and control is given back to Basic.)

Due to Tedmon's `S` command syntax missing the secondary address parameter, saving custom files might in practice require to set up Kernal Save from a small bit of additional code.

### tmaster

WIP

### tload

See: How to integrate tload into the product

## How to integrate tload

### Bootstrap

Every release recordings are supposed to start with "bootstrapping".

A bootstrap is

* recorded in bootstrap mode, so that this (very first) part can be loaded by stock Basic's Load command.
* contain at least the tload routine, plus setup code to trigger the loading in of further part(s) of the product (now on open screen / in IRQ mode), plus optionally anything audiovisual, supposed to run during the first open screen loading part.

(A compromise is likely to be made in the bootstrap part between initial / polling mode loading time, vs. the level of available graphic / sound / anything at the time the product's custom code takes over. Theoretically, custom code may also track the ongoing progress of the loading of further data, and make use of it "on the fly" just as it becomes available.)

### Integrating tload as a binary.

Review tload's [configuration file template](tloadcfg.inc.template) for options, addresses, and zeropage locations - and their defaults. You can customize these options by copying the template file to ``tloadcfg.inc`` in the source directory root, and override the defined values according to your specific requirements. (Git / the build won't overwrite your customized config later on.)

Build the tload utility binary (say, `build.sh tload.asm`).

By default, tload assembles to $f800, with an additional BSS segment (scratch data) to reside at $f400. It also uses several zeropage locations from $d0-$e7, and a few more Basic and standard Kernal Load variables (see [tloadcfg.inc.template](tloadcfg.inc.template) ). Assembled code size is around 1K, BSS data is around $380 bytes.

Link the binary into your bootstrap code file as a binary blob, and/or make sure that the bootstrap puts it into place.

To effectively load a custom turbo file using tload from your code:

* call `tload_init` - the first entrypoint. This routine merely sets up data tables - so, at this point, your own code's IRQ routine may be active without problems. Setup may take a few frames of time.
* make sure not to overwrite the BSS segment's data tables until data loading concludes (i.e. until you call `tload_stop` ).
* another important note for `tload_init`: you must preserve (or, supply: backup / restore), the `tbase` and `tsym` zeropage variables (default: $e6 and $e7) the way they have been set up by the bootstrap polling loader - since, tload_init uses these measurement results to calculate timings.
* call `tload_start` with filename start address in X/Y, and filename length in A. IRQ may be enabled (in any case, the init routine will disable IRQ's for some time, and set up it's own IRQ masks and handler). **A bit of warning** regarding file name: the routine is strict in the meaning of only loading files with correctly (and in-full) specified file names. Files **are** identified by filenames, no lazy specification and wildcards are implemented.
* during loading, sync your own running code, for example, by setting up $ff0a/$ff0b to some particular rasterline, and then polling bit 1 of $ff09 for triggers (then ACKing it by writing $02 to $ff09). Tload's code doesn't touch raster interrupt registers and IRQ masks during operation.
* be careful with modifying $ff06 during loading. Especially never close the screen (bit 4) or modify the vertical smooth scroll bits (bits 0..2).
* poll `tstat_e` (default: $d0) for loader state changes. See state identifiers at Technical Data / tload.
* additionally, you may (but don't have to) poll `tstat` (default: $d1) for more detailed state changes.
* Once `tstat_e` ends up in the ready state ($03), you can conclude the loading part.
* The ST variable ($90 by default) will tell if loading was a success (=0) or failed checksum (!=0).
* call `tload_stop`. This routine restores your original IRQ vector and IRQ masks (as found at the time of calling tload_start).
* If load turns out to be unsuccessful (ST is nonzero), you may instruct the user to stop the datassette, and rewind the tape to, say, location X - and attempt to start over by setting up tload's `tload_start` entrypoint again.

A bit of warning - as you'll soon find out, currently, the loader's CPU consumption is rather huge.

### Integrating tload as a source.

You can also include the tload.asm file directly as a source file. That of course implies that your own code is already in dasm format. Review the address setups in the first part of tload.asm, so that code pieces would fall into the right place in assembly time. Keep attention that tload.asm references a list file normally set up by the build.sh script (a file that holds the current version string).

You may also find clues (for both this and the previous part) by reviewing [tloadtest.asm](tloadtest.asm).

## Technical data

### Custom tape format

T-utils uses [GCR](https://en.wikipedia.org/wiki/Group_coded_recording#Commodore) to record data to tape. Nominal bit timing is 192 single clock cycles, which (in PAL) makes a constant data rate of ~4618 raw bits, a.k.a ~924 GCR nybbles, a.k.a ~462 decoded bytes per second. (Actual rates may vary according to Datassette motor speed tolerances).

Similarly to disk recordings (and contrary to most tape data formats on Commodore), raw 0 and 1 bits are denominated by lacks or presences of magnetic flux reversals, respectively.

(Note: despite the relatively high bit rate, t-utils is expected to play nicely on tape bandwidth - due to the use of n-multiples of one uniform bit timing, and the denomination of one raw bit by one flux reversal, rather than two of them.)

Custom turbo recordings consist of the following fields:

|Name         |Data                  |Note                                                   |
|-------------|----------------------|-------------------------------------------------------|
|Lead-in      |raw $1f nybble * $0a00|This pattern is not normally found in valid GCR data   |
|Lead-in end  |raw $1e nybble * 3    |Signs the lead-in's end, header's start                |
|File type    |one byte              |0 --> bootstrap mode turbo block, 1 --> standalone file|
|Filename     |16 bytes              |N/A for bootstrap                                      |
|Start address|2 bytes               |N/A for bootstrap                                      |
|End address  |2 bytes               |N/A for bootstrap                                      |
|Data payload |End-Start bytes       |                                                       |
|Checksum     |1 byte                |Usual EOR of data payload                              |
|Lead-out     |raw $1f nybble * $0200|                                                       |

### tload

Tload uses constant rate sampling to read data, implementing a circular buffer to decouple realtime sampling from actual data processing and loader state management. Sampling happens at the horizontal line rate (57 single clock cycles).

Tload (in fact every utilities in this package) works both in PAL and NTSC (also PAL-N). Data recordings produced on PAL / NTSC / PAL-N machines slightly vary in speed, due to the slightly different base clock frequency of the machines (...but this is way within tolerances otherwise imposed by varying datassette motor speeds.) _Loading_ data on NTSC machines can be tight (see, 50 less vertical border lines per frame).

Tload currently implements the following "external" state identifiers (as exported in `tstat_e` a.k.a $d0 by default):

```
; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (success in ST)
```

Additionally, the internal states implemented by the code (as found in `tstat` a.k.a $d1) are as below:

```
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
```
Tload runs off Timer 1's IRQ's, and it frequently clears Timer 3's IRQ's as a sideeffect of the code (Timer 3 itself is not affected). The raster registers and Timer 2 are free to play with by user code. (Of course, changing the IRQ enable masks is highly discouraged.)

TBD reducing CPU consumption

### tsave

Tsave obviously embeds a complete polling mode turbo loader that it saves with every "bootstrap" mode turbo recordings. This code also performs signal speed and symmetry measurement using the turbo header signal as reference. (Speed and symmetry data is used by both the polling loader and tload later on).

The polling loader routine resides in the tape buffer ($0332-$03f2) and the Basic system variable area ($0200-$02ff) upon loading.

Unfortunately, there's currently no way to run the polling mode loader with open screen.

It might be worth noting that the "bootstrap" mode Kernal recording part also employs a custom (shortened) Kernal lead-in, header, data lead-in, data block, in order to spare a few seconds of initial loading time.

## Releases

No releases yet.

## History
## License

Files in this package are distributed under the Zlib license (see: [LICENSE](LICENSE)), (C) 2024-2025 Levente Hársfalvi
