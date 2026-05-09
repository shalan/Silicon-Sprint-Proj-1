// SPDX-License-Identifier: Apache-2.0
// sky130_stubs — Minimal behavioral stubs for Sky130 HD cells used by fracn_dll
// Only needed for simulation (-DFUNCTIONAL mode).

`timescale 1ns / 1ps
`default_nettype none

module sky130_fd_sc_hd__clkbuf_1 (A, X);
    input A;
    output X;
    assign X = A;
endmodule

module sky130_fd_sc_hd__clkbuf_2 (A, X);
    input A;
    output X;
    assign X = A;
endmodule

module sky130_fd_sc_hd__clkbuf_16 (A, X);
    input A;
    output X;
    assign X = A;
endmodule

module sky130_fd_sc_hd__clkinv_1 (A, Y);
    input A;
    output Y;
    assign Y = ~A;
endmodule

module sky130_fd_sc_hd__clkinv_2 (A, Y);
    input A;
    output Y;
    assign Y = ~A;
endmodule

module sky130_fd_sc_hd__clkinv_8 (A, Y);
    input A;
    output Y;
    assign Y = ~A;
endmodule

module sky130_fd_sc_hd__einvp_1 (A, TE, Z);
    input A, TE;
    output Z;
    assign Z = TE ? A : 1'bz;
endmodule

module sky130_fd_sc_hd__einvp_2 (A, TE, Z);
    input A, TE;
    output Z;
    assign Z = TE ? A : 1'bz;
endmodule

module sky130_fd_sc_hd__einvn_4 (A, TE_B, Z);
    input A, TE_B;
    output Z;
    assign Z = TE_B ? 1'bz : A;
endmodule

module sky130_fd_sc_hd__einvn_8 (A, TE_B, Z);
    input A, TE_B;
    output Z;
    assign Z = TE_B ? 1'bz : A;
endmodule

module sky130_fd_sc_hd__or2_2 (A, B, X);
    input A, B;
    output X;
    assign X = A | B;
endmodule

module sky130_fd_sc_hd__conb_1 (HI, LO);
    output HI, LO;
    assign HI = 1'b1;
    assign LO = 1'b0;
endmodule

`default_nettype wire
