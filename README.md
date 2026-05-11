# USB CDC Test Chip with FLL, RC Oscillators, and AttoIO

A test chip RTL for Sky130 HD integrating USB CDC, a fractional-N DLL (FLL),
on-chip RC oscillators, an AttoIO I/O processor (RV32EC + DFFRAM), and a
UART-to-APB debug bridge. Targets the
[Caravel](https://github.com/efabless/caravel) user project harness.

## Architecture

```
                    ┌─────────────────────────────────────────────────────────────┐
 xclk (12 MHz)   ──┤  fracn_dll FLL ──► 96 MHz ──► /2 ──► 48 MHz (USB)           │
 GPIO pin           │                                                             │
                    │  ┌──────────┐                                               │
clk (green macro)───┤  │ UART APB │──► APB Splitter ──► S0: clk_ctrl (0x0000)     │
                    │  │  Bridge  │──►              ──► S1: status   (0x2000)     │
  uart_rx ◄─────────┤  │ (xclk)   │──►              ──► S2: usb_fifo (0x4000)     │
  uart_tx ─────────►┤  └──────────┘                  ──► S3: AttoIO   (0x6000)    │
                    │                                        ┌──────────────────┐ │
                    │                                        │ RV32EC + 1KB RAM │ │
                    │                                        │ 16 GPIO, SPI,    │ │
                    │                                        │ Timer, WDT       │ │
                    │                                        └──────────────────┘ │
                    │  RC OSC 16 MHz ──► monitor output                           │
                    │  RC OSC 500 kHz ─► monitor output                           │
                    └─────────────────────────────────────────────────────────────┘
```

### Clock Architecture

```
                          Clock Sources
                    ┌──────────┬──────────────┐
                    │ xclk     │ clk (green)  │
                    │ 12 MHz   │ macro pin    │
                    └────┬─────┴──────────────┘
                         │          │
          ┌──────────────┤          │
          │              │          │
          ▼              │          │
   ┌──────────────┐      │          │
   │  fracn_dll   │      │          │
   │  (FLL)       │      │          │
   │  ref=xclk    │      │          │
   │  div={5i,3f} │      │          │
   └──────┬───────┘      │          │
          │              │          │
          ▼              │          │
      96 MHz             │          │
      (clk_96m)          │          │
          │              │          │
          ├──── /2 (toggle FF)      │
          │              │          │
          ▼              ▼          │
      48 MHz          xclk          │
      (clk_48m)                     │
          │              │          │
          ▼              │          │
   ┌──────────────┐      │          │
   │ clk_mux_2to1 │◄─────┤          │
   │ sel=fll_byp  │      │          │
   └──────┬───────┘      │          │
          │              │          │
          ▼              │          │
       usb_clk           │          │
    (48M or xclk)        │          │
          │              │          │
          ▼              ▼          ▼
   ┌──────────┐   ┌──────────────────────┐
   │ USB CDC  │   │ APB Domain (xclk)    │
   │ clk_i    │   │                      │
   │ app_clk_i│   │  UART APB Master     │
   └──────────┘   │  APB Splitter        │
                  │  clk_ctrl (S0)       │
                  │  status   (S1)       │
                  │  usb_fifo (S2)       │
                  │  AttoIO   (S3)       │
                  └──────┬───────────────┘
                         │
                    ┌────┤
                    │    │
                    ▼    ▼
               sysclk  clk_iop
               (=xclk) (=xclk/1)
                    │
                    ▼
               AttoIO Macro
               (RV32EC + I/O)


    ┌──────────────────────────────────────────────┐
    │            Monitor / Measure                 │
    │                                              │
    │  Sources:          6:1 Mux (sel_mon[2:0])    │
    │  [0] clk (green)     │                       │
    │  [1] xclk            ├──► clk_div ──► GPIO   │
    │  [2] fll_clk_96m     │                       │
    │  [3] fll_clk_48m     │                       │
    │  [4] rc16m_clk       │                       │
    │  [5] rc500k_clk      │                       │
    │                                              │
    │ Dedicated monitor outputs (clk_div per):     │
    │    fll_96m  ──► clk_div ──► gpio_bot[6]      │
    │    rc16m    ──► clk_div ──► gpio_bot[7]      │
    │    rc500k   ──► clk_div ──► gpio_bot[8]      │
    │    fll_48m  ────────────► gpio_bot[10]       │
    │                                              │
    │ Frequency counters (apb_status, xclk domain) │
    │    FLL 96M edges  ──► 2-bit sync ──► count   │
    │    RC 16M edges   ──► 2-bit sync ──► count   │
    │    xclk edges     ───────────────► count     │
    └──────────────────────────────────────────────┘
```

#### Clock Domains

| Domain        | Clock        | Frequency  | Modules                           | Crossing        |
|---------------|-------------|------------|-----------------------------------|-----------------|
| **USB**       | `usb_clk`   | 48 MHz     | `usb_cdc` (clk_i)                 | clk_i ↔ app_clk_i: IP-internal 2-stage sync (safe CDC); app_clk_i=xclk ↔ apb_usb_fifo: IP handles CDC via double-buffer handshake |
| **APB**       | `xclk`      | 12 MHz     | `uart_apb_sys`, `apb_clk_ctrl`, `apb_status`, `apb_usb_fifo` | - |
| **AttoIO**    | `xclk`      | 12 MHz     | `attoio_macro` (`sysclk`)         | None (same as APB) |
| **AttoIO core** | `clk_iop` | 6 MHz (xclk/2) | `AttoRV32`, SPI, timer, WDT   | Known phase (2:1 from xclk) |
| **FLL**       | `fll_clk_96m` | 96 MHz  | `dll`, `dll_controller`           | Internal to FLL; output sampled via /2 and monitor dividers |
| **RC 16M**    | `rc16m_clk`  | 16 MHz   | `sky130_ef_ip__rc_osc_16M`        | 2-bit sync to xclk (monitor + status) |
| **RC 500k**   | `rc500k_clk` | 500 kHz  | `sky130_ef_ip__rc_osc_500k`       | 2-bit sync to xclk (monitor + status) |
| **clk (green)** | `clk`     | unknown    | Caravel macro pin                 | Monitor mux only |

#### USB Clock Sources

The `usb_clk` is selected by a glitch-free `clk_mux_2to1` controlled by `fll_bypass` (CTRL[6]):

| `fll_bypass` | USB Clock (`clk_i`) | App Clock (`app_clk_i`) | Use Case            |
|-------------|---------------------|-------------------------|---------------------|
| 0 (default) | FLL /2 = 48 MHz     | xclk (12 MHz)           | Normal operation    |
| 1           | xclk (direct)       | xclk (12 MHz)           | Debug / bypass FLL  |

`app_clk_i` is always `xclk` (same as APB domain), so the USB FIFO interface is
synchronous to APB. The `usb_cdc` IP handles the clk_i ↔ app_clk_i crossing
internally with 2-stage synchronizers and double-buffer handshake
(`APP_CLK_FREQ=12`, `USE_APP_CLK=1`).

#### Monitor Outputs

| GPIO Pin     | Source          | Divider Register    | Enable Register     |
|-------------|-----------------|---------------------|---------------------|
| `gpio_bot[6]`  | FLL 96 MHz   | `FLL_MON_DIV` 0x0C  | `MON_EN[0]` 0x1C   |
| `gpio_bot[7]`  | RC 16 MHz     | `RC16M_MON_DIV` 0x10 | `MON_EN[1]` 0x1C  |
| `gpio_bot[8]`  | RC 500 kHz    | `RC500K_MON_DIV` 0x14 | `MON_EN[2]` 0x1C  |
| `gpio_bot[10]` | FLL 48 MHz    | - (direct)           | `MON_EN[4]` 0x1C   |

The 6:1 monitor mux output can also be divided and routed to a GPIO via `CLK_MON_DIV` (0x18) and `MON_EN[3]` (0x1C).

Divider formula: `f_out = f_in / (2 * (div_ratio + 1))`.

### GPIO Pin Map

#### Bottom Edge (15 pins, managed by project RTL)

| Pin | Signal      | Direction | Description                     |
|-----|-------------|-----------|---------------------------------|
| 0   | uart_rx     | input     | UART receive (APB bridge)       |
| 1   | uart_tx     | output    | UART transmit (APB bridge)      |
| 2   | xclk        | input     | External clock (12 MHz)         |
| 3   | usb_dp      | bidir     | USB D+                          |
| 4   | usb_dm      | bidir     | USB D-                          |
| 5   | usb_pu      | output    | USB pullup (ext 1.5k to D+)     |
| 6   | fll_mon     | output    | FLL output / N                  |
| 7   | rc16m_mon   | output    | 16M RC OSC / M                  |
| 8   | rc500k_mon  | output    | 500k RC OSC / K                 |
| 9   | usb_cfg     | output    | USB configured status           |
| 10  | clk48m_mon  | output    | 48 MHz FLL/2 clock (gated)     |
| 11  | ext_rst_n   | input     | Active-low external reset      |
| 12-14 | unused    | -         | Unused                          |

#### Top Edge (14 pins, managed by AttoIO)

| Pin | Signal          | Description                        |
|-----|-----------------|------------------------------------|
| 0-13 | gpio[13:0]    | AttoIO GPIO (per-pin dir + padctl) |

#### Right Edge (pins 14-15, managed by AttoIO)

| Pin | Signal    | Description                     |
|-----|-----------|---------------------------------|
| 14  | gpio[14]  | AttoIO GPIO                     |
| 15  | gpio[15]  | AttoIO GPIO                     |

### APB Address Map (via UART bridge, 8 KB slots)

| Address   | Slave      | Description                          |
|-----------|------------|--------------------------------------|
| `0x0000`  | clk_ctrl   | FLL/RC enables, dividers, muxes, USB pad |
| `0x2000`  | status     | Frequency counters, sync'd status    |
| `0x4000`  | usb_fifo   | USB CDC FIFO (read/write bytes)      |
| `0x6000+` | AttoIO     | RV32EC I/O processor (16 GPIO, SPI, timer, WDT) |

### Reset State

#### Control Register Defaults (apb_clk_ctrl)

| Control Bit | Default | Effect |
|-------------|---------|--------|
| `fll_en` | 0 | FLL off |
| `fll_bypass` | 0 | USB mux selects FLL/2 (dead since FLL off) |
| `usb_rst_n` | 1 | USB out of reset (but no clock) |
| `rc16m_en` | 0 | RC 16M off |
| `rc500k_en` | 0 | RC 500k off |
| All `mon_en` | 0 | All monitor outputs disabled |
| `fll_div` | 0 | FLL divider = 0 |
| `usb_dp/dn/pu_dm` | 110 | USB pads in input mode |

#### Subsystem State Out of Reset

| Subsystem | Clock | Active? |
|-----------|-------|---------|
| UART APB bridge | xclk (12 MHz) | Yes |
| apb_clk_ctrl | xclk | Yes |
| apb_status | xclk | Yes (no clocks to count yet) |
| apb_usb_fifo | xclk | Yes |
| AttoIO (APB, SRAMs) | xclk | Yes |
| AttoIO (RV32EC core) | clk_iop (6 MHz) | Yes — CPU executing from reset vector |
| USB CDC (`clk_i`) | none (FLL off) | No clock, stuck |
| USB CDC (`app_clk_i`) | xclk | Has clock but `clk_i` dead |
| FLL | off | No output |
| RC 16M / 500k | off | No output |
| Monitor outputs | — | All gated off |

### Register Maps

#### clk_ctrl (0x0000)

| Offset | Name | Bits | Default | Description |
|--------|------|------|---------|-------------|
| `0x00` | CTRL | [0] | 0 | `fll_en` — FLL enable |
| | | [1] | 0 | `rc16m_en` — 16M RC OSC enable |
| | | [2] | 0 | `rc500k_en` — 500k RC OSC enable |
| | | [5:3] | 000 | `sel_mon` — Monitor mux select (6:1) |
| | | [6] | 0 | `fll_bypass` — Bypass FLL, xclk to USB |
| | | [7] | - | Reserved |
| | | [8] | 1 | `usb_rst_n` — USB reset (active-low) |
| `0x04` | FLL_DIV | [7:0] | 0x00 | FLL feedback divider {5-bit integer, 3-bit fractional (eighths)} |
| `0x08` | FLL_DCO | [0] | 0 | `fll_dco` — DCO mode enable |
| | | [27:2] | 0 | `fll_ext_trim` — DCO external trim [25:0] |
| `0x0C` | FLL_MON_DIV | [15:0] | 0x0000 | FLL 96M output monitor divider |
| `0x10` | RC16M_MON_DIV | [15:0] | 0x0000 | RC 16M monitor divider |
| `0x14` | RC500K_MON_DIV | [15:0] | 0x0000 | RC 500k monitor divider |
| `0x18` | CLK_MON_DIV | [15:0] | 0x0000 | Monitor mux output divider |
| `0x1C` | MON_EN | [0] | 0 | `fll_mon_en` — FLL 96M monitor enable |
| | | [1] | 0 | `rc16m_mon_en` — RC 16M monitor enable |
| | | [2] | 0 | `rc500k_mon_en` — RC 500k monitor enable |
| | | [3] | 0 | `clk_mon_en` — Mux monitor enable |
| | | [4] | 0 | `clk48m_mon_en` — FLL 48M monitor enable |
| `0x20` | USB_PAD | [2:0] | 110 | `usb_dp_dm` — D+ pad drive mode |
| | | [5:3] | 110 | `usb_dn_dm` — D- pad drive mode |
| | | [8:6] | 110 | `usb_pu_dm` — PU pad drive mode |

#### status (0x2000, read-only)

| Offset | Name | Bits | Description |
|--------|------|------|-------------|
| `0x00` | STATUS | [0] | `fll_active` — FLL 96M output toggling |
| | | [1] | `fll_clk48m_active` — FLL/2 output toggling |
| | | [2] | `rc16m_active` — RC 16M toggling |
| | | [3] | `rc500k_active` — RC 500k toggling |
| | | [4] | `fll_en_reg` — FLL enable (echo) |
| | | [5] | `rc16m_en_reg` — RC 16M enable (echo) |
| | | [6] | `rc500k_en_reg` — RC 500k enable (echo) |
| | | [9:7] | `sel_mon` — Monitor mux select (echo) |
| | | [10] | `fll_bypass` — FLL bypass (echo) |
| `0x04` | FLL_CNT | [31:0] | FLL 96M edges in last 1M xclk cycles |
| `0x08` | RC16M_CNT | [31:0] | RC 16M edges in last 1M xclk cycles |
| `0x0C` | REF_CNT | [31:0] | xclk edges in last 1M xclk cycles (should be ~1M) |

#### usb_fifo (0x4000)

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x00` | FIFO_DATA | R/W | Read: next USB OUT byte. Write: push byte to USB IN. |
| `0x04` | FIFO_STATUS | RO | [0]: OUT_FIFO_NOT_EMPTY (data available), [1]: IN_FIFO_NOT_FULL (can write) |

#### AttoIO (0x6000+, 11-bit internal address)

AttoIO has an internal memory-mapped architecture. The host APB interface accesses
a 2 KB address space (`PADDR[10:0]`). See [AttoIO documentation](https://github.com/shalan/AttoIO) for the full internal register map.

Key host-accessible registers (within the `0x700` MMIO page):

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| `0x700` | DOORBELL_H2C | W1S (host) | Host-to-core doorbell |
| `0x704` | DOORBELL_C2H | R/W1C (host) | Core-to-host doorbell |
| `0x708` | IOP_CTRL | R/W | IOP control register |
| `0x70C` | VERSION | RO | Version {major, minor, patch, 0} |
| `0x710` | PINMUX_LO | R/W | Pads 0-7 pinmux, 2 bits each |
| `0x714` | PINMUX_HI | R/W | Pads 8-15 pinmux, 2 bits each |

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

Baud = `xclk_freq / (BAUD_DIV x 16)`. With xclk = 12 MHz:

UART tolerance with 16x oversampling: **+/-3%** max (theoretical +/-5%, safe limit +/-2-3%).

| DIV | Actual | Nearest Standard | Error |
|-----|--------|-------------------|-------|
| 4 | 187500 | 230400 | -18.62% |
| 5 | 150000 | 115200 | +30.21% |
| 6 | 125000 | 115200 | +8.51% |
| 7 | 107143 | 115200 | -6.99% |
| 8 | 93750 | 115200 | -18.62% |
| 9 | 83333 | 57600 | +44.68% |
| 10 | 75000 | 57600 | +30.21% |
| 11 | 68182 | 57600 | +18.37% |
| 12 | 62500 | 57600 | +8.51% |
| **13** | **57692** | **57600** | **+0.16%** |
| 14 | 53571 | 57600 | -6.99% |
| 15 | 50000 | 57600 | -13.19% |

**Recommended: DIV=13 -> 57600 baud** (near-zero error, highest standard rate)

## Synthesis

Requires [Yosys](https://github.com/YosysHQ/yosys) and Sky130 PDK.

```bash
export PDK_ROOT=/path/to/sky130A
make synth
```

### Synthesis Results (28,374 cells)

| Component             | Cells |
|-----------------------|------:|
| DFFRAM (256x32 SRAM)  | 14,096 |
| AttoRV32 (RV32EC)     | 2,706  |
| SIE (USB)             | 999    |
| apb_status            | 919    |
| AttoIO GPIO (16 pads) | 977    |
| ctrl_endp (USB)       | 610    |
| in_fifo (USB, CDC)    | 491    |
| out_fifo (USB, CDC)   | 447    |
| dll_controller (FLL)  | 522    |
| DFFRAM (32x32 SRAM)   | 1,623  |
| AttoIO timer          | 1,053  |
| AttoIO memmux         | 290    |
| apb_clk_ctrl          | 347    |
| AttoIO macro (wiring) | 328    |
| cmd_parser (UART)     | 321    |
| apb_splitter          | 178    |
| UART APB master       | 65     |
| Other (div, mux, etc) | ~1,102 |
| **Total**             | **28,374** |

## Submodules

| Submodule | Source |
|-----------|--------|
| `fracn_dll/` | [RTimothyEdwards/fracn_dll](https://github.com/RTimothyEdwards/fracn_dll) |
| `uart_apb_master/` | [shalan/uart_apb_master](https://github.com/shalan/uart_apb_master) |
| `usb_cdc/` | [ulixxe/usb_cdc](https://github.com/ulixxe/usb_cdc) |
| `AttoIO/` | [shalan/AttoIO](https://github.com/shalan/AttoIO) |
| `frv32/` | [shalan/frv32](https://github.com/shalan/frv32) |
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
project_macro.v        # Top-level integration (rtl/)
fll_top.v              # FLL wrapper (dll + /2 divider)
fll_sim.v              # Behavioral FLL model (simulation only)
apb_clk_ctrl.v         # APB clock control registers
apb_status.v           # APB status / frequency counters
apb_usb_fifo.v         # APB to USB CDC FIFO bridge
clk_mux_2to1.v         # Glitch-free 2:1 clock mux
clk_div.v              # Configurable clock divider
sky130_stubs.v         # Behavioral stubs for Sky130 cells (sim only)
sky130_ef_ip__rc_osc_16M.v  # Behavioral RC 16M model (sim only)
sky130_ef_ip__rc_osc_500k.v # Behavioral RC 500k model (sim only)
tb/
  tb_project_macro.v   # Testbench (20 tests)
sdc/
  project_macro.sdc    # SDC timing constraints
synth/
  synth.ys             # Yosys synthesis script (primary)
  synth.tcl            # Yosys TCL synthesis script (deprecated)
  sta.tcl              # OpenSTA timing analysis
Makefile               # Build system (make sim, make synth)
```

## License

Apache-2.0
