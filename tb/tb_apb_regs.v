// SPDX-License-Identifier: Apache-2.0
//
// tb_apb_regs — APB register read/write smoke tests for project_macro.
//
// Exercises the UART-APB bridge and validates that all APB-mapped control,
// divider, monitor-enable, and USB-pad registers in apb_clk_ctrl store and
// return the correct values. Also performs basic external-reset behavior
// (GPIO[11]) and writes a few bytes to the USB FIFO (no host-side check).
//
// This is the renamed/restructured successor of the original
// tb_project_macro.v. The harness (clocks, reset, UART-APB driver, check)
// lives in include/tb_harness.vh.
//
`default_nettype none
`timescale 1ns / 1ps

module tb_apb_regs;

    `include "tb_harness.vh"

    reg [31:0] rdata;

    initial begin
        init_test("apb_regs");
        do_reset();

        $display("[%0t] Starting tests...", $time);

        $display("=== Test 1: CTRL defaults ===");
        apb_read(32'h0000_0000, rdata);
        check("ctrl_default", rdata, 32'h0000_0100);
        check("ctrl_status", {24'd0, rx_buf[0]}, {24'd0, 8'hAC});

        $display("=== Test 2: Enable FLL ===");
        apb_write(32'h0000_0000, 32'h0000_0101);
        apb_read(32'h0000_0000, rdata);
        check("fll_en", rdata[0], 1'b1);
        check("usb_rst_n", rdata[8], 1'b1);

        $display("=== Test 3: Enable all + monitor select ===");
        apb_write(32'h0000_0000, 32'h0000_011F);
        apb_read(32'h0000_0000, rdata);
        check("all_en", {rdata[2], rdata[1], rdata[0]}, 3'b111);
        check("sel_mon", rdata[5:3], 3'b011);
        check("usb_rst_n2", rdata[8], 1'b1);

        $display("=== Test 4: FLL bypass ===");
        apb_write(32'h0000_0000, 32'h0000_0167);
        apb_read(32'h0000_0000, rdata);
        check("fll_bypass", rdata[6], 1'b1);
        check("sel_mon2", rdata[5:3], 3'b100);

        $display("=== Test 5: FLL divider ===");
        apb_write(32'h0000_0004, 32'h0000_0040);
        apb_read(32'h0000_0004, rdata);
        check("fll_div", rdata[7:0], 8'h40);

        $display("=== Test 6: FLL DCO + ext_trim ===");
        apb_write(32'h0000_0008, 32'h0000_0021);
        apb_read(32'h0000_0008, rdata);
        check("fll_dco", rdata[0], 1'b1);
        check("fll_ext_trim", rdata[27:2], 26'd8);

        $display("=== Test 7: Monitor dividers ===");
        apb_write(32'h0000_000C, 32'h0000_00FF);
        apb_read(32'h0000_000C, rdata);
        check("fll_mon_div", rdata, 32'h0000_00FF);

        apb_write(32'h0000_0010, 32'h0000_07FF);
        apb_read(32'h0000_0010, rdata);
        check("rc16m_mon_div", rdata, 32'h0000_07FF);

        apb_write(32'h0000_0014, 32'h0000_003F);
        apb_read(32'h0000_0014, rdata);
        check("rc500k_mon_div", rdata, 32'h0000_003F);

        apb_write(32'h0000_0018, 32'h0000_1234);
        apb_read(32'h0000_0018, rdata);
        check("clk_mon_div", rdata, 32'h0000_1234);

        $display("=== Test 8: Monitor enables ===");
        apb_write(32'h0000_001C, 32'h0000_001F);
        apb_read(32'h0000_001C, rdata);
        check("all_mon_en", rdata[4:0], 5'b11111);

        $display("=== Test 9: USB pad config ===");
        apb_write(32'h0000_0020, 32'h0000_0111);
        apb_read(32'h0000_0020, rdata);
        check("usb_dp_dm",  rdata[2:0],  3'b001);
        check("usb_dn_dm",  rdata[5:3],  3'b010);
        check("usb_pu_dm",  rdata[8:6],  3'b100);

        $display("=== Test 10: Status registers ===");
        apb_read(32'h0000_2000, rdata);
        $display("[%0t] Status[0x2000] = 0x%08h", $time, rdata);

        apb_read(32'h0000_2004, rdata);
        $display("[%0t] FLL freq cnt[0x2004] = 0x%08h", $time, rdata);

        apb_read(32'h0000_2008, rdata);
        $display("[%0t] RC16M freq cnt[0x2008] = 0x%08h", $time, rdata);

        apb_read(32'h0000_200C, rdata);
        $display("[%0t] Ref freq cnt[0x200C] = 0x%08h", $time, rdata);

        $display("=== Test 11: USB FIFO write ===");
        apb_write(32'h0000_4000, 32'h0000_0048);
        apb_write(32'h0000_4000, 32'h0000_0065);
        apb_write(32'h0000_4000, 32'h0000_006C);
        apb_write(32'h0000_4000, 32'h0000_006C);
        apb_write(32'h0000_4000, 32'h0000_006F);
        $display("[%0t] Wrote 'Hello' to USB FIFO", $time);

        $display("=== Test 12: External reset via GPIO[11] ===");
        apb_write(32'h0000_0000, 32'h0000_0101);
        apb_read(32'h0000_0000, rdata);
        check("pre_ext_rst_fll_en", rdata[0], 1'b1);
        gpio_bot_drive[11] = 0;
        #2000;
        gpio_bot_drive[11] = 1;
        #2000;
        apb_read(32'h0000_0000, rdata);
        check("post_ext_rst_ctrl", rdata, 32'h0000_0100);

        $display("=== Test 13: nc_sercom reachable via APB slot 4 (0x8000) ===");
        // IM register (offset 0x020) is full 32-bit R/W.
        apb_write(32'h0000_8020, 32'hCAFE_BEEF);
        apb_read(32'h0000_8020, rdata);
        check("sercom_im_rw", rdata, 32'hCAFE_BEEF);
        apb_write(32'h0000_8020, 32'h0000_0000);
        apb_read(32'h0000_8020, rdata);
        check("sercom_im_clear", rdata, 32'h0000_0000);

        #100000;

        finalize_test();
    end

endmodule
