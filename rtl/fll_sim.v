// SPDX-License-Identifier: Apache-2.0
// fll_sim — Lightweight simulation model for the FLL (fracn_dll)
//
// When disabled, produces NO events (truly dormant).
// When enabled, produces a ~96 MHz clock.

`default_nettype none
`timescale 1ns / 1ps

module dll (
`ifdef USE_POWER_PINS
    inout  VPWR,
    inout  VGND,
`endif
    input  wire        resetb,
    input  wire        enable,
    input  wire        osc,
    output wire [1:0]  clockp,
    input  wire [7:0]  div,
    input  wire        dco,
    input  wire [25:0] ext_trim
);

    reg osc_reg;
    reg running;

    initial begin
        osc_reg  = 1'b0;
        running  = 1'b0;
    end

    always @(posedge enable) begin
        if (resetb) begin
            running = 1'b1;
            forever begin
                #5_208;
                osc_reg = ~osc_reg;
            end
        end
    end

    always @(negedge enable or negedge resetb) begin
        running = 1'b0;
        osc_reg = 1'b0;
    end

    assign clockp[0] = osc_reg;
    assign clockp[1] = ~osc_reg;

endmodule
`default_nettype wire
