module \$_DFF_P_ (input D, C, output Q);
    sky130_fd_sc_hd__dfxtp_1 _TECHMAP_REPLACE_ (.CLK(C), .D(D), .Q(Q));
endmodule

module \$_DFF_PN0_ (input D, C, R, output Q);
    sky130_fd_sc_hd__dfrtp_1 _TECHMAP_REPLACE_ (.CLK(C), .D(D), .RESET_B(R), .Q(Q));
endmodule

module \$_DFF_PN1_ (input D, C, R, output Q);
    sky130_fd_sc_hd__dfstp_1 _TECHMAP_REPLACE_ (.CLK(C), .D(D), .SET_B(R), .Q(Q));
endmodule
