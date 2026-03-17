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

`timescale 1ns/1ps

module tb_boot;
	localparam time CLK_PERIOD = 20ns;
	localparam logic [63:0] SIG_ADDR  = 64'h8000_1000;
	localparam logic [63:0] SIG_VALUE = 64'hDEAD_BEEF_CAFE_BABE;
	localparam int unsigned SIG_WORD_IDX = (SIG_ADDR - 64'h8000_0000) >> 3;

	logic clk_i;
	logic rst_ni;

	string mem_hex;
	int unsigned cycle_count;

	cva6_barebones dut (
		.clk_i (clk_i),
		.rst_ni (rst_ni)
	);

	initial begin
		clk_i = 1'b0;
		forever #(CLK_PERIOD/2) clk_i = ~clk_i;
	end

	initial begin
		rst_ni = 1'b0;
		cycle_count = 0;

		if (!$value$plusargs("memhex=%s", mem_hex)) begin
			$fatal(1, "Missing +memhex=<path-to-program.hex>");
		end

		$display("[SoC TESTBENCH] Loading SRAM image from %s", mem_hex);
		$readmemh(mem_hex, dut.i_sram.mem);

		$dumpfile("tb_boot.vcd");
		$dumpvars(0);

		repeat (10) @(posedge clk_i);
		rst_ni = 1'b1;
	end

	always @(posedge clk_i) begin
		if (!rst_ni) begin
			cycle_count <= 0;
		end else begin
			cycle_count <= cycle_count + 1;

			if (dut.i_sram.mem[SIG_WORD_IDX] == SIG_VALUE) begin
				$display("[SoC TESTBENCH] PASS: signature detected at cycle %0d", cycle_count);
				$finish;
			end

			if (cycle_count > 500000) begin
				$fatal(1, "[SoC TESTBENCH] FAIL: signature was not written, timeout");
			end
		end
	end
endmodule