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

`define RF dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem

module soc_testharness;
	localparam time         CLK_PERIOD   = 20ns;
	localparam logic [63:0] RAM_BASE     = 64'h8000_0000;
	localparam logic [63:0] SIG_ADDR     = 64'h8000_1000;
	localparam logic [63:0] SIG_VALUE    = 64'hDEAD_BEEF_CAFE_BABE;
	localparam int unsigned SIG_WORD_IDX = (SIG_ADDR - RAM_BASE) >> 3;

	logic clk_i, rst_ni;
	logic soc_tx, soc_rx;

	string       mem_hex;
	int unsigned timeout;
	bit          skip_rom;
	logic [63:0] entry_addr;
	int unsigned cycle_count;
	logic        tx_start_q;

	cva6_barebones dut (
		.clk_i  (clk_i),
		.rst_ni (rst_ni),
		.rx_i   (soc_rx),
		.tx_o   (soc_tx)
	);

	sim_uart #(
		.divider(1)
	) i_romtx (
		.clk_i   (clk_i),
		.rst_ni  (rst_ni),
		.boot_en (!skip_rom),
		.tx_o    (soc_rx),
		.rx_i    (soc_tx)
	);

	initial clk_i = 1'b0;
	always #(CLK_PERIOD/2) clk_i = ~clk_i;

	function automatic string trap_name(input logic [3:0] code);
		case (code)
			4'd0:    return "Instruction address misaligned";
			4'd1:    return "Instruction access fault";
			4'd2:    return "Illegal instruction";
			4'd3:    return "Breakpoint (ebreak)";
			4'd4:    return "Load address misaligned";
			4'd5:    return "Load access fault";
			4'd6:    return "Store/AMO address misaligned";
			4'd7:    return "Store/AMO access fault";
			4'd8:    return "Environment call from U-mode";
			4'd9:    return "Environment call from S-mode";
			4'd11:   return "Environment call from M-mode";
			4'd12:   return "Instruction page fault";
			4'd13:   return "Load page fault";
			4'd15:   return "Store/AMO page fault";
			default: return $sformatf("Unknown exception (code=%0d)", code);
		endcase
	endfunction

	task automatic dump_core;
		$display("[SoC TESTBENCH] ===== CORE DUMP @ cycle %0d =====", cycle_count);
		for (int i = 0; i < 32; i++) begin
			if (i % 4 == 0)
				$write("[SoC TESTBENCH] ");
			$write("x%-2d = 0x%016h", i, `RF[i]);

			if (i % 4 == 3)
				$write("\n");
			else
				$write("    ");
		end
		$display("[SoC TESTBENCH] commit pc = 0x%016h", dut.i_cva6.pc_commit);
		$display("[SoC TESTBENCH] =================================");
	endtask

	// Dump the core, print the reason and stop the simulation with an error
	task automatic fail(input string why);
		dump_core();
		$display("[SoC TESTBENCH] FAIL: %s", why);
		$fatal(1, "%s", why);
	endtask

	initial begin
		rst_ni      = 1'b0;

		if ($test$plusargs("trace")) begin
			$dumpfile("tb_boot.vcd");
			$dumpvars(0);
		end

		if (!$value$plusargs("timeout=%d", timeout)) timeout    = 2_000_000;
		if (!$value$plusargs("entry=%h",   entry_addr)) entry_addr = RAM_BASE;

		skip_rom = $value$plusargs("memhex=%s", mem_hex);

		if (skip_rom) begin
			$display("[SoC TESTBENCH] Boot from RAM, loading %s (entry 0x%h)", mem_hex, entry_addr);
			force dut.i_cva6.boot_addr_i = entry_addr;
			$readmemh(mem_hex, dut.i_sram.mem);
		end else begin
			$display("[SoC TESTBENCH] Boot from BootROM");
		end

		repeat (10) @(posedge clk_i);
		rst_ni = 1'b1;
		$display("[SoC TESTBENCH] rst_ni released");
	end

	always @(posedge clk_i) begin
		if (!rst_ni) begin
			cycle_count <= 0;
			tx_start_q  <= 1'b0;
		end else begin
			cycle_count <= cycle_count + 1;
			tx_start_q  <= dut.i_uart.start;

			// Console: print every byte the SoC UART starts to send
			if (dut.i_uart.start && !tx_start_q && skip_rom)
				$write("%c", dut.i_uart.txd);

			// Test finished: signature written by the program
			if (dut.i_sram.mem[SIG_WORD_IDX] == SIG_VALUE) begin
				$display("\n[SoC TESTBENCH] Signature detected at cycle %0d", cycle_count);
				if (`RF[10] != '0) fail("main returned a non zero value");
				dump_core();
				$display("[SoC TESTBENCH] PASS: main returned 0");
				$finish;
			end

			// Unexpected trap
			if (dut.i_cva6.csr_regfile_i.mcause_q != '0) begin
				$display("\n[SoC TESTBENCH] Unexpected trap: %s", trap_name(dut.i_cva6.csr_regfile_i.mcause_q[3:0]));
				$display("[SoC TESTBENCH] mepc  = 0x%016h", dut.i_cva6.csr_regfile_i.mepc_q);
				$display("[SoC TESTBENCH] mtval = 0x%016h", dut.i_cva6.csr_regfile_i.mtval_q);
				fail("exception caught");
			end

			if (cycle_count > timeout)
				fail("signature not written before timeout");
		end
	end
endmodule

`undef RF