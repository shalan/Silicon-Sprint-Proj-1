# Static Timing Analysis script for project_macro
# Uses OpenSTA with Sky130 HD library
#
# Usage:
#   sta -no_splash sta.tcl
#
# Prerequisites:
#   - PDK installed at $PDK_ROOT
#   - sta (OpenSTA) binary in PATH

set PDK_ROOT $::env(PDK_ROOT)
set PDK      "$PDK_ROOT/sky130A"
set LIB      "$PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

# ---------------------------------------------------------------
# Read libraries
# ---------------------------------------------------------------
read_liberty $LIB

# ---------------------------------------------------------------
# Read netlist (generated from synthesis)
# ---------------------------------------------------------------
if {[file exists synth/project_macro.v]} {
    read_verilog synth/project_macro.v
    link_design project_macro
} else {
    puts "ERROR: synth/project_macro.v not found. Run synthesis first."
    exit 1
}

# ---------------------------------------------------------------
# Read SDC constraints
# ---------------------------------------------------------------
read_sdc sdc/project_macro.sdc

# ---------------------------------------------------------------
# Run timing analysis
# ---------------------------------------------------------------
report_checks -path_delay max -fields {slew cap input nets fanout} -format full_clock_expanded
report_checks -path_delay min -fields {slew cap input nets fanout} -format full_clock_expanded
report_clock_skew
report_power
report_area

puts ""
puts "============================================"
puts "  STA complete"
puts "============================================"
