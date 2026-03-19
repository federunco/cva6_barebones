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

import uart_pkg::*;

module uart_tx (
	input	logic 		clk_i,
	input	logic 		rst_ni,

	input	logic 		tick_i,
	input	logic 		tx_i,
	input	logic[7:0] 	txd_i,

	output	logic 		tx_o,
	output	logic 		busy_o
);

uart_state_t state;
wire sel_bit;

always_ff @(posedge clk_i) begin
	if (!rst_ni) 
		state <= IDLE;
	else if (tick_i) begin
		case (state)
			IDLE: if (tx_i) state <= START_BIT;
			START_BIT: state <= B0;
			B0: state <= B1;
			B1: state <= B2;
			B2: state <= B3;
			B3: state <= B4;
			B4: state <= B5;
			B5: state <= B6;
			B6: state <= B7;
			B7: state <= STOP_BIT;
			STOP_BIT: state <= IDLE;
			default: state <= IDLE;
		endcase
	end
end

assign sel_bit = txd_i[state[2:0]];

always_comb begin
	if (state == IDLE) tx_o = 1'b1;
	else if (state == START_BIT) tx_o = 1'b0;
	else if (state == STOP_BIT) tx_o = 1'b1;
	else tx_o = sel_bit;
end
assign busy_o = state == IDLE ? 1'b0 : 1'b1;


endmodule