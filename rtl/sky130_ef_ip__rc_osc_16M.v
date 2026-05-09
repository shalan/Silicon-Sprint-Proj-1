// SPDX-License-Identifier: Apache-2.0
// sky130_ef_ip__rc_osc_16M — Behavioral model of 16 MHz RC oscillator
//
// Interface matches the analog macro (GDS/SPICE) for easy swap at layout.
// Startup delay ~1 ms after enable assertion.

`default_nettype none

module sky130_ef_ip__rc_osc_16M (
`ifdef USE_POWER_PINS
    inout  VPWR,
    inout  VGND,
`endif
    input  wire ena,
    output wire dout
);

    localparam HALF_PERIOD_NS = 31;

    reg osc;
    reg running;

    initial begin
        osc     = 1'b0;
        running = 1'b0;
    end

    always @(posedge ena) begin
        osc     = 1'b0;
        running = 1'b0;
        #(1000000);
        running = 1'b1;
    end

    always @(negedge ena) begin
        running = 1'b0;
        osc     = 1'b0;
    end

    always @(running) begin
        if (running) begin
            forever begin
                #(HALF_PERIOD_NS);
                osc = ~osc;
            end
        end
    end

    assign dout = running ? osc : 1'b0;

endmodule
`default_nettype wire
