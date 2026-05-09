# Synthesis script for project_macro using Yosys + Sky130 HD
#
# Usage:
#   PDK_ROOT=/path/to/sky130A yosys -c synth/synth.tcl
#
# Outputs:
#   synth/project_macro.v      - Netlist
#   synth/project_macro.stat   - Statistics

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
if {[info exists ::env(PDK_ROOT)]} {
    set PDK_ROOT $::env(PDK_ROOT)
} else {
    set PDK_ROOT "/Users/mshalan/work/pdks/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A"
}

set PDK      "$PDK_ROOT/libs.ref/sky130_fd_sc_hd"
set LIB      "$PDK/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set LIB_V    "$PDK/verilog/sky130_fd_sc_hd.v"
set PRIM_V   "$PDK/verilog/primitives.v"

set TOP      "project_macro"
set PROJ     [file dirname [file dirname [file normalize [info script]]]]
set RTL_DIR  "$PROJ/rtl"
set UART_DIR "$PROJ/uart_apb_master/rtl"
set USB_DIR  "$PROJ/usb_cdc/usb_cdc"
set FLL_DIR  "$PROJ/fracn_dll"
set OUT_DIR  "$PROJ/synth"

file mkdir $OUT_DIR

puts "PDK_ROOT: $PDK_ROOT"
puts "LIB:      $LIB"

# ---------------------------------------------------------------
# Read liberty
# ---------------------------------------------------------------
read_liberty -lib -ignore_miss_func $LIB

# ---------------------------------------------------------------
# Read Sky130 HD Verilog models
# ---------------------------------------------------------------
read_verilog -lib $LIB_V $PRIM_V

# ---------------------------------------------------------------
# Read project RTL (synthesis versions, not sim stubs)
# ---------------------------------------------------------------
read_verilog \
    $RTL_DIR/project_macro.v \
    $RTL_DIR/fll_top.v \
    $RTL_DIR/apb_clk_ctrl.v \
    $RTL_DIR/apb_status.v \
    $RTL_DIR/apb_usb_fifo.v \
    $RTL_DIR/clk_mux_2to1.v \
    $RTL_DIR/clk_div.v

# UART APB master
read_verilog \
    $UART_DIR/uart_apb_master.v \
    $UART_DIR/uart_rx.v \
    $UART_DIR/uart_tx.v \
    $UART_DIR/baud_gen.v \
    $UART_DIR/cmd_parser.v \
    $UART_DIR/resp_builder.v \
    $UART_DIR/apb_master.v \
    $UART_DIR/apb_splitter.v \
    $UART_DIR/uart_apb_sys.v

# USB CDC
read_verilog \
    $USB_DIR/usb_cdc.v \
    $USB_DIR/bulk_endp.v \
    $USB_DIR/ctrl_endp.v \
    $USB_DIR/in_fifo.v \
    $USB_DIR/out_fifo.v \
    $USB_DIR/phy_rx.v \
    $USB_DIR/phy_tx.v \
    $USB_DIR/sie.v

# Fracn DLL (dll.v includes dll_controller.v and ring_osc2x13.v)
read_verilog -sv $FLL_DIR/dll.v

# RC oscillator stubs (black-box for synthesis — analog IPs)
read_verilog -sv $OUT_DIR/blackbox_stubs.v

# ---------------------------------------------------------------
# Elaborate
# ---------------------------------------------------------------
hierarchy -check -top $TOP

# Mark analog IPs as black boxes
blackbox sky130_ef_ip__rc_osc_16M
blackbox sky130_ef_ip__rc_osc_500k

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
opt_clean

# ---------------------------------------------------------------
# DFF legalization for Sky130
dfflegalize -cell {$_DFF_P_} x -cell {$_DFF_PN0_} 0 -cell {$_DFF_PN1_} 1

# Map generic DFFs to Sky130 cells
techmap -map $OUT_DIR/dff_map.v

# Technology mapping
abc -liberty $LIB
clean
opt_clean

# ---------------------------------------------------------------
# Reports
# ---------------------------------------------------------------
tee -o $OUT_DIR/${TOP}.stat stat
tee -o $OUT_DIR/${TOP}.check check

# ---------------------------------------------------------------
# Write outputs
# ---------------------------------------------------------------
write_verilog -noattr -noexpr -nodec $OUT_DIR/${TOP}.v
write_json    $OUT_DIR/${TOP}.json

puts ""
puts "============================================"
puts "  Synthesis complete: $OUT_DIR/${TOP}.v"
puts "============================================"
