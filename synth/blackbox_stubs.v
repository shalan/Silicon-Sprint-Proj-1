module sky130_ef_ip__rc_osc_16M (ena, dout);
    input ena;
    output dout;
endmodule

module sky130_ef_ip__rc_osc_500k (ena, dout);
    input ena;
    output dout;
endmodule

// All-digital PoR macro — hardened separately under por_macro/.
// Project-level synth treats it as a black box.
module por_macro (por_n_out);
    output por_n_out;
endmodule
