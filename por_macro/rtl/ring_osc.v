// SPDX-License-Identifier: Apache-2.0
//
// ring_osc — Free-running ring oscillator with NAND-gated enable.
//
// Two compile-time views:
//
//   `ifdef SIMULATION   -> behavioral toggle model (for fast RTL sim)
//   else                -> Sky130 HD gate-level netlist (for synthesis,
//                          STA, and physical implementation)
//
// Gate-level topology:
//
//     enable ──┐
//              │
//           ┌──▼──┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
//   n[19] ─►│NAND2│──►│INV_1│──►│INV_1│──►│INV_1│──►│INV_1│──┐
//           └─────┘   └─────┘   └─────┘   └─────┘   └─────┘  │
//                                                            │
//      ┌───── n[19] ◄────  ... 15× clkdlybuf4s50_1 ... ◄─────┘
//      │
//      └──► back into NAND2.A
//
//   5 inversions (1 NAND + 4 INV) + 15 non-inverting delay buffers
//   = 20 cells total, odd inversion parity -> oscillates.
//
//   When enable=0, the NAND2 output is forced HIGH and the loop settles
//   in a stable state (no oscillation, no dynamic power).
//
// Frequency (post-layout, TT 1.8 V 25 C):  ~62 MHz nominal
// Period:                                  ~16 ns
// PVT spread:                              ~30 MHz (SS) .. ~130 MHz (FF)
//
// Every cell instance and the loop net carry `(* keep = "true" *)` and
// `(* dont_touch = "true" *)` attributes so Yosys / OpenROAD preserve the
// structural intent. The SDC must additionally declare the loop net as
// a generated clock and break the timing arc, otherwise STA will report
// a combinational loop.
//
`default_nettype none
`timescale 1ns / 1ps

module ring_osc #(
    parameter integer HALF_PERIOD_NS = 8   // simulation-only knob
) (
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    input  wire enable,
    output wire clk_out
);

// -----------------------------------------------------------------------------
`ifdef SIMULATION
// -----------------------------------------------------------------------------
// Behavioral view: pure RTL toggle. Does not exercise the gate-level
// structure; intended for fast iverilog runs of the surrounding logic.
    reg clk_int;
    initial clk_int = 1'b1;
    always begin
        #(HALF_PERIOD_NS);
        if (enable === 1'b0)
            clk_int <= 1'b1;        // mirrors NAND2 forcing output HIGH
        else
            clk_int <= ~clk_int;
    end
    assign clk_out = clk_int;

// -----------------------------------------------------------------------------
`else
// -----------------------------------------------------------------------------
// Gate-level view: hand-instantiated Sky130 HD cells. Synthesizable;
// preserved by Yosys via keep/dont_touch attributes.

    (* keep = "true" *) (* dont_touch = "true" *)
    wire [19:0] n;

    // Loop stage 0: NAND2 with enable. Output = n[0], feedback input = n[19].
    (* keep = "true" *) (* dont_touch = "true" *)
    sky130_fd_sc_hd__nand2_1 u_nand (
`ifdef USE_POWER_PINS
        .VPWR (VPWR),
        .VGND (VGND),
        .VPB  (VPWR),
        .VNB  (VGND),
`endif
        .Y (n[0]),
        .A (n[19]),
        .B (enable)
    );

    // Loop stages 1..4: four inverters.
    (* keep = "true" *) (* dont_touch = "true" *)
    sky130_fd_sc_hd__inv_1 u_inv_0 (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
        .Y (n[1]), .A (n[0])
    );
    (* keep = "true" *) (* dont_touch = "true" *)
    sky130_fd_sc_hd__inv_1 u_inv_1 (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
        .Y (n[2]), .A (n[1])
    );
    (* keep = "true" *) (* dont_touch = "true" *)
    sky130_fd_sc_hd__inv_1 u_inv_2 (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
        .Y (n[3]), .A (n[2])
    );
    (* keep = "true" *) (* dont_touch = "true" *)
    sky130_fd_sc_hd__inv_1 u_inv_3 (
`ifdef USE_POWER_PINS
        .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
        .Y (n[4]), .A (n[3])
    );

    // Loop stages 5..19: fifteen non-inverting delay buffers (~500 ps each).
    genvar i;
    generate
        for (i = 0; i < 15; i = i + 1) begin : g_dly
            (* keep = "true" *) (* dont_touch = "true" *)
            sky130_fd_sc_hd__clkdlybuf4s50_1 u_dly (
`ifdef USE_POWER_PINS
                .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
                .X (n[5 + i]),
                .A (n[4 + i])
            );
        end
    endgenerate

    // Tap the loop right after the NAND2 — the cleanest edge in the chain.
    assign clk_out = n[0];

`endif
// -----------------------------------------------------------------------------

endmodule
