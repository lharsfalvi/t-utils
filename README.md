# t-utils

A.k.a. "Tape-Utils".

## Warning

As of 2026.05.31, still everything is subject to change.

## Overview
T-utils is a set of utilities to assist producing cassette tape based software releases for the [Commodore 264 series](https://en.wikipedia.org/wiki/Commodore_Plus/4).

It consists of:

* tload - a resident tape IRQ loader routine that can be linked into software products
* tsave - a standalone save routine that produces tload's custom recording format
* tmaster - a crossplatform utility to create tape master recordings for production

## How to build

Use [build.sh](build.sh) from the software bundle.

* `build.sh` - build everything
* `build.sh some-source-file` - build specific file(s)
* `build.sh clean` - clean up source directory
* `build.sh dist` - create source release bundle
* `build.sh bdist` - create binary release bundle

To build the binaries, you'll need a Posix compatible environment, bash, and [dasm](https://github.com/dasm-assembler/dasm) (V2.0 or above).

Alternatively, you can use the supplied [Dockerfile](Dockerfile) to spin up a [Debian](https://www.debian.org) based build container. First run `docker build -t tbuild .` in the source directory, to build the container image. `docker run -e USER=$(id -u) -e GROUP=$(id -g) -v $(pwd):/build -it --rm tbuild [args]` spins up a minimal build environment, maps the current working directory as the build directory, and spawns `build.sh` with `args`.

## How to use

### tsave

This is a standalone tape record utility in the form of a classic "tape turbo".

The save code hooks into the Kernal Save vector chain, and listens on device #7 (as that's usual).

Data can be recorded either in a "bootstrapped", or a "standalone" turbo mode.

* A "bootstrap" recording consists of a standard Kernal header + a polling mode custom tape loader + the payload in the custom turbo format (similarly to standard turbo schemas known for the Plus/4).
* A "standalone" recording consists of a single custom turbo recording.

(Moral of the story: for a multi-load game, you'll typically want one single "bootstrap" recording part to get things going on, and a number of "standalone" recordings as further parts of your multi-load product.)

Slightly related note: you can also just use the "bootstrap" mode to record regular files to tape, like you'd use regular Plus/4 turbo tape utilities for this task.

To save files, use

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
; b0    - don't want border striping (during bootstrap load)
; b1-b7 - reserved, keep 0
; b7    - don't want a bootstrap, record a bare custom turbo file
```

(That is, by default, tsave creates "bootstrap" turbo recordings.)

Due to Tedmon's `S` command missing the secondary address parameter option, saving custom files might in practice require to set up Kernal SETLFS/SETNAM/SAVE from a small bit of additional code.

### tmaster

A crossplatform tool to produce a tape master file in raw, tap, or wav format.

Docs WIP

### tload

A non-blocking custom turbo loader that runs completely from timer interrupts.

See also: How to integrate tload into your product

## How to integrate tload

### Bootstrap

Every release recordings are supposed to start with a "bootstrap".

A bootstrap

* is recorded in bootstrap mode, so that this (very first) part can be loaded by stock Basic's Load command
* contains a polling mode loader, which (in turn) pulls in the bootstrap code from a subsequent custom turbo block
* contains a bootstrap code block - your own custom code -, that likely also embeds [tload](#tload), to load further parts of your product.

The polling mode loader is also responsible of running a speed measurement on the lead-in part of the custom turbo block. The polling loader is loaded, in part, to the tape buffer, and the system variable area from $0609 on. Autostart is performed by loading data to the IBSOUT vector ($0324-$0325).

[tmaster](#tmaster) has an extensive set of flags to customize bootstrap generation and appearance. (*This is something supposedly done by tsave as well, not implemented yet). You can control, for example, the way the border is supposed to be striped during loading (and whether it should be striped at all), if you want open or blank screen during bootstrap loading, if and how you want the code to be started when bootstrap loading concludes etc. etc. etc.. See Options.

### Integrating tload as a binary blob.

Grab the latest binary release bundle from [Releases](releases). (The binary bundles are named `t-utils-bin-<version>.tar.gz` .)

Review tload's [configuration file template](tloadcfg.inc.template) for addresses, zeropage locations, and related defaults.

Link the `tload.prg` binary into your bootstrap code as a binary blob, and make sure that the code resides at `$f800` at the time IRQ loading is to start first.

Keep in mind to always preserve whatever is written to `tbase` and `tsym` (a.k.a. $e6 and $e7 by default) by the polling loader. (You can evict and restore the values until using tload calls the next time, if you happen to need the zeropage locations.)

Note: by default, `tload` resides at `$f800`, and it strictly only runs in ROM-off memory configuration. It also uses several zeropage locations from $d0-$e7, and a few more Basic and standard Kernal Load variables (see [tloadcfg.inc.template](tloadcfg.inc.template) for details). Assembled code size is less than $300 bytes.

### Integrating tload as a self-built binary blob.

For this case, you can override tload's assembly time parameters (location, zeropage addresses etc.), with the ease of still not depending on tload's source structure and particular assembler, as per your own product.

Grab the latest source release bundle from [Releases](releases) ( `t-utils-<version>.tar.gz` ).

Copy [tloadcfg.inc.template](tloadcfg.inc.template) to `tloadcfg.inc` and [tutilscfg.inc.template](tutilscfg.inc.template) to `tutilscfg.inc`, and customize the configuration values as per your preferences.

Build the `tload.prg` binary (say, `build.sh tload.asm`).

From this on, see [Integrating tload as a binary blob](#integrating-tload-as-a-binary-blob).

### Integrating tload as source.

You can also use the [tload.asm](tload.asm) file as a source include file for your own boostrap code. That, of course, implies that either your code is in [dasm](https://dasm-assembler.github.io/) format, or, the `tload.asm` source is translated to your own assembler system's syntax.

To set up parameters / the source, things written in [Integrating tload as a self-built binary blob](#integrating-tload-as-a-self-built-binary-blob) apply.

Hint: you can also find clues by reviewing [tloadtest.asm](tloadtest.asm).

### How to use tload to load files

tload exports a jump table for it's functions starting at offset = 0 of it's code.

|Entry name       |Entry offset|In                       |Note                                 |
|-----------------|------------|-------------------------|-------------------------------------|
|tload_init       |$00         |N/A                      |Legacy from GCR mode, N/A for PLE    |
|tload_start      |$03         |filename, see below      |sets up IRQ load + filename to find  |
|tload_stop       |$06         |N/A                      |Restores the IRQ vector and masks    |


To effectively load a custom turbo file using the tload routine:

* call `tload_start` with filename start address in X/Y, and filename length in A. At this point, IRQ's can be globally disabled or enabled (in any case, the start routine would disable IRQ's for a short time, and set up it's own IRQ masks and handler).
* **A bit of warning** regarding file name: the routine is strict in only loading files of correctly (and in-full) specified file names. No wildcards and lazy file name specification are implemented.
* during loading, you can sync your own running code, for example, by setting up $ff0a/$ff0b to some particular rasterline, and polling bit 1 of $ff09 for triggers (then ACKing it by writing $02 to $ff09). Tload's code doesn't touch raster interrupt registers and IRQ masks during operation.
* poll `tstat_e` (default: $d0) for loader state changes, and inform the user accordingly. See state descriptions at Technical Data / tload.
* additionally, you may poll `tstat` (default: $d1) for more detailed state changes (likely unnecessary).
* tload's state machine keeps finding and attempting to load the specified file until a successful load is performed. A "load error", for example, is signaled to the main program (via state code and the ST variable), but the state machine is not stopped. Stopping the datassette while loading a file, likewise, signs a load error, but won't quit the find-and-load cycle. (Try playing around with that while running the `tloadtest` build.)
* The ST variable ($90 by default), other than signing the load error condition on it's side, acts as a kind of "ack" variable from the main program towards the tload state machine. When there's a load error, `tstat_e` = $03 and ST = >$80 are raised, and the datassette motor is stopped. This state is kept until both 1.) the datassette "stop" button is pressed by the user, *and* 2.) ST is cleared by main code. Then, the state machine re-enters at `tstat` = `tstat_e` = 0 i.e. it starts over. Moral of the story: upon load errors, you can tell the user that the load had failed (and that (s)he should, consequently, rewind the tape to xy), clear ST, and simply watch tstat_e to become zero to find out when exactly (s)he really stopped the datassette and started rewinding. 
* Once `tstat_e` ends up in the ready-with-success state (=$04), you can conclude the loading part. (Technically, you can of course also quit the find / load cycle at any arbitrary point, if so desired, and call `tload_stop`.)
* call `tload_stop`. This routine restores your original IRQ vector and IRQ masks (as found at the time of calling `tload_start`).

You may want to take a look at the code of [tloadtest](tloadtest.asm) (especially from the `.rloop0` label and on) on how this is supposedly done, and also play around with `tloadtest` (either in emulator or the real machine) to get an idea of how this is practically supposed to work. `build.sh` produces, amongst other things, a `.tap` file with `tloadtest` plus a dummy test file linked together.

### Display helper routines

Tload implements a handful of additional routines to help visualization.

(These routines are totally "async", a.k.a. they're not part of the IRQ or state machine, they can be called anytime from your code.)

|Entry name       |Entry offset|In                       |Out                                  |
|-----------------|------------|-------------------------|-------------------------------------|
|tload_getprogress|$09         |N/A                      |Bytes left to load + 255 in X/A (L/H)|
|tload_bin2dec    |$0c	       |number in A              |Decimal digits in Y/X/A (L/M/H)      |
|tload_pr2time    |$0f	       |number in X/A            |"Number of secs left" in A           |
|tload_bin2t      |$12         |number in A              |time in Y/X/A (sec/10sec/min)        |

Additional notes.

* `tload_getprogress` returns 0 until effective data loading is started.
* `tload_pr2time` basically scales the 16-bit number in X/A by a 8-bit constant calculated at assembly time, to yield, if supplied the number of bytes left to load, roughly the _number of seconds left_ from loading the data.
* to keep memory footprint small, neither routines use tables to implement multiplication and division. OTOH, generally, they're not prohibitively slow to use, either.

See [tloadtest.asm](tloadtest.asm) code (especially after the `.rloop` label) and try running the `tloadtest` build to get an idea.

## Technical data

### Custom tape format

T-utils from V0.2.0 and up, by default, uses PLE (Pulse Length Encoding) to record data. PLE is the usual general recording method used by stock Commodore Kernal tape I/O routines and third-party custom loaders. Data bits in PLE are denoted by the length (in time) of subsequent signal pulses.

Default timing T for data recording is $70 cycles. The recording strictly employs symmetric pulses. Pulses extend from falling edges to falling edges. (*"Full-wave" tap files can be used to store the recordings.)

Bytes are stored sequentially, MSB first.


|Bit	|denoted by           |
|-------|---------------------|
|0	|2T * low, 2T * high  |
|1	|T * low, T * high    |

As per a roughly even distribution of 0 and 1 bits of compressed data payloads, average nominal data rate is 17734470/20/T/3, a.k.a. 2639bps, a.k.a. ~330 bytes per second.

Data is stored in a unified block format (which applies to both bootstrap data blocks and standalone files).


|Name         |Data                   |Note                                                   |
|-------------|-----------------------|-------------------------------------------------------|
|Lead-in      |$0500 bytes of $ff     |							      |
|Lead-in end  |$fe, $ee               |Signs the lead-in's end, header's start                |
|File type    |one byte               |0 --> bootstrap mode turbo block, 1 --> standalone file|
|Filename     |16 bytes               |absent from bootstraps                                 |
|Start address|2 bytes                |absent from bootstraps                                 |
|End address  |2 bytes                |absent from bootstraps                                 |
|Data payload |End-Start bytes of data|                                                       |
|Checksum     |1 byte                 |EOR of full data payload                               |
|Lead-out     |$0100 bytes of $ff     |                                                       |

Note: as you can see, there's technically a file header defined and used, yet, the file header and data payload are physically within the same continuous data unit.

### tload

Tload uses Timer 2 and hooks to the CPU IRQ vector to track and decode the tape data stream.

By tricks employed in the IRQ routine code, it's ensured that

* the main program in the background is never blocked for more than $270-some timer cycles (not even when there's no incoming tape signal)
* pulse length quantization margin is symmetric ±T, a.k.a. nominal ±112 a.k.a. a whole 224 timer cycles.
* quantization error imposed by the open screen is ± *1* TED badline time

( * On the con-side, the IRQ routine obviously employs a *lot* of busy waiting.)

Tload's version string is embedded into the tload binary blob after the jump table, starting from offset $15.

Tload's state machine currently implements the following "external" state identifiers (as exported in `tstat_e` a.k.a $d0 by default):

```
; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (fail, ST=$ff)
;04	ready (success, ST=0)
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
;08	complete (error)
;09	complete (success)
```

### tsave

Contains code pieces to record a custom Kernal tape format bootstrap, plus, the custom turbo format.

The code embeds the polling mode turbo loader, which is saved prior to "bootstrap" mode recordings.

## GCR Mode

T-utils had originally employed [GCR](https://en.wikipedia.org/wiki/Group_coded_recording#Commodore) encoding mode to record it's custom format. As it turned out later, GCR failed to survive at least one particular analog duplication facility, so, the function was canned, and PLE recording mode was implemented from scratch to remedy the situation.

GCR is fully retained in the code base (see: conditional assembly), but is not built by default, and it's use is discouraged. You can build a GCR mode toolset, if you want, by setting up mode in `tutilscfg.inc` accordingly, and running `build.sh`.

Nominal bit timing T is 192 single clock cycles in GCR mode, which (in PAL) makes a constant data rate of ~4618 raw bits, a.k.a ~924 GCR nybbles, a.k.a ~462 decoded bytes per second (while employing much lower frequency components than that of PLE). OTOH, data quantization margin is just ±T/2 a.k.a. ±96 timer cycles, much worse than that of PLE.

GCR encoding is by-design not yielding symmetric signal pulses, and from that point on, timing precision gets hampered by the equipment's bad low-frequency characteristics. GCR recordings also need to be stored in "half-wave" .tap files, accordingly.

The format is using `$1f` GCR nybbles for Lead-in and Lead-out, and three subsequent `$1e` nybbles to signal Lead-in end. Otherwise, on top of GCR encoding, the exact same block format applies as that already described at PLE.

The GCR IRQ loader runs off Timer 1 (rather than Timer 2). The code uses constant rate sampling to read data, and it implements a circular buffer to decouple realtime sampling from actual data processing and loader state management. Sampling happens at the horizontal line rate (57 single clock cycles). Due to the way the sampling code is implemented (timing is very tight, especially around the TED's blocking DMA's), the screen can not be blanked, or the vertical scroll bits tampered with, while the GCR IRQ loader is running.

For decoding GCR, a couple of precalculated tables are used, which means that the code needs an additional 1K of BSS space to run (located at $f400 and on), and the tables need to be initialized by calling tload_init prior to calling tload_start. The tables can be discarded of after concluding the data loading process.

Loading works on both PAL and NTSC machines.

## Releases

See [Releases](releases).

## License

Files in this package are distributed under the Zlib license (see: [LICENSE](LICENSE)), (C) 2024-2026 Levente Hársfalvi
