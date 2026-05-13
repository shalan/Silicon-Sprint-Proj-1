// SPDX-License-Identifier: Apache-2.0
//
// ring_osc — Free-running ring oscillator with NAND-gated enable.
//
// Topology (hardened, Sky130 HD):
//
//        enable
//          |
//          v
//        +-----+      +-----+      +-----+      +-----+      +-----+
//        |NAND2|----->| INV |----->| INV |----->| INV |----->| INV |
//        +-----+      +-----+      +-----+      +-----+      +-----+
//          ^                                                    |
//          |                                                    v
//          |              [15 x clkdlybuf4s50_1]                |
//          +<---------------------------------------------------+
//
//   5 inversions (4*inv + 1*nand2) + 15 non-inverting delay cells
//   = 20 cells total, odd inversion parity -> oscillates.
//   NAND2 with `enable=0` forces output HIGH -> loop settles in stable state.
//
// Nominal post-layout frequency (TT, 1.8 V, 25 C):  ~62 MHz
// PVT spread (FF .. SS):                            ~30 MHz .. ~130 MHz
//
// This RTL view is the *simulation* model. The ASIC hardening flow must
// supply a hand-instantiated gate-level netlist for this module using the
// sky130_fd_sc_hd primitives above with `(* keep = "true" *)` and
// `(* dont_touch = "true" *)` attributes on every instance and on the loop
// net itself. A pure-RTL combinational inverter loop will be optimized away
// by any logic-synthesis tool.
//
`default_nettype none
`timescale 1ns / 1ps

module ring_osc #(
    parameter integer HALF_PERIOD_NS = 8   // 16 ns period -> ~62.5 MHz nominal
) (
    input  wire enable,
    output reg  clk_out
);

    initial clk_out = 1'b1;

    // Toggle on a sub-1-ns granularity so iverilog can capture both edges.
    always begin
        #(HALF_PERIOD_NS);
        if (enable === 1'b0)
            clk_out <= 1'b1;        // NAND2 forces output high
        else
            clk_out <= ~clk_out;    // oscillates (treats X as "running" too)
    end

endmodule
