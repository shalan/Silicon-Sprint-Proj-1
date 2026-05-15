// SPDX-License-Identifier: Apache-2.0
//
// attoio_wrap — thin project-side wrapper around attoio_macro that hides
// the unused host-peripheral (hp_*) bundles.
//
// The upstream AttoIO macro exposes three 16-bit alternate-function buses
// (hp0/hp1/hp2_out/oe/in, 144 ports total) so a host SoC can steer
// external peripherals onto AttoIO pads via PINMUX. This project does not
// use that feature, so we wrap the macro and tie the hp_* inputs to zero,
// leave the hp_*_in outputs dangling, and expose only:
//
//   - APB slave port
//   - 16-bit pad interface (pad_in / pad_out / pad_oe / pad_ctl)
//   - sysclk / clk_iop / rst_n
//   - irq_to_host
//
// The hardened version of *this* module then has a clean two-side pin
// layout: all pad_* on the north face, all APB + clk/rst/irq on the south.
//
`default_nettype none
`timescale 1ns / 1ps

module attoio_wrap #(
    parameter NGPIO = 16     // attoio_macro accepts 8 or 16
) (
    // ---- Clocks ----
    input  wire                 sysclk,
    input  wire                 clk_iop,

    // ---- Reset ----
    input  wire                 rst_n,

    // ---- APB4 slave (host / system bus, sysclk domain) ----
    input  wire [10:0]          PADDR,
    input  wire                 PSEL,
    input  wire                 PENABLE,
    input  wire                 PWRITE,
    input  wire [31:0]          PWDATA,
    input  wire [3:0]           PSTRB,
    output wire [31:0]          PRDATA,
    output wire                 PREADY,
    output wire                 PSLVERR,

    // ---- Pad interface ----
    input  wire [NGPIO-1:0]     pad_in,
    output wire [NGPIO-1:0]     pad_out,
    output wire [NGPIO-1:0]     pad_oe,
    output wire [NGPIO*8-1:0]   pad_ctl,

    // ---- Status ----
    output wire                 irq_to_host
);

    attoio_macro #(
        .NGPIO (NGPIO)
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

        .pad_in      (pad_in),
        .pad_out     (pad_out),
        .pad_oe      (pad_oe),
        .pad_ctl     (pad_ctl),

        // Host-peripheral bundles are unused -- tie inputs off, drop
        // the inputs-to-host (hp*_in) outputs. PINMUX defaults to '00
        // (= AttoIO drives the pad), so these never propagate anyway.
        .hp0_out     ({NGPIO{1'b0}}),
        .hp0_oe      ({NGPIO{1'b0}}),
        .hp0_in      (/* unused */),
        .hp1_out     ({NGPIO{1'b0}}),
        .hp1_oe      ({NGPIO{1'b0}}),
        .hp1_in      (/* unused */),
        .hp2_out     ({NGPIO{1'b0}}),
        .hp2_oe      ({NGPIO{1'b0}}),
        .hp2_in      (/* unused */),

        .irq_to_host (irq_to_host)
    );

endmodule
