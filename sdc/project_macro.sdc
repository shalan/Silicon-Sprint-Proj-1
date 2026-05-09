# SDC constraints for project_macro (Sky130 HD synthesis)
#
# Clock architecture:
#   clk    : Green macro clock (slow monitor input) — not a system clock
#   xclk   : External clock from GPIO pin (6-12 MHz, user-selectable)
#            → UART APB bridge clock + FLL reference
#   FLL    : 96 MHz from fracn_dll (generated internally)
#   FLL/2  : 48 MHz for USB CDC (generated internally)
#   RC16M  : 16 MHz RC oscillator (analog IP)
#   RC500K : 500 kHz RC oscillator (analog IP)
#
# Primary clock: xclk at 12 MHz
# USB clock domain: 48 MHz from FLL/2 divider

# ---------------------------------------------------------------
# Primary input clock: xclk (6-12 MHz, default 12 MHz)
# ---------------------------------------------------------------
create_clock -name xclk -period 83.33 [get_ports gpio_bot_in[2]]
set_clock_transition 0.1 [get_clocks xclk]
set_clock_uncertainty 0.2 [get_clocks xclk]

# ---------------------------------------------------------------
# Slow monitor clock: clk from green macro (not a timing-critical path)
# ---------------------------------------------------------------
create_clock -name clk -period 1000 [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_clock_uncertainty 0.5 [get_clocks clk]

# ---------------------------------------------------------------
# Generated clocks from FLL
# ---------------------------------------------------------------
# FLL output: 96 MHz (xclk × 8 with default div=8.0)
create_generated_clock -name fll_clk96m \
    -master_pin [get_ports gpio_bot_in[2]] \
    -divide 1 \
    -source [get_ports gpio_bot_in[2]] \
    [get_pins u_fll_top/u_toggle_ff/Q]

# FLL/2 output: 48 MHz for USB
create_generated_clock -name fll_clk48m \
    -master_pin [get_pins u_fll_top/u_toggle_ff/Q] \
    -divide 2 \
    -source [get_pins u_fll_top/u_toggle_ff/Q] \
    [get_pins u_fll_top/clk_48m]

# USB clock from mux (when not in bypass)
create_generated_clock -name usb_clk \
    -master_pin [get_pins u_fll_top/clk_48m] \
    -divide 1 \
    -source [get_pins u_fll_top/clk_48m] \
    [get_pins u_usb_clk_mux/clk_out]

# FLL bypass mode: xclk directly to USB clock
create_generated_clock -name usb_clk_bypass \
    -master_pin [get_ports gpio_bot_in[2]] \
    -divide 1 \
    -source [get_ports gpio_bot_in[2]] \
    -add \
    [get_pins u_usb_clk_mux/clk_out]

# ---------------------------------------------------------------
# Clock domain crossings (false paths)
# ---------------------------------------------------------------
# xclk ↔ clk (independent clock domains)
set_clock_groups -asynchronous \
    -group [get_clocks xclk] \
    -group [get_clocks clk]

# xclk ↔ USB clock domain (CDC handled by clk_mux_2to1)
set_clock_groups -asynchronous \
    -group [get_clocks xclk] \
    -group [get_clocks usb_clk]

# FLL ↔ xclk (FLL reference is synchronously derived, but
# FLL output is from ring oscillator — treat as async)
set_clock_groups -asynchronous \
    -group [get_clocks fll_clk96m] \
    -group [get_clocks xclk]

# RC oscillator outputs are analog — no timing constraints
set_clock_groups -asynchronous \
    -group [get_clocks usb_clk] \
    -group [get_clocks clk]

# ---------------------------------------------------------------
# Input delays (relative to xclk)
# ---------------------------------------------------------------
# UART RX input (gpio_bot_in[0]) — asynchronous, generous setup
set_input_delay 20 -clock xclk [get_ports gpio_bot_in[0]]
set_false_path -from [get_ports gpio_bot_in[0]]

# ---------------------------------------------------------------
# Output delays (relative to xclk)
# ---------------------------------------------------------------
# UART TX output (gpio_bot_out[1])
set_output_delay 20 -clock xclk [get_ports gpio_bot_out[1]]

# Monitor outputs are not timing-critical
set_output_delay 50 -clock xclk [get_ports gpio_bot_out[6]]
set_output_delay 50 -clock xclk [get_ports gpio_bot_out[7]]
set_output_delay 50 -clock xclk [get_ports gpio_bot_out[8]]
set_output_delay 50 -clock xclk [get_ports gpio_bot_out[10]]

# USB pad outputs (48 MHz domain)
set_output_delay 5 -clock usb_clk [get_ports gpio_bot_out[3]]
set_output_delay 5 -clock usb_clk [get_ports gpio_bot_out[4]]
set_output_delay 5 -clock usb_clk [get_ports gpio_bot_out[5]]
set_output_delay 5 -clock usb_clk [get_ports gpio_bot_out[9]]

# ---------------------------------------------------------------
# Load assumptions
# ---------------------------------------------------------------
set_load 0.01 [all_inputs]
set_load 0.02 [all_outputs]
set_fanout_load 5 [all_outputs]

# ---------------------------------------------------------------
# Driving cell assumptions
# ---------------------------------------------------------------
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_1 [all_inputs]

# ---------------------------------------------------------------
# Don't touch analog IP instances
# ---------------------------------------------------------------
set_dont_touch [get_cells u_rc_osc_16M]
set_dont_touch [get_cells u_rc_osc_500K]
set_dont_touch [get_cells u_fll_top]

# ---------------------------------------------------------------
# USB CDC FIFO paths — not timing-critical from xclk domain
# ---------------------------------------------------------------
set_false_path -from [get_ports gpio_bot_in[3]]
set_false_path -from [get_ports gpio_bot_in[4]]
set_false_path -to [get_ports gpio_bot_out[14:11]]
