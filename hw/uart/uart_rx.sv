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

module uart_rx (
	input	logic 		clk_i,
	input	logic 		rst_ni,

	input	logic 		tick_i,
	input	logic 		rx_i,

	output	logic 		valid_o,
	output	logic[7:0]	rxd_o
);

logic [1:0] rx_sync, rx_cnt;
logic [2:0] sample_cnt;
logic [7:0] data;

logic rx;
logic sample;

uart_state_t state;

// Two flops synchronizer
always_ff @(posedge clk_i) begin
	if (!rst_ni) rx_sync <= '1;
	else rx_sync <= {rx_sync[0], rx_i};
end

// Simple filter
always_ff @(posedge clk_i) begin
	if (!rst_ni) begin
		rx_cnt <= '0;
		rx <= 1'b1;
	end else begin
		if (rx_sync[1] && rx_cnt != 2'b11) rx_cnt <= rx_cnt + 1;
		else if (!rx_sync[1] && rx_cnt != 2'b00) rx_cnt <= rx_cnt - 1;

		if (rx_cnt == 2'b00) rx <= 0;
		else if (rx_cnt == 2'b11) rx <= 1;
	end
end

always_ff @(posedge clk_i) begin
	if (!rst_ni) state <= IDLE;
	else if (tick_i) begin
		case (state)
			IDLE: if (~rx) state <= START_BIT;
			START_BIT: if (sample) state <= B0;
			B0: if (sample) state <= B1;
			B1: if (sample) state <= B2;
			B2: if (sample) state <= B3;
			B3: if (sample) state <= B4;
			B4: if (sample) state <= B5;
			B5: if (sample) state <= B6;
			B6: if (sample) state <= B7;
			B7: if (sample) state <= IDLE;
			default: state <= IDLE;
		endcase
	end
end

always_ff @(posedge clk_i) begin
	if (!rst_ni) sample_cnt <= '0;
	else if (state == IDLE) sample_cnt <= '0;
	else if (tick_i) sample_cnt <= sample_cnt + 1;
end
assign sample = sample_cnt == 7 ? 1'b1 : 1'b0;

always_ff @(posedge clk_i) begin
	if (!rst_ni) begin
		data <= '0;
		rxd_o <= '0;
		valid_o <= '0;
	end else begin
		valid_o <= 1'b0;
		if (tick_i && sample && state[3]) begin
			data <= {rx, data[7:1]};
			if (state == B7) begin
				valid_o <= 1'b1;
				rxd_o <= {rx, data[7:1]};
			end
		end
	end
end

endmodule