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

module sim_uart #(
    parameter int    clk_freq = 50000000,
    parameter int    divider  = 1,
    parameter string pty_name = "uart0",
    parameter int    OSR      = 16
) (
    input   logic clk_i,
    input   logic rst_ni,

    input   logic boot_en = 1'b1,

    output  logic tx_o,
    input   logic rx_i = 1'b1
);

    // =========================================================================
    // DPI-C
    // =========================================================================
    import "DPI-C" function chandle uartdpi_create(input string name);
    import "DPI-C" function int     uartdpi_get_byte(input chandle ctx);
    import "DPI-C" function void    uartdpi_put_byte(input chandle ctx, input byte c);
    import "DPI-C" function void    uartdpi_close(input chandle ctx);

    chandle dpi_ctx;

    initial begin
        dpi_ctx = uartdpi_create(pty_name);
        if (dpi_ctx == null)
            $fatal(1, "Failed to create virtual PTY for sim_uart");
    end

    final begin
        uartdpi_close(dpi_ctx);
    end

    logic tick;
    logic tick8;

    baud_gen #(clk_freq) i_baudgen (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .divider_i  (divider),
        .tick_o     (tick),
        .tick8_o    (tick8)
    );

    // host -> SoC
    typedef enum logic {TX_IDLE, TX_SEND} tx_state_t;

    tx_state_t  tx_state;
    logic       tx_q;
    logic [9:0] tx_shreg;   // {stop, data[7:0], start}, LSB goes out first
    logic [3:0] tx_cnt;
    int         tx_byte;

    assign tx_o = tx_q;

    /* verilator lint_off BLKSEQ */
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            tx_state <= TX_IDLE;
            tx_q     <= 1'b1;
            tx_shreg <= '1;
            tx_cnt   <= '0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_q <= 1'b1;
                    // Poll the C side only on tick
                    if (tick && boot_en) begin
                        tx_byte = uartdpi_get_byte(dpi_ctx);
                        if (tx_byte >= 0) begin
                            tx_shreg <= {1'b1, tx_byte[7:0], 1'b0};
                            tx_cnt   <= '0;
                            tx_state <= TX_SEND;
                        end
                    end
                end

                TX_SEND: begin
                    if (tick) begin
                        tx_q     <= tx_shreg[0];
                        tx_shreg <= {1'b1, tx_shreg[9:1]};
                        if (tx_cnt == 4'd9) begin
                            tx_state <= TX_IDLE;
                        end else begin
                            tx_cnt <= tx_cnt + 4'd1;
                        end
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end
    /* verilator lint_on BLKSEQ */

    // SoC -> host
    localparam int OSR_W = $clog2(OSR);
    localparam logic [OSR_W-1:0] MID_START = OSR_W'(OSR/2 - 1);
    localparam logic [OSR_W-1:0] FULL_BIT  = OSR_W'(OSR - 1);

    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;

    rx_state_t         rx_state;
    logic [OSR_W-1:0]  rx_tick_cnt;
    logic [2:0]        rx_bit_cnt;
    logic [7:0]        rx_shreg;
    logic              rx_sync_q, rx_sync;

    // 2-flop synchroniser
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_sync_q <= 1'b1;
            rx_sync   <= 1'b1;
        end else begin
            rx_sync_q <= rx_i;
            rx_sync   <= rx_sync_q;
        end
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            rx_state    <= RX_IDLE;
            rx_tick_cnt <= '0;
            rx_bit_cnt  <= '0;
            rx_shreg    <= '0;
        end else if (tick8) begin
            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync) begin
                        rx_tick_cnt <= '0;
                        rx_state    <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_tick_cnt == MID_START) begin
                        rx_tick_cnt <= '0;
                        rx_bit_cnt  <= '0;
                        rx_state    <= (!rx_sync) ? RX_DATA : RX_IDLE;
                    end else begin
                        rx_tick_cnt <= rx_tick_cnt + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_tick_cnt == FULL_BIT) begin
                        rx_tick_cnt          <= '0;
                        rx_shreg[rx_bit_cnt] <= rx_sync;
                        if (rx_bit_cnt == 3'd7) rx_state <= RX_STOP;
                        else                    rx_bit_cnt <= rx_bit_cnt + 3'd1;
                    end else begin
                        rx_tick_cnt <= rx_tick_cnt + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (rx_tick_cnt == FULL_BIT) begin
                        if (boot_en) uartdpi_put_byte(dpi_ctx, byte'(rx_shreg));
                        rx_state    <= RX_IDLE;
                        rx_tick_cnt <= '0;
                    end else begin
                        rx_tick_cnt <= rx_tick_cnt + 1'b1;
                    end
                end

                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule