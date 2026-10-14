// Copyright 2026 Federico Runco (federico.runco@gmail.com)
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Solderpad Hardware License v2.1 (the “License”); 
// you may not use this file except in compliance with the License, or, 
// at your option, the Apache License version 2.0. You may obtain a copy 
// of the License at https://solderpad.org/licenses/SHL-2.1/
// 
// Unless required by applicable law or agreed to in writing, any work 
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
// License for the specific language governing permissions and limitations 
// under the License.

#define BOOTROM
#include <stdint.h>
#include "uart.h"
#include "encoding.h"

#define TIMEOUT         1

#ifdef SYNTHESIS
#define UART_DIVIDER    (CLK_FREQ / 16 / BAUDRATE) - 1 
#else
#define UART_DIVIDER    1
#define CLK_FREQ        10000
#endif

static inline uint8_t uart_getc(void) {
    uint8_t c;
    while (!uart_read(&c));
    return c;
}

uint32_t get_incoming_32b(void) {
    uint32_t res = 0;
    for (int i = 0; i < 4; i++) {
        res |= ((uint32_t)uart_getc()) << (i * 8);
    }
    return res;
}

uintptr_t get_incoming_ptr(void) {
    uintptr_t res = 0;
    for (unsigned int i = 0; i < sizeof(uintptr_t); i++) {
        res |= ((uintptr_t)uart_getc()) << (i * 8);
    }
    return res;
}

void main(void) {
    uint32_t signature = 0;
    uint8_t tmp;
    uintptr_t entry_point = 0x80000000UL;

    set_uart_div(UART_DIVIDER);
    print_uart("BOOTRDY\n");

    clear_csr(mcountinhibit, 1);
    write_csr(mcycle, 0);

    while (CLK_FREQ * TIMEOUT > read_csr(mcycle)) {
        if (uart_read(&tmp)) {
            signature = (signature >> 8) | ((uint32_t)tmp << 24);
            if (signature == 0xB007BABE) break;
        }
    }

    if (signature == 0xB007BABE) {
        entry_point = get_incoming_ptr();
        uint32_t num_segments = get_incoming_32b();

        print_uart("UPLDRDY");

        for (uint32_t s = 0; s < num_segments; s++) {
            uint8_t *dst    = (uint8_t *)get_incoming_ptr();
            uint32_t filesz = get_incoming_32b();
            uint32_t memsz  = get_incoming_32b();

            // Write initialized bytes from UART
            for (uint32_t i = 0; i < filesz; i++) {
                dst[i] = uart_getc();
            }

            // Zero out remaining .bss memory
            for (uint32_t i = filesz; i < memsz; i++) {
                dst[i] = 0;
            }

            // Acknowledge segment completion (prevents UART RX overrun during .bss zeroing)
            print_uart(".");
        }
    }

    print_uart("JMP\n");

    __asm__ volatile (
        "fence.i\n\t"
        "jr %0\n\t"
        :
        : "r"(entry_point)
        : "memory"
    );
}