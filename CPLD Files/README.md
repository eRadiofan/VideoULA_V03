# VideoULA V03 – CPLD firmware

Firmware for the ATF1504AS-AU44 (V03 hardware). Current release: **V02/V03 Build 6**.

Note: firmware build numbers are independent of hardware versions and revisions. The
V01 firmware (Build 37) and the V02/V03 firmware (Build 6) use separate numbering.

## Files

| File | Purpose |
|---|---|
| `src/VideoULA.v` | Verilog source (common V02/V03 code) |
| `VideoULA.qsf` | Quartus settings and pin assignments |
| `VideoULA.qpf` | Quartus project file |
| `VideoULA.sdc` | Timing constraints (auto-detected from the project root) |

Keep this layout. The `.qsf` refers to `src/VideoULA.v` by relative path.

## Toolchain

The tools and commands below are for a **Windows** build environment.

- Altera Quartus II 13.0 SP1 Web Edition:
  https://www.altera.com/downloads/fpga-development-tools/quartus-ii-web-edition-design-software-version-13-0sp1-windows
- Atmel POF2JED: https://www.microchip.com/en-us/development-tool/pof2jed
- fuseconv (part of prjbureau): https://github.com/whitequark/prjbureau
- OpenOCD (xPack): https://github.com/xpack-dev-tools/openocd-xpack/releases
- Device: EPM7064STC44-10 (used as the closest match for the ATF1504AS; the
  output is converted for the ATF1504AS in step 2 below)

## Choosing the 16MHz or 48MHz build

Near the top of `src/VideoULA.v`, enable exactly one of:

    `define CLK_48MHZ
    //`define CLK_16MHZ

For the 16MHz build, swap the comment markers so `CLK_16MHZ` is active and
`CLK_48MHZ` is commented out. Do not enable both.

The 48MHz build is recommended. The 16MHz build is a fallback for machines where
the CPLD's clocks must stay locked to the motherboard's own 16MHz. It does not need
the 48MHz oscillator. The CPLD `CLK_6M` output is generated from the 16MHz clock and can
be used with the 6MHz interface boards, but it has a small fixed jitter (about 10ns), so
the picture on mode 7 test screens such as M7CALIB is slightly noisier than in the 48MHz
build. If `CLK_6M` is not connected, the motherboard's own 6MHz is used.

## SRAM write timing

Palette writes to the SRAM use three cycles: capture the address, drive the address with
nWE high, then pull nWE low. Near the top of `src/VideoULA.v` there is an optional define
that chooses which three cycles of the 8-cycle counter are used:

    //`define SRAM_WRITE_LATE

- **Default (define commented out):** cycles 1, 2 and 3.
- **`SRAM_WRITE_LATE` defined:** cycles 2, 3 and 4. The ULA control register write also moves
  one cycle later.

Both give the SRAM a full cycle of address setup before nWE falls, and both use the same
number of macrocells. The default is recommended.

## Programming the ATF1504AS

In the commands below, `<project>` is your Quartus project folder.

### Step 1 – Create the .pof file in Quartus

1. Install Quartus II 13.0 SP1 (link above) and open the project.
2. The project uses the four files from the Files section above: `src\VideoULA.v`,
   `VideoULA.qpf`, `VideoULA.qsf` and `VideoULA.sdc`. Open `VideoULA.qpf` in Quartus.
3. Compile and check for errors.

This creates `<project>\output_files\VideoULA.pof`.

### Step 2 – Convert .pof to .jed with Atmel POF2JED

1. Download and install Atmel POF2JED (link above).
2. Input file: `<project>\output_files\VideoULA.pof`
3. Device: `1504AS`
4. Output file: `<project>\output_files\VideoULA.jed`

### Step 3 – Convert .jed to .svf with fuseconv

1. Install Python 3 and make sure it is on your PATH.
2. Download the prjbureau tools (link above) and extract them (for example to
   `C:\prjbureau-main`).
3. Run:

        cd C:\prjbureau-main
        python -m util.fuseconv -d ATF1504AS <project>\output_files\VideoULA.jed <project>\output_files\VideoULA.svf

This will likely fail with an error ending similar to:

    util.jesd3.JESD3ParsingError: unrecognized field at line 795, column 2 (b'*\n\nNOTE  device '...)

The POF2JED output has a stray line containing only `*`. Open the `.jed` file
in a text editor, go to the line reported, and either delete the line that
contains only `*` or put `NOTE` in front of the `*`. Save the file and run the
command again.

### Step 4 – Program the CPLD with OpenOCD

1. Download OpenOCD for Windows (link above) and extract it
   (for example to `C:\OpenOCD`).
2. Run:

        cd <project>\output_files
        C:\OpenOCD\bin\openocd -d2 -f interface/altera-usb-blaster.cfg -c "adapter speed 400" -c "transport select jtag" -c "jtag newtap ATF1504AS tap -irlen 3 -expected-id 0x0150403f" -c "init" -c "svf VideoULA.svf" -c "sleep 200" -c "shutdown"

A successful run ends with a message similar to
`svf file programmed successfully for NNNN commands with 0 errors`.

The CPLD needs the 12V programming voltage on its programming pin during
programming. See the programmer board section in the main README.

## Status

V02/V03 Build 6 is tested on V03 hardware in both 16MHz and 48MHz modes.

### Build 6

Palette writes to the external SRAM now take two cycles: the address is driven first,
then nWE is pulled low, so the address is stable before the write. The data bus is only
driven during the nWE cycle. The address setup problem was identified by hoglet, who also
proposed a fix; it became apparent with the faster SRAM radiofan was using. radiofan's fix
(a slightly different approach with the same result) is used here.

In the 16MHz build, `CLK_6M` is now generated from `CLK_16M`, so the 48MHz oscillator is
not needed in that build. The macrocell count is 52/64 (48MHz build) and 50/64 (16MHz build).

### Cursor position

Modes 0-6 use no cursor delay (`cursor_invert0`); mode 7 uses a one-stage delay
(`cursor_invert[0]`, 62.5ns). Both paths cannot use zero delay together, because the
design then fails to route in Quartus.

The mode 7 cursor was checked on a Master and a Model B, in both the 16MHz and 48MHz
builds, with the 6MHz derived on the motherboard, and in the 48MHz build with the 6MHz
generated by the CPLD. The cursor is correctly aligned in all of these except a Master
using the motherboard 6MHz (in either build), where it may be marginally (less than
half a pixel) to the left.

For the cleanest mode 7 picture, use the CPLD `CLK_6M` output to drive the teletext IC
(preferably the 48MHz build, with the IC37 replacement board on a Model B or the IC25 replacement board on
a Master; see [6MHz Interface Boards](https://github.com/kgl2001/VideoULA_V01/tree/main/KiCAD%20Files/6MHz%20Interface%20Boards)). With the motherboard's own 6MHz circuit, or the CPLD 6MHz in the 16MHz build, the mode 7 picture
can show some noise on test screens such as M7CALIB.
