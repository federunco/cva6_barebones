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

void main (){
	set_uart_div(5000000); //TODO: distinguish between simulation and RTL
	print_uart("CVA6 SoC First stage bootloader\n");
	print_uart("Send update cmd in 10 seconds to upload HEX data [TODO IMPL]\n");
	// TODO: implement update CMD 
	print_uart("Jumping to boot address\n");
	__asm__ volatile(
        "li t0, 0x80000000;"
        "jr t0"
	);
}