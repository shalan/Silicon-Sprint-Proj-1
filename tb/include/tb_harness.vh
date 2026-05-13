// SPDX-License-Identifier: Apache-2.0
//
// tb_harness.vh — shared verification harness for project_macro
//
// Provides DUT instantiation, clock/reset generation, UART-APB driver tasks,
// self-checking infrastructure (pass/fail counters with $fatal on failure),
// optional waveform dump (+dumpwave plusarg), and a simulation timeout.
//
// Include this inside a testbench module:
//
//     module tb_my_test;
//         `include "tb_harness.vh"
//         initial begin
//             init_test("my_test");
//             do_reset();
//             // ... apb_write / apb_read / check ...
//             finalize_test();
//         end
//     endmodule
//
// Run with: make sim TEST=my_test
//      or:  make sim TEST=my_test DUMP=1   (enables VCD dump)

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
        uart_rx        = 1;
        gpio_bot_drive = 15'b0;
        gpio_bot_drive[11] = 1;
    end

    // UART byte transmit (TB -> DUT)
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

    // UART byte receive thread (DUT -> TB)
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
    reg [255:0] tb_name;

    task check;
        input [256:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[%0t] FAIL %0s: got=0x%08h expected=0x%08h",
                         $time, name, actual, expected);
            end
        end
    endtask

    task init_test;
        input [255:0] name;
        begin
            pass_count = 0;
            fail_count = 0;
            tb_name    = name;
            $display("[%0t] Testbench '%0s' starting...", $time, name);
            if ($test$plusargs("dumpwave")) begin
                $dumpfile("build/wave.vcd");
                $dumpvars(0, u_dut);
                $display("[%0t] VCD dump enabled: build/wave.vcd", $time);
            end
        end
    endtask

    task do_reset;
        begin
            reset_n            = 0;
            por_n              = 0;
            gpio_bot_drive[11] = 0;
            #1000;
            reset_n            = 1;
            por_n              = 1;
            #500;
            gpio_bot_drive[11] = 1;
            $display("[%0t] Reset released", $time);
            #5000;
        end
    endtask

    // Print summary and exit with non-zero code on any failure
    task finalize_test;
        begin
            $display("");
            $display("========================================");
            $display("  RESULTS [%0s]: %0d passed, %0d failed",
                     tb_name, pass_count, fail_count);
            $display("========================================");
            if (fail_count > 0) begin
                $display("  *** SOME TESTS FAILED ***");
                $display("========================================");
                $fatal(1, "Testbench failed");
            end else begin
                $display("  ALL TESTS PASSED");
                $display("========================================");
                $finish;
            end
        end
    endtask

    // Global simulation timeout (overridable by setting SIM_TIMEOUT_NS before include)
`ifndef SIM_TIMEOUT_NS
  `define SIM_TIMEOUT_NS 120_000_000
`endif
    initial begin
        #(`SIM_TIMEOUT_NS);
        $display("[%0t] TIMEOUT - simulation exceeded %0d ns",
                 $time, `SIM_TIMEOUT_NS);
        $fatal(1, "Simulation timeout");
    end
