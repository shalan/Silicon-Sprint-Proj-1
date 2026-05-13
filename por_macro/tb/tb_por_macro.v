// SPDX-License-Identifier: Apache-2.0
//
// tb_por_macro — Unit testbench for the all-digital PoR macro.
//
// Validates:
//   1. por_n_out starts asserted (= 0) on power-up
//   2. por_n_out deasserts (= 1) within the expected PVT window
//   3. After deassertion, the RO halts (no further clk_out toggles)
//   4. por_n_out remains HIGH for the rest of the run (latched by shift regs)
//
// To exercise the random-init behaviour the testbench forces each shift
// register to a random pattern at t=0, mirroring the trick used in the
// upstream shalan/ADPoR testbench.
//
`default_nettype none
`timescale 1ns / 1ps

module tb_por_macro;

    wire por_n_out;

    por_macro #(
        .ADPOR_LENGTH      (24),
        .DIV_BITS          (6),
        .RO_HALF_PERIOD_NS (8)
    ) dut (
        .por_n_out (por_n_out)
    );

    // Expected pulse window:  ~12 us (FF) .. ~51 us (SS), ~25 us (TT).
    // Sim model uses nominal RO_HALF_PERIOD_NS=8 -> expect ~25 us.
    localparam integer EXPECT_MIN_NS = 20_000;
    localparam integer EXPECT_MAX_NS = 35_000;

    integer pass_count;
    integer fail_count;

    task check_cond;
        input [255:0] name;
        input         cond;
        begin
            if (cond) begin
                pass_count = pass_count + 1;
                $display("[%0t] PASS %0s", $time, name);
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL %0s", $time, name);
            end
        end
    endtask

    integer t_deassert;
    integer ro_toggles_after;
    reg     ro_prev;

    initial begin
        pass_count = 0;
        fail_count = 0;
        t_deassert = 0;
        ro_toggles_after = 0;

        $dumpfile("build/tb_por_macro.vcd");
        $dumpvars(0, tb_por_macro);

        // The DUT's `ifdef SIMULATION` initial blocks already randomise
        // every flop's power-on state ($random), so no force/release here.

        // 1) por_n_out should be asserted shortly after t=0
        #100;
        check_cond("por_asserted_at_start", por_n_out === 1'b0);

        // 2) Wait for deassertion
        wait (por_n_out === 1'b1);
        t_deassert = $time;
        $display("[%0t] por_n_out deasserted (pulse width = %0d ns)",
                 $time, t_deassert);
        check_cond("pulse_width_min", t_deassert >= EXPECT_MIN_NS);
        check_cond("pulse_width_max", t_deassert <= EXPECT_MAX_NS);

        // 3) After deassertion, RO must stop. Count edges in a fixed window.
        ro_prev = dut.u_ro.clk_out;
        fork
            begin : edge_counter
                integer i;
                for (i = 0; i < 5000; i = i + 1) begin
                    #10;
                    if (dut.u_ro.clk_out !== ro_prev) begin
                        ro_toggles_after = ro_toggles_after + 1;
                        ro_prev = dut.u_ro.clk_out;
                    end
                end
            end
        join
        check_cond("ro_halted_after_por", ro_toggles_after <= 2);
        $display("[%0t] RO edges in 50 us after deassertion: %0d",
                 $time, ro_toggles_after);

        // 4) por_n_out must still be HIGH at end of run
        check_cond("por_latched_high", por_n_out === 1'b1);

        $display("");
        $display("========================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0) begin
            $display("  *** SOME TESTS FAILED ***");
            $fatal(1, "tb_por_macro failed");
        end else begin
            $display("  ALL TESTS PASSED");
            $finish;
        end
    end

    initial begin
        #500_000;
        $display("[%0t] TIMEOUT - tb_por_macro exceeded 500 us", $time);
        $fatal(1, "tb_por_macro timeout");
    end

endmodule
