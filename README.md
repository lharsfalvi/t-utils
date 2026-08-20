# t-utils

A.k.a. "Tape-Utils".

## Overview
T-utils is a set of utilities to assist the work of producing cassette tape based software releases for the [Commodore 264 series](https://en.wikipedia.org/wiki/Commodore_Plus/4).

Currently, it consists of:

* tload - a resident tape IRQ loader routine that can be linked into software products
* tsave - a standalone save routine that produces tload's custom recording format
* tmaster.py - a cross-platform utility to create tape master recordings for production
* tloadtest - a simple utility to test and demonstrate tload's operation

## How to use

### tsave

This is a standalone, native tape recording utility in the form of a classic "tape turbo".

The save code hooks to the Kernal Save vector chain, and listens on device #7.

Data can be recorded either in a "bootstrapped", or a "standalone" turbo mode.

* A "bootstrap" recording consists of a polling mode custom loader recorded in standard Kernal format + a payload in custom turbo format.
* A "standalone" recording consists of a single custom turbo recording (actually a header + the payload in one merged turbo block).

Hint: a bootstrap recording is exactly like the common Turbo recordings that one knows on this platform. These recordings can be loaded by stock Basic/Kernal Load. They ensure that control is taken from the Kernal load routines, load in a subsequent custom turbo block, and either return to the Kernal, or pass control on to the loaded custom code (i.e. autostart).

Hint 2: for a multi-load game, you'll typically want one single bootstrap recording part to get things going, and a number of standalone turbo recordings as parts of your multi-load product.

Slightly related note: consequently, you can also just use "bootstrap" mode to record regular files to tape, the way you'd use regular Plus/4 turbo tape utilities.

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
; b1-b6 - reserved, keep 0
; b7    - don't want a bootstrap, record a bare custom turbo file
```

(That is, by default, tsave creates "bootstrap" turbo recordings.)

Setting up Kernal Save the standard way (SETLFS, SETNAM, SAVE) from custom code also works.

Note: there is a set of planned features in tsave (those that'd control aesthetics and autostart), not yet implemented.

### tmaster.py

Tmaster.py is a cross-platform command-line tool that generates master tape recording files.

It accepts one or more binary input files and produces a `.raw`, `.tap`, or `.wav` output containing a complete, potentially ready-to-duplicate tape image.

#### Usage

```
(python3) tmaster.py [global args] input_file "recorded_name" [file args] [...] output.{raw|tap|wav}
```

#### Global arguments

| Argument              | Description                                          | Default          |
|-----------------------|------------------------------------------------------|------------------|
| `-h`                  | Show help                                            | -                |
| `-gcr` / `-ple`       | Custom encoding                                      | `-ple`           |
| `-N x`                | Timing base in T units                               | PLE: 14, GCR: 24 |
| `-Cc` / `-Cu` / `-Cs` | PETSCII conversion: convenient / unshifted / shifted | `-Cc`            |

(Note: A T unit here is that of tap format's timebase unit, a.k.a. 8 single clock cycles.)

(Note 2: "convenient" PETSCII conversion means an "intuitively right" character conversion method. It effectively means "unshifted", with alphanumeric characters converted to uppercase first. See also: Unicode to [unshifted](tmaster.spec/unicode_petscii_lut_unshifted.txt) and [shifted](tmaster.spec/unicode_petscii_lut_shifted.txt) PETSCII in tmaster.py's [specs](tmaster.spec).)

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
 ./tmaster.py game.prg game out.tap
```

Save `tloadtest.prg` as a "short" bootstrap recording (omit recording the first halves of the Kernal mode part), custom data to be loaded with open screen, Novaload-style border striping, and autostart by Basic RUN. Append `build/testfile.prg` as `payload` in standalone custom turbo format. Write the result to `tloadtest.tap`.

(That's more or less a direct excerpt from [build.sh](build.sh).)

```
./tmaster.py tloadtest.prg tloadtest -Sy -Oy -nova -run build/testfile.prg payload -s tloadtest.tap
```

### tload

A non-blocking custom turbo loader, that runs off a periodic timer IRQ.

See: [How to integrate tload into your product](#how-to-integrate-tload)

## How to build

You might not need this (see: binary release bundles on the [Releases](../../releases) page) at all. If you need to, use [build.sh](build.sh).

* `./build.sh` - build everything
* `./build.sh some-source-file` - build specific file(s)
* `./build.sh clean` - clean up source directory
* `./build.sh dist` - create source release bundle
* `./build.sh bdist` - create binary release bundle

To build the artifacts, you'll need a POSIX compatible environment, bash, Python 3, and [dasm](https://github.com/dasm-assembler/dasm) (V2.0 or above).

Alternatively, you can use the supplied [Dockerfile](Dockerfile) to spin up a [Debian](https://www.debian.org) based build container. See: [Build container](#build-container).

## How to integrate tload

### Bootstrap

Release recordings are supposed to start with a "bootstrap".

A bootstrap

* is recorded in bootstrap mode, so that it can be loaded by the user from Basic
* contains a polling mode loader, which (in turn) pulls in the bootstrap code from a subsequent custom turbo block
* contains a bootstrap code block - your own custom code - that likely also embeds [tload](#tload), to load further parts of your product.

The polling mode loader is also responsible for running a speed measurement on the lead-in part of the custom turbo block (and storing the result in `tbase` and `tsym` for later use in tload). The polling loader code is loaded to the tape buffer and the system variable area from $0609 on. The polling loader's own autostart is performed by loading data to the IBSOUT vector ($0324-$0325).

[tmaster.py](#tmaster.py) has an extensive [set of flags](#bootstrap-options) to customise bootstrap generation and appearance. (*This is something supposedly done by tsave as well, not implemented yet). You can control, for example, the way the border is to be striped during bootstrap loading (and, whether it should be striped at all), if you want open or blank screen during bootstrap loading, if and how you want the code to be started when bootstrap loading concludes, and so on. See [Options](#tmaster.py).

### Integrating tload as a binary blob.

* Grab the latest binary release bundle from [Releases](../../releases). (The binary bundles are named `t-utils-bin-<version>.tar.gz`.)
* Review tload's [configuration file template](tloadcfg.inc.template) for addresses, zeropage locations, and related defaults.
* Link the `tload.prg` binary into your bootstrap code as a binary blob, and make sure that the code ends up residing at `$fa00` at the time it's executed first.

### Integrating tload as a self-built binary blob.

This option has the benefit of being able to redefine tload's assembly-time parameters (location, zeropage addresses etc.), while still not being dependent on tload's source structure and particular assembler, as per your own product's development setup.

* Grab the latest source release bundle from [Releases](../../releases) (`t-utils-<version>.tar.gz`).
* Copy [tloadcfg.inc.template](tloadcfg.inc.template) to `tloadcfg.inc` and [tutilscfg.inc.template](tutilscfg.inc.template) to `tutilscfg.inc`, and customise the configuration values as per your preferences.
* Build the `tload.prg` binary (say, `./build.sh tload.asm`).

From this on, see [Integrating tload as a binary blob](#integrating-tload-as-a-binary-blob).

### Integrating tload as source.

You can also use the [tload.asm](tload.asm) file as a source include file for your own bootstrap code. That, of course, implies that either your code is in [dasm](https://dasm-assembler.github.io/) format, or, the `tload.asm` source is translated to your own assembler system's syntax.

To set up parameters / the source, things written in [Integrating tload as a self-built binary blob](#integrating-tload-as-a-self-built-binary-blob) apply.

Hint: you can also find clues by reviewing [tloadtest.asm](tloadtest.asm).

### How to use tload to load files

tload exports a jump table, that starts at offset 0 of the assembled binary.

|Entry name       |Entry offset in jump table|In                       |Note                                 |
|-----------------|--------------------------|-------------------------|-------------------------------------|
|tload_start      |$00                       |filename, see below      |sets up IRQ load + filename to find  |
|tload_stop       |$03                       |N/A                      |Restores the IRQ vector and masks    |


To effectively load a custom turbo file using the tload routine:

* call `tload_start` with filename length in A, and filename start address in X/Y. The routine grabs and saves the current IRQ config, sets up its own IRQ masks and handler, and stores the filename parameters in memory.
* **A bit of warning** regarding filename: the routine is strict in only loading files of correctly (and in-full) specified filenames. Also, no wildcards are implemented.
* you can't use IRQ's while the loader is running. On the other hand, the main program space (given that the loader is running in IRQ space) is fully yours to work with. You can sync/time your own running code, preferably, by setting up $ff0a/$ff0b, and polling bit 1 of $ff09 (say, use `bit $ff09` in a loop with a pre-loaded mask of $02 in A, then `sta $ff09` after the match is triggered) to keep track of subsequent display frames. Tload's code doesn't touch raster interrupt registers and IRQ masks during operation.
* poll `tstat_e` (default: $d0) in your code for loader state changes, and inform the user accordingly. See [tload state machine states](#tload-state-machine-states).
* tload's state machine keeps looking for and attempting to load the specified file until the task finishes with success. A "load error", for example, is signalled to the main program (via state code and the ST variable), but the state machine is not stopped. The user's decision to stop the datassette while loading a file, likewise, signs a load error, but won't quit the find-and-load loop. (Try playing around with that while running the `tloadtest` utility.)
* The ST variable ($90 by default), other than signalling the load error condition on the loader's side, acts as a kind of "ack" variable from the main program towards the tload state machine. Upon start, ST=0. When there's a load error, `tstat_e = $03` and `ST = >$80` are raised, and the datassette motor is stopped. This state is kept until both 1.) the datassette is stopped by the user, *and* 2.) a non-zero non-negative value is written to ST by main code. Then, the state machine re-enters at `tstat_e = 0` and `ST = 0` i.e. it starts over. Moral of the story: upon load errors, you can tell the user that the load failed (and that (s)he should, consequently, rewind / re-position the tape), settle ST, and simply watch `tstat_e` to become zero to find out when exactly the user really stops the datassette and starts rewinding the tape.
* Once `tstat_e` ends up in the ready state with success ( `=$03`, and `ST=0` ), you can conclude loading.
* call `tload_stop`. This routine restores your original IRQ vector and IRQ masks (as found at the time of calling `tload_start`).

(Bottom line: you can also call `tload_stop` upon load errors, and handle re-initialisation manually. Tload wouldn't care - when tload_start is called the next time, the state machine is re-inited anyway.)

You may want to take a look at the code of [tloadtest](tloadtest.asm) (especially from the `.rloop0` label and on) on how this is supposedly done, and you can also play around with `tloadtest` (either in emulator or on the real machine) to get an idea of how this is practically supposed to work. (Note: tloadtest currently won't prompt on failed loading. It simply increments the number of fails, and starts over. That's because tloadtest is/was also used to bulk-test tload's reliability on different datassette units.) `build.sh` produces, amongst other things, a `.tap` file with `tloadtest` and a dummy test file linked together, so that basic testing would be easy to do.

Keep in mind to always preserve data in `tbase` and `tsym` (a.k.a. `$e6` and `$e7` by default) stored there by the polling loader. (You can evict the values between loading times if needed.)

Note: by default, `tload` resides at `$fa00`. It also uses several zeropage locations in `$d0-$e7`, plus a few more standard Basic and Kernal Load variables (see [tloadcfg.inc.template](tloadcfg.inc.template) for details). Code and zeropage locations can be overridden if necessary (you have to create a custom tloadcfg.inc and build the tload binary, see: [Integrating tload as a self-built binary blob](#integrating-tload-as-a-self-built-binary-blob) and on). Assembled code size is less than $300 bytes.

Tload strictly only runs with the ROMs switched off (even if it's relocated to somewhere under $8000).

### Display helper routines

Tload implements a handful of additional routines to help visualisation.

(These routines are "async", a.k.a. they're not part of tload's IRQ code or state machine. They can be called from your code without restrictions.)

Jump table (continued from [How to use tload to load files](#how-to-use-tload-to-load-files) )

|Entry name       |Entry offset in jump table|In                       |Out                                  |
|-----------------|--------------------------|-------------------------|-------------------------------------|
|tload_getprogress|$06                       |N/A                      |Bytes left to load + 255 in X/A (L/H)|
|tload_bin2dec    |$09	                     |number in A              |Decimal digits in Y/X/A (L/M/H)      |
|tload_pr2time    |$0c	                     |number in X/A            |"Number of secs left" in A           |
|tload_bin2t      |$0f                       |number in A              |time in Y/X/A (sec/10sec/min)        |

Notes:

* `tload_getprogress` returns 0 until data loading would have been started.
* `tload_pr2time` scales the 16-bit number supplied in X/A by an 8-bit constant calculated at assembly time, to yield, if supplied the number of bytes left to load, roughly the _number of seconds left_ from loading the data block.
* to keep memory footprint small, neither routine uses tables to implement multiplication and division (...there's likely a faster method out there to produce the values, at the expense of using more memory).

See [tloadtest.asm](tloadtest.asm) code (especially after the `.rloop` label) and try loading the `tloadtest.tap` build to get an idea.

## How to create tape master recordings

Once the binary pieces of your product become ready, creating a master recording can be done in a matter of running [tmaster.py](tmaster.py) with the related (long...) parameter list.

Things to know / experiment with:

* aesthetic properties (bootstrap with open / closed screen, method of border striping etc., see [Bootstrap options](#bootstrap-options) ) .
* method of bootstrap autostart (fixed address or run) and init (or, lack of any).
* filenames used by the prod / the loader. (tmaster.py obviously needs to know the filenames of the pieces that tload, embedded into your product's code, will attempt to find and load later on.)
* target recording file type. (To upload your prod to online sites, .tap should be perfect. For cassette duplicator facilities, you'll likely need to supply a .wav file.)
* if you're planning to produce physical recordings, the recorder signal chain's input polarity. (Commodore's tape recordings are, unfortunately, not agnostic to polarity. Polarity absolutely needs to match.)

Hint: for most cases, you'll likely want to create a custom wrapper shell script to run tmaster.py and include your parameter list, to keep track of every flag, filename, target filename etc. used.

## Technical data and additional notes

### Custom tape format

From V0.2.0 on, T-utils, by default, uses PLE (Pulse Length Encoding) to record data. PLE is the general recording method used by stock Commodore Kernal tape I/O routines (well... sort of...) and third-party custom loaders. Data bits in PLE are denoted by the length (time) of subsequent signal pulses.

Default / nominal timing T for tload's custom data recording is $70 cycles. The recording strictly employs symmetric pulses. Pulses, similarly to the Kernal's recording format, extend from falling edges to falling edges. (*"Full-wave" tap files can be used to store the recordings.)

Bytes are stored sequentially, MSB first.


|Bit	|denoted by       |
|-------|-----------------|
|0	|2T low, 2T high  |
|1	| T low,  T high  |

As per a roughly even distribution of 0 and 1 bits of compressed data payloads, average nominal data rate is 17734470/20/T/3, a.k.a. **2639bps**, a.k.a. **~330 bytes per second**.

Data is stored in a unified block format (which applies to bootstrap data blocks and standalone files).


|Name         |Data                   |Note                                                   |
|-------------|-----------------------|-------------------------------------------------------|
|Lead-in      |$0500 bytes of $ff     |							      |
|Lead-in end  |$fe, $ee               |Signs the lead-in's end, header's start                |
|File type    |one byte               |0 --> bootstrap block, 1 --> standalone file           |
|Filename     |16 bytes               |absent from bootstrap                                  |
|Start address|2 bytes                |absent from bootstrap                                  |
|End address  |2 bytes                |absent from bootstrap                                  |
|Data payload |End-Start bytes of data|                                                       |
|Checksum     |2 bytes                |Mod-255 Fletcher-16 (end-around-carry variant)         |
|Lead-out     |$0100 bytes of $ff     |                                                       |

Note: as you can see, there's *technically* a file header defined and used. However, file header and data payload are physically within one continuous unit. There's no gap (no lead-out, gap, lead-in) between header and data.

A word of note about the Fletcher-16 checksum. The type was chosen out of its better error detection properties (generally considered on-par with CRC-8) than that of the xor checksum, while still maintaining modest computational requirements. The one implemented here is the one's complement addition-based variant (the cheapest one to implement on 6502), which implies that initial sum1 = sum2 = 255.


### tload

Tload uses Timer 2 and hooks to the CPU IRQ vector to track and decode the tape data stream.

By tricks employed in the IRQ routine code, it's ensured that

* user code running in the background is never blocked for more than $270-some timer cycles (not even when there's no incoming tape signal)
* pulse length quantisation margin is symmetric ±T, a.k.a. nominal ±$70 / ±112 a.k.a. a whole 224 timer cycles.
* quantisation error imposed by the open screen is ± *1* TED badline time

(On the downside, the IRQ routine obviously employs a *lot* of busy waiting.)

Also:

* Tload uses the measurement result provided by the polling loader to set up the actual quantisation threshold.
* Tload's version string is embedded into the tload binary blob right after the leading jump table, starting from offset `$15`.
* There's no separate PAL and NTSC code. Tload in fact doesn't care whether it is running on a PAL or NTSC (or PAL-N) machine. (Signal speed variations, for the most part, are caused by datassette motor speed variations anyway).


#### tload state machine states

Tload's state machine currently implements the following "external" state identifiers (as exported in `tstat_e` a.k.a `$d0` by default):

```
; tstat_e
;00	waiting for play to be pressed
;01	searching
;02	found, loading
;03	ready (ST=0 success, ST<$80 pending restart, ST=$80+ fail)
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

Tsave also contains code to be able to record a custom Kernal tape format bootstrap, plus, the custom turbo format. It also obviously embeds the polling mode turbo loader code.

### tmaster.py

The utility was written by [Claude Code](https://claude.com/product/claude-code) in Python, following [specs](tmaster.spec) written by me. For any technical questions, these specs should be the source of truth.

[build.sh](build.sh) is (amongst other things) used to patch the [tmaster.py](tmaster.py) file, for it to always have the latest bootstrap loader binary code and patch address offset lists.

## GCR Mode

T-utils had originally employed [GCR](https://en.wikipedia.org/wiki/Group_coded_recording#Commodore) encoding to record data. As it turned out later, this recording failed to survive at least one particular analogue duplication facility. So, the method was dropped, and a conservative approach was taken (PLE recording mode was implemented) to remedy the situation.

GCR is fully retained in the code base (see: conditional assembly), but is not built by default. Its use is discouraged. You can still build a GCR mode toolset if you want by setting up a custom `tutilscfg.inc`, and running `build.sh`.

Nominal bit timing T is 192 single clock cycles in GCR mode, which (in PAL) makes a constant data rate of ~4618 raw bits, a.k.a. ~924 GCR nybbles, a.k.a. ~462 decoded bytes per second (while employing much lower frequency components than that of PLE). OTOH, data quantisation margin is ±T/2 a.k.a. ±96 timer cycles, a bit worse than that of PLE.

GCR encoding by design won't yield symmetric signal pulses, and from that point on, timing precision gets hampered by less than optimal (low, high) frequency and phase characteristics. GCR recordings also need to be stored in "half-wave" .tap files, accordingly.

The format uses `$1f` GCR nybbles for Lead-in and Lead-out (rather than bytes `$ff`), and three subsequent `$1e` nybbles (rather than bytes `$fe $ee`) to signal Lead-in end. Otherwise, on top of low-level GCR encoding, PLE's exact same block format applies.

The GCR IRQ loader runs off Timer 1 (rather than Timer 2). The code uses constant-rate sampling to read data, and implements a circular buffer to decouple real-time sampling from actual data processing. Sampling happens at the horizontal line rate (57 single clock cycles). Due to the way the sampling code is implemented (timing is very tight, especially around the TED's blocking DMAs), the screen must not be blanked, and the vertical scroll bits must not be tampered with, while the GCR IRQ loader is running.

The GCR loader code is larger than the PLE one. By default, it's assembled to run from $f800. Moreover, GCR decoding employs precalculated tables, which means that the code needs an additional 1K of BSS space to run (located at $f400 and on), and the tables need to be initialised by calling `tload_init` prior to calling `tload_start`. The tables can be discarded after concluding data loading processes. (See: the [jump/entry table](#how-to-use-tload-to-load-files) is shifted by one entry in GCR mode, with `tload_init` becoming the first one.)

Loading works on both PAL and NTSC machines.

The GCR polling loader code also measures (and stores) a parameter of the datassette comparator's asymmetry. (As it turned out, some datassettes happen to exhibit very asymmetric low-to-high vs. high-to-low comparator characteristics. Given the asymmetric nature of the GCR signal, datassette asymmetry became a relevant parameter for GCR decoding.)

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
The apparent magic involving the environment variables lets the container run the build with your own user and group IDs (so that files would be created with the right ownership). The volume mount part mounts your current directory as the working directory in the container.

The `[args]` part is simply passed on to [build.sh](build.sh).

The special argument of `sh` skips running the build script, and drops you into a shell within the build container.

## Releases

See [Releases](../../releases).

## To do

* implement missing features in tsave
* write native tmaster utility

(Neither looks very important TBH.)

Success stories, bug reports etc. are always welcome.

## Thanks and Acknowledgements

* Csaba Pankaczy

The development of t-utils was triggered by Csaba's idea of ​​making an official tape release of [Death Sector](https://plus4world.powweb.com/software/Death_Sector). Its evolution was tightly related to the game's release process, ideas, testing, disappointments, new ideas,... all that.

## Licence

Files in this package are distributed under the Zlib License (see: [LICENSE](LICENSE)), (C) 2024-2026 Levente Hársfalvi
