# t-utils

A.k.a. "Tape-Utils".

## Warning

As of 2026.06.01, still everything is subject to change.

## Overview
T-utils is a set of utilities to assist the production of cassette tape based software releases for the [Commodore 264 series](https://en.wikipedia.org/wiki/Commodore_Plus/4).

It consists of:

* tload - a resident tape IRQ loader routine that can be linked into software products
* tsave - a standalone save routine that produces tload's custom recording format
* tmaster - a crossplatform utility to create tape master recordings for production
* tloadtest - a simple utility to test and demonstrate tload's operation

## How to build

You might not need this (see: binary release bundles); when you do, use [build.sh](build.sh).

* `build.sh` - build everything
* `build.sh some-source-file` - build specific file(s)
* `build.sh clean` - clean up source directory
* `build.sh dist` - create source release bundle
* `build.sh bdist` - create binary release bundle

To build the artifacts, you'll need a Posix compatible environment, bash, Python 3, and [dasm](https://github.com/dasm-assembler/dasm) (V2.0 or above).

Alternatively, you can use the supplied [Dockerfile](Dockerfile) to spin up a [Debian](https://www.debian.org) based build container. See: [Build container](#build-container).

## How to use

### tsave

This is a standalone, native tape recording utility in the form of a classic "tape turbo".

The save code hooks into the Kernal Save vector chain, and listens on device #7 (as that's usual).

Data can be recorded either in a "bootstrapped", or a "standalone" turbo mode.

* A "bootstrap" recording consists of a standard Kernal header + a polling mode custom tape loader + the payload in the custom turbo format (similarly to standard turbo schemas known on the Plus/4).
* A "standalone" recording consists of a single custom turbo recording.

(Hint: for a multi-load game, you'll typically want one single "bootstrap" recording part to get things going on, and a number of "standalone" recordings as further parts of your multi-load product.)

Slightly related note: you can also just use the "bootstrap" mode to record regular files to tape, like you'd use regular Plus/4 turbo tape utilities for that.

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

Setting up Kernal Save the standard way (SETLFS, SETNAM, SAVE) from custom code also works.

### tmaster

Tmaster is a crossplatform command-line tool that generates master tape recording files.

It accepts one or more binary input files and produces a `.raw`, `.tap`, or `.wav` output containing a complete, ready-to-duplicate tape image.


#### Usage

```
tmaster [global args] input_file "recorded_name" [file args] [...] output.{raw|tap|wav}
```

#### Global arguments

| Argument              | Description                                          | Default          |
|-----------------------|------------------------------------------------------|------------------|
| `-h`                  | Show help                                            | -                |
| `-gcr` / `-ple`       | Custom encoding                                      | `-ple`           |
| `-N x`                | Timing base in T units                               | PLE: 14, GCR: 24 |
| `-Cc` / `-Cu` / `-Cs` | PETSCII conversion: convenient / unshifted / shifted | `-Cc`            |

(Note: "T units" are that of tap format's timebase units, a.k.a. 8 single clock cycles.)

(Note 2: "Convenient" conversion effectively means "unshifted", with alphanumeric characters converted to upcase first.)

#### Per-file arguments

Each input file is followed by its target (recorded) name and optional flags.

| Argument          | Description                                  | Default |
|-------------------|----------------------------------------------|---------|
| `input_file`      | Source binary (first 2 bytes = load address) | -       |
| `"recorded_name"` | Filename on the tape                         | -       |
| `-b` / `-s`       | Record as bootstrap / standalone             | `-b`    |

#### Bootstrap options

| Argument        | Description                                       | Default |
|-----------------|---------------------------------------------------|---------|
| `-Sy` / `-Sn`   | Short bootstrap: omit Round 1 Kernal blocks       | `-Sn`   |
| `-Oy` / `-On`   | Open screen during load                           | `-On`   |
| `-ORy` / `-ORn` | Restore open-screen state                         | `-ORy`  |
| `-By` / `-Bn`   | Border striping (disabling also sets `-BIn -BRn`) | `-By`   |
| `-BIy` / `-BIn` | Increment border colour                           | `-BIy`  |
| `-BUa` / `-BUe` | Border update method: ADC / EOR                   | `-BUe`  |
| `-BUV x`        | Border update value                               | `0x41`  |
| `-BRy` / `-BRn` | Restore border colour                             | `-BRy`  |
| `-BRV x`        | Restore colour value                              | `0xee`  |
| `-E x`          | Execute address                                   | `0x8703`|
| `-run`          | Shortcut: `-E 0x8bcd`                             | -       |
| `-herc`         | Shortcut: `-BUe -BUV 0x41`                        | -       |
| `-her`          | Shortcut: `-BUa -BUV 0x10`                        | -       |
| `-axon`         | Shortcut: `-BUa -BUV 0x38`                        | -       |
| `-nova`         | Shortcut: `-BUe -BUV 0x7f`                        | -       |

#### Output formats

| Extension | Format                                                                        |
|-----------|-------------------------------------------------------------------------------|
| `.raw`    | Raw bitstream — one logical level per T, MSB-first packed bytes               |
| `.tap`    | TAP container — V1 (PLE, H→L intervals) or V2 (GCR, all-transition intervals) |
| `.wav`    | RIFF/WAV audio file — resampled from PAL T-rate, 8/16-bit, mono/stereo        |

#### WAV output arguments

Placed after the output filename, all optional. These flags are only valid for `.wav` output.

| Argument | Description                          | Default |
|----------|--------------------------------------|---------|
| `-s x`   | Sampling frequency (Hz)              | `44100` |
| `-c x`   | Channels: `1`=mono, `2`=stereo       | `1`     |
| `-d x`   | Bit depth: `8`=unsigned, `16`=signed | `8`     |
| `-i`     | Invert signal (swap L/H levels)      | -       |

#### Examples

Save a single prg file in bootstrap mode.

```
 ./tmaster game.prg game out.tap
```

Save `tloadtest.prg` as a "short" bootstrap recording (omit recording half the Kernal mode part), to be loaded with open screen, Novaload-style border striping, and autostart by Basic RUN. Append `build/testfile.prg` as `payload` in standalone custom turbo format. Write the result to `tloadtest.tap`.

(That's more or less a direct excerpt from [build.sh](build.sh).)

```
./tmaster tloadtest.prg tloadtest -Sy -Oy -nova -run build/testfile.prg payload -s tloadtest.tap
```

### tload

A non-blocking custom turbo loader, that runs off a periodic timer IRQ.

See: How to integrate tload into your product

## How to integrate tload

### Bootstrap

Every release recordings are supposed to start with a "bootstrap".

A bootstrap

* is recorded in bootstrap mode, so that this (very first) part can be loaded by stock Basic's Load command
* contains a polling mode loader, which (in turn) pulls in the bootstrap code from a subsequent custom turbo block
* contains a bootstrap code block - your own custom code -, that likely also embeds [tload](#tload), to load further parts of your product.

The polling mode loader is also responsible of running a speed measurement on the lead-in part of the custom turbo block (and storing the result in `tbase` and `tsym` for later use in tload). The polling loader code is loaded to the tape buffer and the system variable area from $0609 on. Autostart is performed by loading data to the IBSOUT vector ($0324-$0325).

[tmaster](#tmaster) has an extensive [set of flags](#bootstrap-options) to customize bootstrap generation and appearance. (*This is something supposedly done by tsave as well, not implemented yet). You can control, for example, the way the border is supposed to be striped during bootstrap loading (and, whether it should be striped at all), if you want open or blank screen during bootstrap loading, if and how you want the code to be started when bootstrap loading concludes etc. etc. etc.. See [Options](#tmaster).

### Integrating tload as a binary blob.

* Grab the latest binary release bundle from [Releases](releases). (The binary bundles are named `t-utils-bin-<version>.tar.gz` .)
* Review tload's [configuration file template](tloadcfg.inc.template) for addresses, zeropage locations, and related defaults.
* Link the `tload.prg` binary into your bootstrap code as a binary blob, and make sure that the code ends up residing at `$fa00` at the time it's to be executed first.

### Integrating tload as a self-built binary blob.

This case has the benefit of being able to redefine tload's assembly time parameters (location, zeropage addresses etc.), while still not being dependent on tload's source structure and particular assembler, as per your own product.

* Grab the latest source release bundle from [Releases](releases) ( `t-utils-<version>.tar.gz` ).
* Copy [tloadcfg.inc.template](tloadcfg.inc.template) to `tloadcfg.inc` and [tutilscfg.inc.template](tutilscfg.inc.template) to `tutilscfg.inc`, and customize the configuration values as per your preferences.
* Build the `tload.prg` binary (say, `build.sh tload.asm`).

From this on, see [Integrating tload as a binary blob](#integrating-tload-as-a-binary-blob).

### Integrating tload as source.

You can also use the [tload.asm](tload.asm) file as a source include file for your own boostrap code. That, of course, implies that either your code is in [dasm](https://dasm-assembler.github.io/) format, or, the `tload.asm` source is translated to your own assembler system's syntax.

To set up parameters / the source, things written in [Integrating tload as a self-built binary blob](#integrating-tload-as-a-self-built-binary-blob) apply.

Hint: you can also find clues by reviewing [tloadtest.asm](tloadtest.asm).

### How to use tload to load files

tload exports a jump table, that starts at offset 0 of the assembled binary.

|Entry name       |Entry offset|In                       |Note                                 |
|-----------------|------------|-------------------------|-------------------------------------|
|tload_init       |$00         |N/A                      |Legacy from GCR mode, N/A for PLE    |
|tload_start      |$03         |filename, see below      |sets up IRQ load + filename to find  |
|tload_stop       |$06         |N/A                      |Restores the IRQ vector and masks    |


To effectively load a custom turbo file using the tload routine:

* call `tload_start` with filename length in A, and filename start address in X/Y. The routine grabs and saves the current IRQ config, sets up it's own IRQ masks and handler, and stores the filename parameters in memory.
* **A bit of warning** regarding file name: the routine is strict in only loading files of correctly (and in-full) specified file names. No wildcards and lazy file name specification are implemented.
* during loading, you can sync your own running code, preferably, by setting up $ff0a/$ff0b to some particular rasterline, and use bit 1 of $ff09 as a trigger (...then ACKing it by writing $02 to $ff09). Tload's code doesn't touch raster interrupt registers and IRQ masks during operation.
* poll `tstat_e` (default: $d0) in your code for loader state changes, and inform the user accordingly. See [tload state machine states](#tload-state-machine-states).
* tload's state machine keeps looking for and attempting to load the specified file until the task finishes with succeess. A "load error", for example, is signaled to the main program (via state code and the ST variable), but the state machine is not stopped. The user's decision to stop the datassette while loading a file, likewise, signs a load error, but won't quit the find-and-load loop. (Try playing around with that while running the `tloadtest` utility.)
* The ST variable ($90 by default), other than signing the load error condition on it's side, acts as a kind of "ack" variable from the main program towards the tload state machine. Upon start, ST=0. When there's a load error, `tstat_e = $03` and `ST = >$80` are raised, and the datassette motor is stopped. This state is kept until both 1.) the datassette is stopped by the user, *and* 2.) ST is cleared by main code. Then, the state machine re-enters at `tstat_e = 0` i.e. it starts over. Moral of the story: upon load errors, you can tell the user that the load has failed (and that (s)he should, consequently, rewind / re-position the tape, clear ST, and simply watch `tstat_e` to become zero to find out when exactly (s)he really stops the datassette and starts rewinding the tape. 
* Once `tstat_e` ends up in the finished-with-success state ( `=$04` ), you can conclude the loading part.
* call `tload_stop`. This routine restores your original IRQ vector and IRQ masks (as found at the time of calling `tload_start`).

You may want to take a look at the code of [tloadtest](tloadtest.asm) (especially from the `.rloop0` label and on) on how this is supposedly done, and also play around with `tloadtest` (either in emulator or the real machine) to get an idea of how this is practically supposed to work. `build.sh` produces, amongst other things, a `.tap` file with `tloadtest` and a dummy test file linked together, so that basic testing would be easy to set up.

Keep in mind to always preserve data written to `tbase` and `tsym` (a.k.a. `$e6` and `$e7` by default) by the polling loader. (You can evict the values between load times, if needed.)

Note: by default, `tload` resides at `$fa00`, and it strictly only runs in ROM-off memory configuration. It also uses several zeropage locations from `$d0-$e7`, and a few more Basic and standard Kernal Load variables (see [tloadcfg.inc.template](tloadcfg.inc.template) for details). Assembled code size is less than $300 bytes.

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
* to keep memory footprint small, neither routines use tables to implement multiplication and division (...there's likely a faster method there to produce the values, at the expense of using more memory).

See [tloadtest.asm](tloadtest.asm) code (especially after the `.rloop` label) and try running the `tloadtest` build to get an idea.

## How to create tape master recordings

Once the binary pieces of the product become available, creating a master recording can be done in a matter of running [tmaster](tmaster) with a presumably long parameter list.

What you'll need to know or decide are

* aesthetical properties (bootstrap load open / closed screen, method of border striping etc., see [Bootstrap options](#bootstrap-options) )
* method of autostart (fixed address, run) and init (or, lack thereof) to be done prior to your code's autostart
* filenames used by the prod / the loader. (Tmaster obviously needs to know the filenames you'll try to find by tload's setup later on.)
* target file type. (For online sites, .tap should be perfect. For cassette duplicator facilities, you'll likely need to supply a .wav file.)
* in case of producing physical recordings, the recorder signal chain's input polarity. (Commodore's tape recordings are, unfortunately, not agnostic to polarity. Polarity absolutely needs to match.)

Hint: for most cases, you'll likely want to create a custom wrapper shell script to run tmaster with your parameter list, to keep track of every flags, filenames, target filenames etc. 

## Technical data

### Custom tape format

T-utils from V0.2.0 and up, by default, uses PLE (Pulse Length Encoding) to record data. PLE is the usual general recording method used by stock Commodore Kernal tape I/O routines and third-party custom loaders. Data bits in PLE are denoted by the length (in time) of subsequent signal pulses.

Default / nominal timing T for data recording is $70 cycles. The recording strictly employs symmetric pulses. Pulses extend from falling edges to falling edges. (*"Full-wave" tap files can be used to store the recordings.)

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

Note: as you can see, there's technically a file header defined and used, yet, file header and data payload are physically located within one continuous data unit.

### tload

Tload uses Timer 2 and hooks to the CPU IRQ vector to track and decode the tape data stream.

By tricks employed in the IRQ routine code, it's ensured that

* the main program in the background is never blocked for more than $270-some timer cycles (not even when there's no incoming tape signal)
* pulse length quantization margin is symmetric ±T, a.k.a. nominal ±112 a.k.a. a whole 224 timer cycles.
* quantization error imposed by the open screen is ± *1* TED badline time

( * On the con-side, the IRQ routine obviously employs a *lot* of busy waiting.)

* Tload uses the measurement result of the polling loader to set up actual quantization threshold.
* Tload's version string is embedded into the tload binary blob after the jump table, starting from offset `$15`.
* There's no separate PAL and NTSC code. Tload in fact doesn't care whether it is running on a PAL or NTSC (or PAL-N) machine. Signal speed variations, in the largest part, are caused by datassette motor speed variations (anyway).

#### tload state machine states

Tload's state machine currently implements the following "external" state identifiers (as exported in `tstat_e` a.k.a `$d0` by default):

```
; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (fail, ST=$ff)
;04	ready (success, ST=0)
```

Additionally, the internal states implemented by the code (as found in `tstat` a.k.a `$d1`) are as below:

```
; tstat
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

There's nothing really to say here. Tsave also contains code to be able to record a custom Kernal tape format bootstrap, plus, the custom turbo format.

The code also embeds the polling mode turbo loader, which is saved prior to "bootstrap" mode recordings.

### tmaster

The utility was written by [Claude Code](https://claude.com/product/claude-code) in Python, following [specs](tmaster.spec) written by me. Of any technical questions, the specs should be the sources to follow.

[build.sh](build.sh) is used to patch the [tmaster](tmaster) code, for it to always have the latest bootstrap loader binary code snippets and patch address offset list.

## GCR Mode

T-utils had originally employed [GCR](https://en.wikipedia.org/wiki/Group_coded_recording#Commodore) encoding mode to record it's custom format. As it turned out later, the GCR recording failed to survive at least one particular analog duplication facility, so, the method was dropped, and PLE recording mode was implemented to remedy the situation.

GCR is fully retained in the code base (see: conditional assembly), but is not built by default, and it's use is discouraged. You can build a GCR mode toolset, if you want, by setting up mode in `tutilscfg.inc` accordingly, and running `build.sh`.

Nominal bit timing T is 192 single clock cycles in GCR mode, which (in PAL) makes a constant data rate of ~4618 raw bits, a.k.a ~924 GCR nybbles, a.k.a ~462 decoded bytes per second (while employing much lower frequency components than that of PLE). OTOH, data quantization margin is ±T/2 a.k.a. ±96 timer cycles, a bit worse than that of PLE.

GCR encoding by-design won't yield symmetric signal pulses, and from that point on, timing precision gets hampered by equipment's apparently bad frequency characteristics. GCR recordings also need to be stored in "half-wave" .tap files, accordingly.

The format is using `$1f` GCR nybbles for Lead-in and Lead-out (rather than bytes `$ff`), and three subsequent `$1e` nybbles (rather than bytes `$fe $ee`) to signal Lead-in end. Otherwise, on top of low-level GCR encoding, PLE's exact same block format applies.

The GCR IRQ loader runs off Timer 1 (rather than Timer 2). The code uses constant rate sampling to read data, and implements a circular buffer to decouple realtime sampling from actual data processing. Sampling happens at the horizontal line rate (57 single clock cycles). Due to the way the sampling code is implemented (timing is very tight, especially around the TED's blocking DMA's), the screen must not be blanked, and the vertical scroll bits must not be tampered with, while the GCR IRQ loader is running.

The GCR loader code is larger. By default, it's assembled to run from $f800. Moreover, GCR decoding employs precalculated tables, which means that the code needs an additional 1K of BSS space to run (located at $f400 and on), and the tables need to be initialized by calling `tload_init` prior to calling `tload_start`. The tables can be discarded of after concluding the data loading process.

Loading works on both PAL and NTSC machines.

The GCR polling loader code also produces a measurement for the (a)symmetry of the bootstrap lead-in signal. (Some datassettes happen to show very asymmetric low-to-high and high-to-low comparator characteristics, which is a relevant parameter here, but not for the usual encoding schemas (or any of the other 8-bit Commodore platforms whatsoever).) Also, the GCR polling loader (unlike the PLE one) won't work with open screen.

## Build container

A.k.a. an isolated, defined, minimal build environment.

Build the container image by running this command in the source directory.

```
docker build -t tbuild:latest .
```
Spin up a container and execute the [build.sh](build.sh) script by running

```
docker run -e USER=$(id -u) -e GROUP=$(id -g) -v $(pwd):/build -it --rm tbuild [args]
```
The apparent magic involving the environment variables let the container run the build with your own user and group ID's (so that files would be created with the right ownership). The volume mount part mounts your current directory as the working directory in the container.

The `[args]` part is simply passed on to [build.sh](build.sh).

The special argument of `sh` skips running the build script, and drops you into a shell within the build container.

## Releases

See [Releases](releases).

## License

Files in this package are distributed under the Zlib license (see: [LICENSE](LICENSE)), (C) 2024-2026 Levente Hársfalvi
