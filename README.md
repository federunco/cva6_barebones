# CVA6 Barebones
A simple hobby project to teach myself how to build a working SoC based on the CVA6 core.

## Dependencies
- Python 3
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
make run PROGRAM=hello_world
```
Tests results are available on both console output and ```verif/out``` directory.

## Writing Custom Programs
Place your program in the `sw` directory. Use the Hello World example `Makefile` as a reference for how to build it. Then run the `run` target from the top-level `Makefile`, passing your selected program as an argument.

## Roadmap
- [x] Basic core + SRAM instantiation
- [x] Testbench and custom program execution
- [ ] AXI UART device + testbench `printf` output over UART
- [ ] Boot ROM (UART upload)
- [ ] FPGA synthesis
- [ ] Better documentation

## Licensing
The SoC is released under the Solderpad Hardware License version 2.1, which is a permissive license based on Apache 2.0. Please refer to the Solderpad license file for more information.

The OpenHW Group CVA6 core, vendored through Bender, is released under the Solderpad Hardware License version 0.51. Please refer to the original repository for more information.

The PULP Platform AXI modules, vendored through Bender, are released under the Solderpad Hardware License version 0.51. Please refer to the original repository for more information.

The PULP Platform `axi2mem` unit, vendored in `vendor/axi2mem.sv`, is released under the Solderpad Hardware License version 0.51. Please refer to the original repository for more information.