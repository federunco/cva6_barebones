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

BUILD_PREFIX := hello
ROOT_DIR := $(abspath $(CURDIR)/../..)
BUILD_DIR := ./build

SRC := main.c

ELF := $(BUILD_DIR)/$(BUILD_PREFIX).elf

TOOLCHAIN_PREFIX := riscv64-unknown-elf
CC := $(TOOLCHAIN_PREFIX)-gcc

LDSCRIPT := $(ROOT_DIR)/sw/common/link.ld
CRT := $(ROOT_DIR)/sw/common/crt.s

CFLAGS := \
	-nostartfiles \
	-ffreestanding \
	-I../common \
	-march=rv64imac_zicsr_zifencei \
	-mabi=lp64 \
	-mcmodel=medany

LDFLAGS := \
	-T "$(LDSCRIPT)" \
	-Wl,--gc-sections \
	-Wl,--build-id=none

BASE_HEADER := "[SW COMPILE]"

.PHONY: all clean

all: $(ELF)

$(BUILD_DIR):
	mkdir -p "$@"

$(ELF): $(LDSCRIPT) $(CRT) $(SRC) | $(BUILD_DIR)
	@echo $(BASE_HEADER) Compiling $@
	"$(CC)" \
		$(CFLAGS) \
		"$(CRT)" \
		"$(SRC)" \
		$(LDFLAGS) \
		-o "$@"

clean:
	rm -rf "$(BUILD_DIR)"