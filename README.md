# CVA6 Barebones
A simple hobby project to teach myself how to build a working SoC based on the CVA6 core.

## Dependencies
- Python 3 with hjson, mako, tabulate, pyserial, pyelftools and tqdm dependencies
- Bender
- RISC-V toolchain
- Verilator

## Quick Start
For the initial setup, fetch the Bender dependencies:
```
make getdeps
```

To run the Hello World test:
```
make run PROGRAM=hello_world TIMEOUT=10000
```
Tests results are available on both console output and `verif/out` directory.
Expected output from the simulation is the following:
```
[UART-DPI] Virtual UART ready: /dev/ttys000 -> ./uart0
[SoC TESTBENCH] Boot from RAM, loading /Users/federunco/cva6_barebones/verif/out/run-2026-10-14-hello_world/program.hex (entry 0x0000000080000000)
[SoC TESTBENCH] rst_ni released
Hello, world!
[SoC TESTBENCH] Signature detected at cycle 8169
[SoC TESTBENCH] ===== CORE DUMP @ cycle 8169 =====
[SoC TESTBENCH] x0  = 0x0000000000000000    x1  = 0x000000008000000c    x2  = 0x0000000080010000    x3  = 0x0000000000000000
[SoC TESTBENCH] x4  = 0x0000000000000000    x5  = 0x0000000080001000    x6  = 0xdeadbeefcafebabe    x7  = 0x0000000000000000
[SoC TESTBENCH] x8  = 0x0000000000000000    x9  = 0x0000000000000000    x10 = 0x0000000000000000    x11 = 0x0000000000000000
[SoC TESTBENCH] x12 = 0x000000008000fbf8    x13 = 0x0000000000000000    x14 = 0x0000000000000000    x15 = 0x0000000000000000
[SoC TESTBENCH] x16 = 0x0000000000000008    x17 = 0x0000000000000000    x18 = 0x0000000000000000    x19 = 0x0000000000000000
[SoC TESTBENCH] x20 = 0x0000000000000000    x21 = 0x0000000000000000    x22 = 0x0000000000000000    x23 = 0x0000000000000000
[SoC TESTBENCH] x24 = 0x0000000000000000    x25 = 0x0000000000000000    x26 = 0x0000000000000000    x27 = 0x0000000000000000
[SoC TESTBENCH] x28 = 0xffffffffffff0208    x29 = 0x000000008000fbc0    x30 = 0x000000008000fbf0    x31 = 0x0000000000000000
[SoC TESTBENCH] commit pc = 0x0000000080000032
[SoC TESTBENCH] =================================
[SoC TESTBENCH] PASS: main returned 0
```

## Writing Custom Programs
Place your program in the `sw` directory. Use the Hello World example `Makefile` as a reference for how to build it. Then run the `run` target from the top-level `Makefile`, passing your selected program as an argument.

Simulations using the UART with realistic baud rates are computationally expensive. To improve simulation performance, configure the UART divider to a high value (up to CLK_FREQ/16).

## FPGA Synthesis
To synthesize the SoC, run:

```bash
make fpga BOARD=zynq7020db
```

This command generates a valid bitstream and build artifacts under `fpga/out/run-YYYY-MM-DD` for a generic Zynq-7020 development board.  
Currently, only Vivado is supported.

To add support for a new board:

1. Add a new board entry in `fpga/targets.mk`.
2. Define the target clock frequency, UART baud rate, and XDC constraints filename.
3. Add the corresponding XDC file to `fpga/constraints`.

Use the existing target as the reference implementation.

## Uploading a Program

Compile your program first. Then upload it with `upload.py`:

```bash
python utils/upload.py --elf sw/hello_world/build/hello.elf --port /dev/cu.usbserial-1310
```

The script waits for the Boot ROM, uploads the ELF, and then streams the program output. 

Expected output is similar to the following:
```
Detected entrypoint: 0x80000000, 1 segments
Waiting for BootROM (rst core to trigger)...
Sending handshake...
Waiting for response...
Upload started...
  -> Segment 0 loaded (44144 bytes sent)                                                                                                                                                                                                                                                               
Upload: 100%|███████████████| 43.1k/43.1k [01:36<00:00, 456B/s]
Upload complete, 44176 bytes sent.
Waiting for core to jump to RAM...
Program output:
----------------------------------------

Hello, world!

----------------------------------------
```

# Licensing
Copyright 2026 (c) Federico Runco

The SoC is released under the Solderpad Hardware License version 2.1, which is a permissive license based on Apache 2.0. Please refer to the Solderpad license file for more information.

## Dependencies
The table below summarizes the main third-party dependencies and their corresponding licenses.
| Dependency | Version | License | 
|-|-|-|
| [cva6](https://github.com/openhwgroup/cva6) | upstream | SPHL v0.51 
| [axi](https://github.com/pulp-platform/axi) | 0.31.1 | SPHL v0.51 
| [register_interface](https://github.com/pulp-platform/register_interface) | 0.4.1 | SPHL v0.51 
| [axi2mem](https://github.com/pulp-platform/axi2mem/blob/master/axi2mem.sv) | upstream | SPHL v0.51 