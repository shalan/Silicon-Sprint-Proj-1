`default_nettype none
`timescale 1ns / 1ps
//
// Testbench for project_macro
//
// UART-based APB testbench. Uses a parallel receiver thread to capture
// response bytes while the main thread sends commands. This handles the
// full-duplex nature of the UART bridge where responses can start before
// the command transmission completes.
//
// The receiver thread monitors uart_tx continuously, catching each byte
// as it arrives. The main thread uses rx_target to specify how many bytes
// to expect (1 for writes, 5 for reads) and waits on rx_done.
//
module tb_project_macro;

    reg         clk;
    reg         reset_n;
    reg         por_n;
    reg         xclk;
    reg         uart_rx;
    reg  [14:0] gpio_bot_drive;
    wire [14:0] gpio_bot_out;
    wire [14:0] gpio_bot_oeb;
    wire [44:0] gpio_bot_dm;
    wire [8:0]  gpio_rt_out;
    wire [8:0]  gpio_rt_oeb;
    wire [26:0] gpio_rt_dm;
    wire [13:0] gpio_top_out;
    wire [13:0] gpio_top_oeb;
    wire [41:0] gpio_top_dm;

    wire [14:0] gpio_bot_in;
    wire [8:0]  gpio_rt_in;
    wire [13:0] gpio_top_in;

    assign gpio_bot_in[0]     = uart_rx;
    assign gpio_bot_in[1]     = 1'b0;
    assign gpio_bot_in[2]     = xclk;
    assign gpio_bot_in[14:3]  = gpio_bot_drive[14:3];
    assign gpio_rt_in         = 9'b0;
    assign gpio_top_in        = 14'b0;

    project_macro #(
        .XCLK_FREQ_MHZ    (12),
        .BAUD_DIV         (16'd13)
    ) u_dut (
        .clk          (clk),
        .reset_n      (reset_n),
        .por_n        (por_n),
        .gpio_bot_in  (gpio_bot_in),
        .gpio_bot_out (gpio_bot_out),
        .gpio_bot_oeb (gpio_bot_oeb),
        .gpio_bot_dm  (gpio_bot_dm),
        .gpio_rt_in   (gpio_rt_in),
        .gpio_rt_out  (gpio_rt_out),
        .gpio_rt_oeb  (gpio_rt_oeb),
        .gpio_rt_dm   (gpio_rt_dm),
        .gpio_top_in  (gpio_top_in),
        .gpio_top_out (gpio_top_out),
        .gpio_top_oeb (gpio_top_oeb),
        .gpio_top_dm  (gpio_top_dm)
    );

    wire uart_tx = gpio_bot_out[1];

    localparam XCLK_HALF = 41;
    localparam CLK_HALF  = 25;
    localparam BIT_NS    = 17333;

    initial begin
        clk = 0;
        forever #CLK_HALF clk = ~clk;
    end

    initial begin
        xclk = 0;
        forever #XCLK_HALF xclk = ~xclk;
    end

    initial begin
        uart_rx       = 1;
        gpio_bot_drive = 15'b0;
        gpio_bot_drive[11] = 1;
    end

    task send_byte;
        input [7:0] data;
        integer i;
        begin
            uart_rx = 0;
            #BIT_NS;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #BIT_NS;
            end
            uart_rx = 1;
            #BIT_NS;
        end
    endtask

    reg [7:0]  rx_buf [0:7];
    reg        rx_done;
    integer    rx_idx;
    integer    rx_target;

    initial begin
        rx_done   = 0;
        rx_idx    = 0;
        rx_target = 1;
        forever begin
            @(negedge uart_tx);
            #(BIT_NS + BIT_NS/2);
            begin : rx_byte_blk
                reg [7:0] r;
                integer j;
                r = 0;
                for (j = 0; j < 8; j = j + 1) begin
                    r[j] = uart_tx;
                    #BIT_NS;
                end
                rx_buf[rx_idx] = r;
                rx_idx = rx_idx + 1;
                if (rx_idx >= rx_target)
                    rx_done = 1;
            end
        end
    end

    task apb_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            rx_done = 0; rx_idx = 0; rx_target = 5;
            send_byte(8'hDE); send_byte(8'hAD); send_byte(8'h5A);
            send_byte(addr[31:24]); send_byte(addr[23:16]);
            send_byte(addr[15:8]);  send_byte(addr[7:0]);
            wait (rx_done);
            data = {rx_buf[1], rx_buf[2], rx_buf[3], rx_buf[4]};
        end
    endtask

    task apb_write;
        input [31:0] addr;
        input [31:0] wdata;
        begin
            rx_done = 0; rx_idx = 0; rx_target = 1;
            send_byte(8'hDE); send_byte(8'hAD); send_byte(8'hA5);
            send_byte(addr[31:24]); send_byte(addr[23:16]);
            send_byte(addr[15:8]);  send_byte(addr[7:0]);
            send_byte(wdata[31:24]); send_byte(wdata[23:16]);
            send_byte(wdata[15:8]);  send_byte(wdata[7:0]);
            wait (rx_done);
        end
    endtask

    integer pass_count;
    integer fail_count;

    task check;
        input [256:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL %0s: got=0x%08h expected=0x%08h", $time, name, actual, expected);
            end
        end
    endtask

    reg [31:0] rdata;

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("[%0t] Testbench starting...", $time);

        reset_n = 0;
        por_n   = 0;
        gpio_bot_drive[11] = 0;
        #1000;
        reset_n = 1;
        por_n   = 1;
        #500;
        gpio_bot_drive[11] = 1;
        $display("[%0t] Reset released", $time);
        #5000;

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

        #100000;

        $display("");
        $display("========================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count > 0)
            $display("  *** SOME TESTS FAILED ***");
        else
            $display("  ALL TESTS PASSED");
        $display("========================================");

        $finish;
    end

    initial begin
        #120_000_000;
        $display("[%0t] TIMEOUT - simulation exceeded 120s", $time);
        $finish;
    end

endmodule
