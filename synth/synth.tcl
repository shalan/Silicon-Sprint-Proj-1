# Synthesis script for project_macro using Yosys + Sky130 HD
#
# Usage:
#   yosys -c synth/synth.tcl
#
# Prerequisites:
#   - PDK installed at $PDK_ROOT/sky130A
#   - Yosys with sky130 plugin
#
# Outputs:
#   synth/project_macro.v      - Netlist
#   synth/project_macro.rpt    - Area/timing report
#   synth/project_macro.stat   - Statistics

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
set PDK_ROOT $::env(PDK_ROOT)
set PDK      "$PDK_ROOT/sky130A"
set LIB      "$PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set LEF      "$PDK/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
set SDC      "sdc/project_macro.sdc"

set TOP      "project_macro"
set RTL_DIR  "rtl"
set UART_DIR "uart_apb_master/rtl"
set USB_DIR  "usb_cdc/usb_cdc"
set OUT_DIR  "synth"

# ---------------------------------------------------------------
# Read liberty and LEF
# ---------------------------------------------------------------
read_liberty -lib $LIB

# ---------------------------------------------------------------
# Read Verilog sources
# ---------------------------------------------------------------
# Note: fll_sim.v and sky130_stubs.v are simulation-only;
# for synthesis we use fll_top.v which instantiates the real
# fracn_dll and sky130 standard cells.
read_verilog -sv \
    $RTL_DIR/project_macro.v \
    $RTL_DIR/fll_top.v \
    $RTL_DIR/apb_clk_ctrl.v \
    $RTL_DIR/apb_status.v \
    $RTL_DIR/apb_usb_fifo.v \
    $RTL_DIR/clk_mux_2to1.v \
    $RTL_DIR/clk_div.v \
    $UART_DIR/uart_apb_master.v \
    $UART_DIR/uart_rx.v \
    $UART_DIR/uart_tx.v \
    $UART_DIR/baud_gen.v \
    $UART_DIR/cmd_parser.v \
    $UART_DIR/resp_builder.v \
    $UART_DIR/apb_master.v \
    $UART_DIR/apb_splitter.v \
    $UART_DIR/uart_apb_sys.v \
    $USB_DIR/usb_cdc.v \
    $USB_DIR/bulk_endp.v \
    $USB_DIR/ctrl_endp.v \
    $USB_DIR/in_fifo.v \
    $USB_DIR/out_fifo.v \
    $USB_DIR/phy_rx.v \
    $USB_DIR/phy_tx.v \
    $USB_DIR/sie.v

# Read fracn_dll from IP directory
read_verilog -sv fracn_dll/dll.v fracn_dll/dll_controller.v

# Read RC oscillator behavioral models (black-box for synthesis)
# These are analog IPs — they will be placed as hard macros
read_verilog -sv \
    $RTL_DIR/sky130_ef_ip__rc_osc_16M.v \
    $RTL_DIR/sky130_ef_ip__rc_osc_500k.v

# ---------------------------------------------------------------
# Elaborate
# ---------------------------------------------------------------
hierarchy -check -top $TOP
# Mark analog IPs as black boxes
blackbox sky130_ef_ip__rc_osc_16M
blackbox sky130_ef_ip__rc_osc_500k
# The ring_osc2x13 inside fracn_dll is also analog
blackbox ring_osc2x13

# ---------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------
synth -top $TOP

# ---------------------------------------------------------------
# Optimize
# ---------------------------------------------------------------
opt -purge
opt_clean
opt_expr
opt_merge
opt_muxtree
opt_reduce

# ---------------------------------------------------------------
# DFF legalization for Sky130
# ---------------------------------------------------------------
dfflegalize -cell {sky130_fd_sc_hd__dfxtp_1} -mincelems 1

# ---------------------------------------------------------------
# Technology mapping
# ---------------------------------------------------------------
abc -liberty $LIB -clock sky130_fd_sc_hd__clkbuf_1
clean
opt_clean

# ---------------------------------------------------------------
# Reports
# ---------------------------------------------------------------
tee -o $OUT_DIR/${TOP}.stat stat
tee -o $OUT_DIR/${TOP}.rpt check

# ---------------------------------------------------------------
# Write outputs
# ---------------------------------------------------------------
write_verilog -noattr -noexpr -nodec $OUT_DIR/${TOP}.v
write_json    $OUT_DIR/${TOP}.json

puts ""
puts "============================================"
puts "  Synthesis complete: $OUT_DIR/${TOP}.v"
puts "============================================"
