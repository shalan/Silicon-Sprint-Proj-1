// SPDX-License-Identifier: Apache-2.0
//
// adpor — All-digital power-on reset core.
//
// Adapted from https://github.com/shalan/ADPoR  (Mohamed Shalan)
//
// Four LENGTH-bit shift registers run from a slow PoR clock. Two are fed
// with a constant '1, two with a constant '0. Each comparator asserts only
// when its register has been completely filled with the input value. The
// AND of all four comparators is `rst_n`.
//
// On power-up the shift-register flops come up with random values. After
// LENGTH clocks the registers are guaranteed to contain only the input
// pattern, so `rst_n` deasserts (= goes high). Probability of a spurious
// early match is (1/2^LENGTH)^4 = 2^-(4*LENGTH); for LENGTH=24 that is
// 2^-96 -- negligible.
//
// Once `rst_n` is high, the upstream RO is gated off (via the enable in
// por_macro). With no clock, the shift registers hold their matched
// contents indefinitely, so `rst_n` stays high until the next power cycle
// brings the flops to random state again. The shift registers themselves
// act as the latch -- no extra storage needed.
//
`default_nettype none
`timescale 1ns / 1ps

module adpor_shift #(parameter integer LENGTH = 24) (
    input  wire                  clk,
    input  wire                  in,
    input  wire [LENGTH-1:0]     cmp,
    output wire                  match
);
    reg [LENGTH-1:0] shift_reg;

    // For iverilog runs we randomise the initial state so the macro
    // behaves like silicon coming out of power-on. The synthesized macro
    // does not need this.
`ifdef SIMULATION
    initial shift_reg = $random;
`endif

    always @(posedge clk)
        shift_reg <= {in, shift_reg[LENGTH-1:1]};

    assign match = (shift_reg == cmp);
endmodule


module adpor #(parameter integer LENGTH = 24) (
    input  wire clk,
    output wire rst_n
);
    wire m1, m2, m3, m4;

    adpor_shift #(.LENGTH(LENGTH)) reg1 (
        .clk(clk), .in(1'b1), .cmp({LENGTH{1'b1}}), .match(m1));
    adpor_shift #(.LENGTH(LENGTH)) reg2 (
        .clk(clk), .in(1'b0), .cmp({LENGTH{1'b0}}), .match(m2));
    adpor_shift #(.LENGTH(LENGTH)) reg3 (
        .clk(clk), .in(1'b1), .cmp({LENGTH{1'b1}}), .match(m3));
    adpor_shift #(.LENGTH(LENGTH)) reg4 (
        .clk(clk), .in(1'b0), .cmp({LENGTH{1'b0}}), .match(m4));

    assign rst_n = m1 & m2 & m3 & m4;

endmodule
