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
	int unsigned timeout;
	int unsigned ram_boot;
	int unsigned cycle_count;
	int unsigned gpr_idx;
	logic [1:0] uart_tick;

	task automatic dump_core;
		$display("[SoC TESTBENCH] ===== CORE DUMP @ cycle %0d =====", cycle_count);
		for (gpr_idx = 0; gpr_idx < 32; gpr_idx += 4) begin
			$display("[SoC TESTBENCH] x%-2d = 0x%016h x%-2d = 0x%016h x%-2d = 0x%016h x%-2d = 0x%016h",
				gpr_idx,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx],
				gpr_idx + 1,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 1],
				gpr_idx + 2,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 2],
				gpr_idx + 3,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 3]
			);
		end
		$display("[SoC TESTBENCH] pc = 0x%016h", dut.i_cva6.pc_id_ex);
		$write("[SoC TESTBENCH] =================================");
	endtask

	cva6_barebones dut (
		.clk_i (clk_i),
		.rst_ni (rst_ni)
	);

	initial begin
		clk_i = 1'b0;
		uart_tick <= '0;
		forever #(CLK_PERIOD/2) clk_i = ~clk_i;
	end

	initial begin
		rst_ni = 1'b0;
		cycle_count = 0;

		$dumpfile("tb_boot.vcd");
		$dumpvars(0);

		if (!$value$plusargs("memhex=%s", mem_hex)) begin
			$fatal(1, "Missing +memhex=<path-to-program.hex>");
		end

		if (!$value$plusargs("timeout=%d", timeout)) begin
			$fatal(1, "Missing +timeout=<timeout-in-cycles>");
		end

		if (!$value$plusargs("ramboot=%d", ram_boot)) begin
			$fatal(1, "Missing +ramboot=<skip-bootrom>");
		end

		if (ram_boot == 1) begin
			force dut.i_cva6.boot_addr_i = 64'h8000_0000;
			$display("[SoC TESTBENCH] Selected boot from RAM");
		end else begin
			$display("[SoC TESTBENCH] Selected boot from BootROM");
		end

		$display("[SoC TESTBENCH] Loading SRAM image from %s", mem_hex);
		$readmemh(mem_hex, dut.i_sram.mem);

		repeat (10) @(posedge clk_i);
		rst_ni = 1'b1;
		$display("[SoC TESTBENCH] rst_ni released");
	end

	always @(posedge clk_i) begin
		if (!rst_ni) begin
			cycle_count <= 0;
		end else begin
			cycle_count <= cycle_count + 1;
			uart_tick <= {uart_tick[0], dut.i_uart.tick};

			if (dut.i_sram.mem[SIG_WORD_IDX] == SIG_VALUE) begin
				$display("\n[SoC TESTBENCH] Signature detected at cycle %0d", cycle_count);
				dump_core();
				if (dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[15] != '0) begin
					$display("[SoC TESTBENCH] FAIL: main returned a non zero value. Check core dump for more details");
					$fatal(1, "main returned a non zero value");
				end
					
				$display("\n[SoC TESTBENCH] PASS: main returned 0");
				$finish;
			end

			if (cycle_count > timeout) begin
				$display("\n[SoC TESTBENCH] Cycles timeout");
				dump_core();
				$display("[SoC TESTBENCH] FAIL: Signature was not written before simulation timeout");
				$fatal(1, "signature not written");
			end

			if (dut.i_uart.i_tx.state == uart_pkg::START_BIT && uart_tick[1]) 
				$write("%c", dut.i_uart.txd);
		end
	end
endmodule