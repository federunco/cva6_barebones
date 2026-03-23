# Copyright 2026 Federico Runco (federico.runco@gmail.com)
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# 
# Licensed under the Solderpad Hardware License v2.1 (the “License”); 
# you may not use this file except in compliance with the License, or, 
# at your option, the Apache License version 2.0. You may obtain a copy 
# of the License at https://solderpad.org/licenses/SHL-2.1/
# 
# Unless required by applicable law or agreed to in writing, any work 
# distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
# License for the specific language governing permissions and limitations 
# under the License.

BASE_HEADER := "[SoC MAKEFILE]"
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SW_DIR := $(ROOT_DIR)/sw
SIM_OUT_BASE := $(ROOT_DIR)/verif/out

VERIF_DIR := $(ROOT_DIR)/verif
BENDER := bender
VERILATOR := verilator
TARGET_CVA6_ISA := cv64a6_imafdc_sv39
VERILATED_TB := tb_boot_exe
PROGRAM ?= not_set
TIMEOUT ?= 500000
RI_PATH = $(shell $(BENDER) path register_interface)
REGGEN = $(RI_PATH)/vendor/lowrisc_opentitan/util/regtool.py


SIM_OUT_DIR := $(VERIF_DIR)/out/run-$(shell date +%Y-%m-%d)-$(PROGRAM)

PROGRAM_DIR := $(ROOT_DIR)/sw/$(PROGRAM)
PROGRAM_MAKEFILE := $(PROGRAM_DIR)/Makefile
MEMHEX := $(SIM_OUT_DIR)/program.hex

FLIST := $(VERIF_DIR)/soc.flist
SIM_BIN := $(VERIF_DIR)/build/$(VERILATED_TB)

.PHONY: getdeps build-program verilate run clean

getdeps: Bender.yml
	$(BENDER) update

hw/uart/reg:
	mkdir -p hw/uart/reg
	python3 $(REGGEN) -r -t ./hw/uart/reg ./hw/uart/uart.hjson 

peripherals: hw/uart/reg	

build-program:
	@if [ ! -f "$(PROGRAM_MAKEFILE)" ]; then \
		echo "$(BASE_HEADER) Unknown test '$(PROGRAM)' (no Makefile in sw/$(PROGRAM))"; \
		exit 1; \
	fi
	@echo $(BASE_HEADER) Building program $(PROGRAM)
	$(MAKE) -C "$(PROGRAM_DIR)"	

verilate: peripherals
	@echo $(BASE_HEADER) Compiling the design
	$(BENDER) script flist-plus -t $(TARGET_CVA6_ISA) -t soc_verilate > tmp.flist
	# HPDCache does not compile, TODO: investigate, not used by the selected ISA, can be removed from flist
	grep -v "hpdcache" tmp.flist > "$(FLIST)"
	rm tmp.flist

	# --trace-fst
	# --trace-structs 

	$(VERILATOR) \
		--sv \
		--timing \
		--bbox-unsup \
		-Wno-TIMESCALEMOD \
		-Wno-fatal \
		--binary \
		-O3 \
		--threads 4 \
		-j 4 \
		--top-module tb_boot \
		-F "$(FLIST)" \
		-Mdir "$(VERIF_DIR)/build" \
		-o $(VERILATED_TB)

run: build-program verilate
	mkdir -p $(SIM_OUT_BASE)
	mkdir -p $(SIM_OUT_DIR)
	@echo $(BASE_HEADER) Copying build artifacts in output directory
	@elf_file="$$(find "$(PROGRAM_DIR)" -maxdepth 2 -type f -name '*.elf' | head -n 1)"; \
	hex_file="$$(find "$(PROGRAM_DIR)" -maxdepth 2 -type f -name '*.hex' | head -n 1)"; \
	cp "$$elf_file" "$(SIM_OUT_DIR)/program.elf"; \
	cp "$$hex_file" "$(MEMHEX)";
	@echo $(BASE_HEADER) Copied $$elf_file in $(SIM_OUT_DIR)/program.elf
	@echo $(BASE_HEADER) Copied $$hex_file in $(MEMHEX)
	@echo $(BASE_HEADER) Starting simulation
	"$(SIM_BIN)" +memhex="$(MEMHEX)" +timeout=$(TIMEOUT) | tee $(SIM_OUT_DIR)/output.txt
	mv $(ROOT_DIR)/trace_hart_0.dasm $(SIM_OUT_DIR)/trace_hart_0.dasm 
	@echo $(BASE_HEADER) SoC simulation terminated
	@echo $(BASE_HEADER) Results transcripts and artifacts available at $(SIM_OUT_DIR)

clean:
	@for dir in "$(SW_DIR)"/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir" clean; \
		fi; \
	done
	rm -rf "$(SIM_OUT_BASE)"
	rm -rf "$(VERIF_DIR)/build"
	rm -f "$(FLIST_RAW)" "$(FLIST)"
	rm -rf hw/uart/reg

