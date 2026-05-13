// SPDX-License-Identifier: Apache-2.0
//
// por_macro — All-digital power-on-reset macro for characterization.
//
//   ring_osc (~62 MHz nom)       /64 divider         adpor (LENGTH=24)
//   +-------+   ro_clk   +------------+   por_clk   +--------+
//   |       |----------->|            |------------>|        |
//   |       |            |  div_cnt   |             | shift  |---> por_n_out
//   |       |            |            |             | regs   |
//   +-------+            +------------+             +--------+
//       ^                                                |
//       |                                                |
//       |  enable = ~por_n_out                           |
//       +------------------------------------------------+
//
// Pulse width (typical, post-layout, TT 1.8 V 25 C):
//   LENGTH * (T_ro * 64) = 24 * (16 ns * 64) ~= 25 us
//   PVT range (FF..SS):                       ~12 us .. ~51 us
//
// After the PoR pulse deasserts:
//   - `por_n_out` stays HIGH (shift registers hold their settled state)
//   - `enable` stays LOW   -> RO is gated off (NAND2 forces stable HIGH)
//   - divider FFs have no clock -> hold state
//   - macro consumes only leakage current until the next power cycle
//
// Ports:
//   por_n_out  -- active-low PoR pulse. Intended for routing to a GPIO pad
//                 for scope/LA monitoring only; NOT a system reset.
//
`default_nettype none
`timescale 1ns / 1ps

module por_macro #(
    parameter integer ADPOR_LENGTH       = 24,
    parameter integer DIV_BITS           = 6,    // /64
    parameter integer RO_HALF_PERIOD_NS  = 8     // ~62.5 MHz nominal
) (
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    output wire por_n_out
);

    wire ro_clk;
    wire por_clk;
    wire enable;

    // Combinational disable feedback. As soon as ADPOR asserts the
    // deasserted state (por_n_out = 1), the NAND2 in the ring oscillator
    // forces a stable high; the divider and ADPOR shift registers stop
    // clocking and the macro idles at leakage current.
    assign enable = ~por_n_out;

    ring_osc #(
        .HALF_PERIOD_NS (RO_HALF_PERIOD_NS)
    ) u_ro (
        .enable  (enable),
        .clk_out (ro_clk)
    );

    // Ripple counter divider. FFs come up with random values on power-up,
    // which only delays the first POR-clk edge by up to /64 RO cycles
    // (~1 us) -- acceptable jitter at the start of the PoR pulse.
    reg [DIV_BITS-1:0] div_cnt;

`ifdef SIMULATION
    initial div_cnt = $random;
`endif

    always @(posedge ro_clk)
        div_cnt <= div_cnt + 1'b1;

    assign por_clk = div_cnt[DIV_BITS-1];

    adpor #(.LENGTH(ADPOR_LENGTH)) u_adpor (
        .clk   (por_clk),
        .rst_n (por_n_out)
    );

endmodule
