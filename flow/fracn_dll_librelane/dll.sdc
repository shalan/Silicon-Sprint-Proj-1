# DLL (fracn_dll) macro — PnR/signoff SDC.
#
# The DLL reference clock "osc" is xclk = 12 MHz (83.333 ns period).
# The ring oscillator output is internally generated (~96 MHz) and
# is NOT constrained as a clock port — it is an internal path.
#
# dll_controller runs on the ring oscillator clock (clockp[0] feedback)
# but this is not a port, so STA only sees paths from osc to clockp.
#
# Assumptions:
#   - 150 ps setup + hold uncertainty
#   - 3.5 % timing derate (OCV)
#   - I/O delays scaled to 25% of osc period

create_clock -name osc -period 83.333 [get_ports osc]

set_clock_uncertainty -setup 0.150 [get_clocks osc]
set_clock_uncertainty -hold  0.150 [get_clocks osc]
set_clock_transition 0.150 [all_clocks]

set_timing_derate -early 0.965
set_timing_derate -late  1.035

# Input delays — 25% of 83.333 ns = ~20 ns
set ctrl_inputs [list resetb enable div dco ext_trim]

foreach p $ctrl_inputs {
    set_input_delay  -clock osc -max 20.0 [get_ports $p]
    set_input_delay  -clock osc -min 5.0  [get_ports $p]
}

# Output delays — clockp is a generated clock output, relaxed
set_output_delay -clock osc -max 20.0 [get_ports {clockp[*]}]
set_output_delay -clock osc -min 5.0  [get_ports {clockp[*]}]

# Driving cell and load
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [all_inputs]
set_load 0.0175 [all_outputs]

# The ring oscillator is a combinational loop by design.
# Disable timing checks on the internal loop.
set_false_path -through [get_ports resetb]
set_false_path -through [get_ports enable]
