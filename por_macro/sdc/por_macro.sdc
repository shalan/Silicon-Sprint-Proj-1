# SPDX-License-Identifier: Apache-2.0
#
# SDC for por_macro.
#
# The macro generates its own clocks internally. There is no clock input
# port. STA must be told two things:
#   1. the ring-oscillator output is a clock (with a nominal period and
#      generous PVT bounds)
#   2. the combinational feedback path that *makes* the oscillator is not
#      a normal timing path -- it must be broken so STA does not flag a
#      combinational loop.
#
# Nominal RO period (post-layout, TT 1.8 V 25 C): ~16 ns
# PVT range: ~7.5 ns (FF) .. ~33 ns (SS)
#
# Using the slow-corner period here gives STA enough margin on the divider
# and ADPOR shift register paths.

# ----------------------------------------------------------------------
# 1) Declare the ring-osc output as the primary internal clock.
# ----------------------------------------------------------------------
create_clock -name ring_osc_clk \
    -period 33.0 \
    [get_pins u_ro/u_nand/Y]

# ----------------------------------------------------------------------
# 2) Declare the divider output as a generated clock (RO / 64).
# ----------------------------------------------------------------------
create_generated_clock -name por_clk \
    -source [get_pins u_ro/u_nand/Y] \
    -divide_by 64 \
    [get_pins div_cnt_reg[5]/Q]

# ----------------------------------------------------------------------
# 3) Break the ring-osc combinational feedback loop for STA.
#    The NAND2.A input is the "loop closure" -- disable timing through it
#    so STA doesn't see an arc that revisits its own start point.
# ----------------------------------------------------------------------
set_disable_timing -from A -to Y [get_cells u_ro/u_nand]

# ----------------------------------------------------------------------
# 4) Mark the ring-osc cells and loop wires as do-not-touch in P&R.
#    The keep/dont_touch attributes in RTL handle synthesis; this is the
#    physical-flow equivalent.
# ----------------------------------------------------------------------
set_dont_touch [get_cells u_ro/u_nand]
set_dont_touch [get_cells u_ro/u_inv_*]
set_dont_touch [get_cells u_ro/g_dly[*].u_dly]

# ----------------------------------------------------------------------
# 5) Output transition / driving-cell defaults.
# ----------------------------------------------------------------------
set_max_transition 1.5
set_load 0.05 [all_outputs]
