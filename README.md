# USB CDC Test Chip with FLL and RC Oscillators

A test chip RTL for Sky130 HD integrating USB CDC, a fractional-N DLL (FLL),
on-chip RC oscillators, and a UART-to-APB debug bridge. Targets the
[Caravel](https://github.com/efabless/caravel) user project harness.

## Architecture

```
                    ┌─────────────────────────────────────────┐
  xclk (6-12 MHz) ──┤  fracn_dll FLL ──► 96 MHz ──► /2 ──► 48 MHz (USB)  │
  GPIO pin           │                                         │
                    │  ┌──────────┐                            │
  clk (green macro)──┤  │ UART APB │──► APB Splitter ──► S0: clk_ctrl   │
                    │  │  Bridge  │──►                ──► S1: status     │
  uart_rx ◄─────────┤  │ (xclk)  │──►                ──► S2: usb_fifo   │
  uart_tx ──────────┤  └──────────┘                            │
                    │                                         │
                    │  RC OSC 16 MHz ──► monitor output        │
                    │  RC OSC 500 kHz ─► monitor output        │
                    └─────────────────────────────────────────┘
```

### Clock Architecture

| Clock      | Source                  | Frequency |
|------------|-------------------------|-----------|
| xclk       | GPIO pin (external)     | 6–12 MHz  |
| FLL 96 MHz | fracn_dll (xclk × N)   | 96 MHz    |
| USB 48 MHz | FLL/2 (toggle FF)       | 48 MHz    |
| RC 16 MHz  | On-chip RC oscillator   | 16 MHz    |
| RC 500 kHz | On-chip RC oscillator   | 500 kHz   |

### GPIO Pin Map (bottom edge, 15 pins)

| Pin | Signal      | Direction | Description                     |
|-----|-------------|-----------|---------------------------------|
| 0   | uart_rx     | input     | UART receive (APB bridge)       |
| 1   | uart_tx     | output    | UART transmit (APB bridge)      |
| 2   | xclk        | input     | External clock (6–12 MHz)       |
| 3   | usb_dp      | bidir     | USB D+                          |
| 4   | usb_dm      | bidir     | USB D-                          |
| 5   | usb_pu      | output    | USB pullup (ext 1.5kΩ to D+)   |
| 6   | fll_mon     | output    | FLL output ÷ N                  |
| 7   | rc16m_mon   | output    | 16M RC OSC ÷ M                  |
| 8   | rc500k_mon  | output    | 500k RC OSC ÷ K                 |
| 9   | usb_cfg     | output    | USB configured status           |
| 10  | clk48m_mon  | output    | 48 MHz FLL/2 clock (gated)     |
| 11–14 | spare    | —         | Unused                          |

### APB Address Map (via UART bridge, 8 KB slots)

| Address   | Slave      | Description                          |
|-----------|------------|--------------------------------------|
| `0x0000`  | clk_ctrl   | FLL/RC enables, dividers, muxes, USB pad |
| `0x2000`  | status     | Frequency counters, sync'd status    |
| `0x4000`  | usb_fifo   | USB CDC FIFO (read/write bytes)      |
| `0x6000+` | unused     | —                                    |

### UART Protocol

**Command**: `SYNC(0xDE, 0xAD) + CMD + ADDR[31:0] + DATA[31:0]` (write only)

**Response**: `STATUS + DATA[31:0]` (read only)

| CMD   | Operation |
|-------|-----------|
| `0x5A` | Read     |
| `0xA5` | Write    |

| STATUS | Meaning |
|--------|---------|
| `0xAC` | ACK     |
| `0xEE` | Error   |

## Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com) (`iverilog`).

```bash
make sim
```

This builds and runs the testbench. All 20 APB register tests should pass.

### UART Baud Rate

Baud = `xclk_freq / (BAUD_DIV × 16)`. Default: 12 MHz / (6 × 16) = 125000 baud.

## Submodules

| Submodule | Source |
|-----------|--------|
| `fracn_dll/` | [RTimothyEdwards/fracn_dll](https://github.com/RTimothyEdwards/fracn_dll) |
| `uart_apb_master/` | [shalan/uart_apb_master](https://github.com/shalan/uart_apb_master) |
| `usb_cdc/` | [ulixxe/usb_cdc](https://github.com/ulixxe/usb_cdc) |
| `sky130_ef_ip__rc_osc_16M/` | [RTimothyEdwards/sky130_ef_ip__rc_osc_16M](https://github.com/RTimothyEdwards/sky130_ef_ip__rc_osc_16M) |
| `sky130_ef_ip__rc_osc_500k/` | [RTimothyEdwards/sky130_ef_ip__rc_osc_500k](https://github.com/RTimothyEdwards/sky130_ef_ip__rc_osc_500k) |

Clone with submodules:
```bash
git clone --recursive <repo-url>
# or after cloning:
git submodule update --init --recursive
```

## Directory Structure

```
├── rtl/                    # Project RTL
│   ├── project_macro.v     # Top-level integration
│   ├── fll_top.v           # FLL wrapper (dll + /2 divider)
│   ├── fll_sim.v           # Behavioral FLL model (simulation only)
│   ├── apb_clk_ctrl.v      # APB clock control registers
│   ├── apb_status.v        # APB status / frequency counters
│   ├── apb_usb_fifo.v      # APB to USB CDC FIFO bridge
│   ├── clk_mux_2to1.v      # Glitch-free 2:1 clock mux
│   ├── clk_div.v           # Configurable clock divider
│   ├── sky130_stubs.v      # Behavioral stubs for Sky130 cells (sim only)
│   ├── sky130_ef_ip__rc_osc_16M.v   # Behavioral RC 16M model (sim only)
│   ├── sky130_ef_ip__rc_osc_500k.v  # Behavioral RC 500k model (sim only)
│   └── tb_project_macro.v  # Testbench
├── sdc/
│   └── project_macro.sdc   # SDC timing constraints
├── synth/
│   ├── synth.tcl           # Yosys synthesis script
│   └── sta.tcl             # OpenSTA timing analysis
├── Makefile                # Build system
└── .gitignore
```

## Synthesis (WIP)

Requires Sky130 PDK and Yosys:

```bash
export PDK_ROOT=/path/to/sky130A
yosys -c synth/synth.tcl
```

## License

Apache-2.0
