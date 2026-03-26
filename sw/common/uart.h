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

#ifndef _SOC_UART_
#define _SOC_UART_

#ifndef BOOTROM
#include <stdint.h>
#endif

#define UART_BASE_ADDR 0x10000000

#define UART_DATA_REG_OFFSET 0x0
#define UART_CSREG_REG_OFFSET 0x8
#define UART_DIVIDER_REG_OFFSET 0x10
#define UART_CSREG_BUSY_BIT 0
#define UART_CSREG_START_BIT 1
#define UART_CSREG_VALID_BIT 2

static void write_reg_u8(uintptr_t addr, uint8_t value)
{
    volatile uint8_t *loc_addr = (volatile uint8_t *)addr;
    *loc_addr = value;
}

static void write_reg_u32(uintptr_t addr, uint32_t value)
{
    volatile uint32_t *loc_addr = (volatile uint32_t *)addr;
    *loc_addr = value;
}

static uint8_t read_reg_u8(uintptr_t addr)
{
    return *(volatile uint8_t *)addr;
}

static inline void uart_putchar(char c) {
	while ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1);
	write_reg_u8(UART_BASE_ADDR + UART_DATA_REG_OFFSET, (uint8_t) c);
	write_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET, 1 << UART_CSREG_START_BIT);
	while ( ! ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1 ));
	write_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET, 0 << UART_CSREG_START_BIT);
	while ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1);
}

static void print_uart(const char *str)
{
    const char *cur = &str[0];
    while (*cur != '\0')
    {
        uart_putchar((uint8_t)*cur);
        ++cur;
    }
}

static void set_uart_div (uint32_t div) {
	write_reg_u32(UART_BASE_ADDR + UART_DIVIDER_REG_OFFSET, div);
}

#ifndef BOOTROM
#define printf(...) do { \
        char text[1024]; \
        sprintf(text, __VA_ARGS__); \
        print_uart(text); \
} while (0)
#endif

#endif