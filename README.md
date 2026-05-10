# USB CDC Test Chip with FLL, RC Oscillators, and AttoIO

A test chip RTL for Sky130 HD integrating USB CDC, a fractional-N DLL (FLL),
on-chip RC oscillators, an AttoIO I/O processor (RV32EC + DFFRAM), and a
UART-to-APB debug bridge. Targets the
[Caravel](https://github.com/efabless/caravel) user project harness.

## Architecture

```
                    ┌─────────────────────────────────────────────────────────────┐
 xclk (6-12 MHz)  ──┤  fracn_dll FLL ──► 96 MHz ──► /2 ──► 48 MHz (USB)           │
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
                    │ 6-12 MHz │ macro pin    │
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
| **USB**       | `usb_clk`   | 48 MHz     | `usb_cdc`                         | 2-bit sync to xclk (apb_status freq counters); async FIFO to xclk (apb_usb_fifo) |
| **APB**       | `xclk`      | 6-12 MHz   | `uart_apb_sys`, `apb_clk_ctrl`, `apb_status`, `apb_usb_fifo` | - |
| **AttoIO**    | `xclk`      | 6-12 MHz   | `attoio_macro` (`sysclk`)         | None (same as APB) |
| **FLL**       | `fll_clk_96m` | 96 MHz  | `dll`, `dll_controller`           | Internal to FLL; output sampled via /2 and monitor dividers |
| **RC 16M**    | `rc16m_clk`  | 16 MHz   | `sky130_ef_ip__rc_osc_16M`        | 2-bit sync to xclk (monitor + status) |
| **RC 500k**   | `rc500k_clk` | 500 kHz  | `sky130_ef_ip__rc_osc_500k`       | 2-bit sync to xclk (monitor + status) |
| **clk (green)** | `clk`     | unknown    | Caravel macro pin                 | Monitor mux only |

#### USB Clock Sources

The `usb_clk` is selected by a glitch-free `clk_mux_2to1` controlled by `fll_bypass` (CTRL[6]):

| `fll_bypass` | USB Clock Source | Frequency     | Use Case            |
|-------------|------------------|---------------|---------------------|
| 0 (default) | FLL /2           | 48 MHz        | Normal operation    |
| 1           | xclk (direct)    | 6-12 MHz      | Debug / bypass FLL  |

FLL divider (`FLL_DIV` register, `0x04`): 8-bit `{5-bit integer, 3-bit fractional (eighths)}`.
Target: `96 MHz = xclk * div`. Examples:
- xclk=12 MHz, div=8.0 (`0x40`) -> 96 MHz
- xclk=10 MHz, div=9.6 (`0x4C`) -> 96 MHz
- xclk=6 MHz, div=16.0 (`0x80`) -> 96 MHz

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
| 2   | xclk        | input     | External clock (6-12 MHz)       |
| 3   | usb_dp      | bidir     | USB D+                          |
| 4   | usb_dm      | bidir     | USB D-                          |
| 5   | usb_pu      | output    | USB pullup (ext 1.5k to D+)     |
| 6   | fll_mon     | output    | FLL output / N                  |
| 7   | rc16m_mon   | output    | 16M RC OSC / M                  |
| 8   | rc500k_mon  | output    | 500k RC OSC / K                 |
| 9   | usb_cfg     | output    | USB configured status           |
| 10  | clk48m_mon  | output    | 48 MHz FLL/2 clock (gated)     |
| 11-14 | unused    | -         | Unused                          |

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

Baud = `xclk_freq / (BAUD_DIV x 16)`.

UART tolerance with 16x oversampling: **+/-3%** max (theoretical +/-5%, safe limit +/-2-3%).

#### 6 MHz xclk

| DIV | Actual | Nearest Standard | Error |
|-----|--------|-------------------|-------|
| 4 | 93750 | 115200 | -18.62% |
| 5 | 75000 | 57600 | +30.21% |
| 6 | 62500 | 57600 | +8.51% |
| 7 | 53571 | 57600 | -6.99% |
| 8 | 46875 | 38400 | +22.07% |
| 9 | 41667 | 38400 | +8.51% |
| **10** | **37500** | **38400** | **-2.34%** |
| 11 | 34091 | 38400 | -11.22% |
| 12 | 31250 | 38400 | -18.62% |
| 13 | 28846 | 38400 | -24.88% |
| 14 | 26786 | 19200 | +39.51% |
| 15 | 25000 | 19200 | +30.21% |

**Recommended: DIV=10 -> 38400 baud** (only option within tolerance)

#### 12 MHz xclk

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

### Synthesis Results (28,288 cells)

| Component             | Cells |
|-----------------------|------:|
| DFFRAM (256x32 SRAM)  | 14,094 |
| AttoRV32 (RV32EC)     | 2,698  |
| SIE (USB)             | 1,007  |
| apb_status            | 919    |
| AttoIO GPIO (16 pads) | 975    |
| ctrl_endp (USB)       | 613    |
| dll_controller (FLL)  | 522    |
| DFFRAM (32x32 SRAM)   | 1,623  |
| AttoIO timer          | 1,053  |
| in_fifo (USB)         | 446    |
| out_fifo (USB)        | 392    |
| AttoIO memmux         | 290    |
| apb_clk_ctrl          | 346    |
| AttoIO macro (wiring) | 328    |
| cmd_parser (UART)     | 325    |
| UART APB master       | 65     |
| Other (div, mux, etc) | ~1,180 |
| **Total**             | **28,288** |

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
