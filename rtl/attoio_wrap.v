// SPDX-License-Identifier: Apache-2.0
//
// attoio_wrap — thin project-side wrapper around attoio_macro.
//
// Hides everything that does not actually leave the chip:
//
//   * The three unused host-peripheral bundles (hp0/hp1/hp2). 144 ports.
//   * GPIO pins [15:14] -- the inner attoio_macro requires NGPIO=16,
//     but project_macro only routes 14 pads to the chip-level top edge.
//     The upper two pads are tied off inside the wrapper.
//   * The upper 5 bits of each per-pad 8-bit pad_ctl word. Only the
//     lower 3 (the drive-mode select that the Caravel padframe consumes)
//     reach the chip boundary; the rest (slew, hold, ...) stay internal
//     to AttoIO.
//
// Net effect on the hardened macro pin face:
//
//                                 OLD          NEW
//   N (pad-side)   pad_in           16  ->     14
//                  pad_out          16  ->     14
//                  pad_oe           16  ->     14
//                  pad_ctl/pad_dm  128  ->     42   (3 bits x 14 pads)
//                                 ----        ----
//                                  176  pins  84  pins
//
// The S face (APB + clk/rst + irq) is unchanged.
//
`default_nettype none
`timescale 1ns / 1ps

module attoio_wrap (
    // ---- Clocks ----
    input  wire        sysclk,
    input  wire        clk_iop,

    // ---- Reset ----
    input  wire        rst_n,

    // ---- APB4 slave (host / system bus, sysclk domain) ----
    input  wire [10:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    input  wire [3:0]  PSTRB,
    output wire [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    // ---- Pad interface (14 pads, post-slimming) ----
    input  wire [13:0] pad_in,
    output wire [13:0] pad_out,
    output wire [13:0] pad_oe,
    output wire [41:0] pad_dm,    // 3 bits per pad * 14 pads

    // ---- Status ----
    output wire        irq_to_host
);

    // ------------------------------------------------------------------
    // Inner attoio_macro still has the full 16-pad / 128-bit pad_ctl
    // interface (NGPIO is constrained to 8 or 16).
    // ------------------------------------------------------------------
    wire [15:0]  inner_pad_in;
    wire [15:0]  inner_pad_out;
    wire [15:0]  inner_pad_oe;
    wire [127:0] inner_pad_ctl;

    assign inner_pad_in[13:0]  = pad_in;
    assign inner_pad_in[15:14] = 2'b00;

    assign pad_out = inner_pad_out[13:0];
    assign pad_oe  = inner_pad_oe[13:0];
    // inner_pad_out[15:14] and inner_pad_oe[15:14] left unconnected.

    // For each of the 14 pinned pads, expose the low 3 bits of the
    // 8-bit pad_ctl word as the chip-level drive-mode bus.
    genvar i;
    generate
        for (i = 0; i < 14; i = i + 1) begin : g_pad_dm
            assign pad_dm[i*3 +: 3] = inner_pad_ctl[i*8 +: 3];
        end
    endgenerate
    // The upper 5 bits of each pad_ctl word, and the full pad_ctl
    // entries for pads [15:14], are intentionally not exposed.

    attoio_macro #(
        .NGPIO (16)
    ) u_attoio (
        .sysclk      (sysclk),
        .clk_iop     (clk_iop),
        .rst_n       (rst_n),

        .PADDR       (PADDR),
        .PSEL        (PSEL),
        .PENABLE     (PENABLE),
        .PWRITE      (PWRITE),
        .PWDATA      (PWDATA),
        .PSTRB       (PSTRB),
        .PRDATA      (PRDATA),
        .PREADY      (PREADY),
        .PSLVERR     (PSLVERR),

        .pad_in      (inner_pad_in),
        .pad_out     (inner_pad_out),
        .pad_oe      (inner_pad_oe),
        .pad_ctl     (inner_pad_ctl),

        .hp0_out     (16'b0),
        .hp0_oe      (16'b0),
        .hp0_in      (/* unused */),
        .hp1_out     (16'b0),
        .hp1_oe      (16'b0),
        .hp1_in      (/* unused */),
        .hp2_out     (16'b0),
        .hp2_oe      (16'b0),
        .hp2_in      (/* unused */),

        .irq_to_host (irq_to_host)
    );

endmodule
