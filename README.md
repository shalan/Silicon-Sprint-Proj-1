# Silicon Sprint test chip — USB CDC, FLL, RC OSCs, AttoIO, nc_sercom, ADPoR

A Sky130 HD test-chip RTL integrating:

- USB CDC over a 48 MHz fractional-N PLL
- Two on-chip RC oscillators (16 MHz, 500 kHz)
- An AttoIO I/O processor (RV32EC + 1 KB DFFRAM + GPIO/SPI/timer/WDT)
- An nc_sercom multi-protocol serial peripheral (USART / SPI / I2C)
- An all-digital power-on-reset macro (ring osc + ADPOR), monitor-only
- UART-to-APB debug bridge

Targets the [Caravel](https://github.com/efabless/caravel) user-project harness.

## Architecture

```
                +------------------------------------------------------------+
 xclk (12 MHz)->|  fracn_dll FLL -- 96 MHz -- /2 -- 48 MHz (USB)             |
                |                                                            |
                |  +---------+                                               |
                |  | UART    |--> APB Splitter (8 slots, 8 KB each):         |
  uart_rx ----->|  | APB     |     S0 0x0000  clk_ctrl                       |
  uart_tx <-----|  | bridge  |     S1 0x2000  status (incl. IRQ @ 0x10)      |
                |  +---------+     S2 0x4000  usb_fifo                       |
                |                  S3 0x6000  AttoIO                         |
                |                  S4 0x8000  nc_sercom                      |
                |                                                            |
                |  AttoIO       : RV32EC + 1 KB DFFRAM, 14 GPIOs (top edge)  |
                |  nc_sercom    : USART/SPI/I2C, 6 pads (right edge)         |
                |  por_macro    : self-clocked ADPoR, monitor on bot[12]     |
                |  RC OSC 16M   : monitor output                             |
                |  RC OSC 500k  : monitor output                             |
                +------------------------------------------------------------+
```

### Clock domains

| Domain | Clock | Frequency | Modules | CDC |
|---|---|---|---|---|
| **APB / system** | `xclk` | 12 MHz | uart_apb_sys, apb_clk_ctrl, apb_status, apb_usb_fifo, nc_sercom (PCLK) | — |
| **USB** | `usb_clk` | 48 MHz | usb_cdc (clk_i) | IP-internal 2-stage sync; app_clk_i = xclk |
| **AttoIO macro** | `sysclk` | 12 MHz (=xclk) | attoio_macro | — |
| **AttoIO core** | `clk_iop` | 6 MHz (xclk/2) | AttoRV32, attoio_spi, attoio_timer, attoio_wdt | Known phase (2:1 from xclk) |
| **FLL** | `fll_clk_96m` | 96 MHz | dll (hard macro) | Internal; output sampled via /2 + dividers |
| **RC 16M** | `rc16m_clk` | ~16 MHz | sky130_ef_ip__rc_osc_16M | 2-stage sync to xclk |
| **RC 500k** | `rc500k_clk` | ~500 kHz | sky130_ef_ip__rc_osc_500k | 2-stage sync to xclk |
| **PoR ring osc** | internal | ~62 MHz | por_macro | Self-contained; gates off after PoR pulse |

`fll_bypass = 1` swaps the USB clock to direct `xclk` for debug.

### GPIO pin map (38 pads)

Every macro lives on a single edge of the pad ring (post-cleanup).

#### Bottom edge — `gpio_bot[14:0]` (15 pins)

| Pin | Dir | Signal | Source / sink |
|-----|-----|--------|---------------|
| 0 | in  | `uart_rx` | UART-APB bridge |
| 1 | out | `uart_tx` | UART-APB bridge |
| 2 | in  | `xclk` (12 MHz) | system clock input |
| 3 | inout | `usb_dp` | usb_cdc |
| 4 | inout | `usb_dm` | usb_cdc |
| 5 | out | `usb_pu` | usb_cdc (D+ pull-up enable, ext 1.5 kΩ) |
| 6 | out | `fll_mon` | FLL output ÷ N |
| 7 | out | `rc16m_mon` | RC 16M ÷ M |
| 8 | out | `rc500k_mon` | RC 500k ÷ K |
| 9 | out | `usb_configured` | usb_cdc status |
| 10 | out | `clk48m_mon` | gated FLL ÷ 2 |
| 11 | in  | `ext_rst_n` | external reset |
| 12 | out | `adpor_mon` | por_macro `por_n_out` (monitor only) |
| 13 | — | spare | — |
| 14 | — | spare | — |

#### Right edge — `gpio_rt[8:0]` (9 pins)

| Pin | Dir | Signal | Source / sink |
|-----|-----|--------|---------------|
| 0 | — | spare | — |
| 1 | — | spare | — |
| 2..7 | inout | `sercom_pad[0:5]` | nc_sercom (USART / SPI / I2C per mode) |
| 8 | — | spare | — |

#### Top edge — `gpio_top[13:0]` (14 pins)

| Pin | Dir | Signal | Source / sink |
|-----|-----|--------|---------------|
| 0..13 | inout | `attoio_gpio[13:0]` | attoio_macro (NGPIO=16 internally; [15:14] tied off, not pinned) |

### APB address map (UART bridge, 8 KB slots)

| Address | Slave | Description |
|---|---|---|
| `0x0000` | clk_ctrl | FLL/RC enables, dividers, monitor muxes, USB pad drive modes |
| `0x2000` | status   | Frequency counters, sync'd activity bits, **IRQ status @ 0x2010** |
| `0x4000` | usb_fifo | USB CDC FIFO byte read/write |
| `0x6000` | AttoIO   | RV32EC I/O processor (12-bit internal address space) |
| `0x8000` | nc_sercom | USART/SPI/I2C (12-bit internal address space) |

### IRQ status register (0x2010, read-only, sync'd to xclk)

| Bit | Source |
|---|---|
| 0 | `irq_attoio` — AttoIO `irq_to_host` |
| 1 | `irq_sercom` — nc_sercom `irq_o` |
| [31:2] | reserved (room for future peripherals) |

Poll-only. Bits self-clear when the source peripheral deasserts.

## Hard macros (black-boxed at project synth)

| Macro | Source | Notes |
|---|---|---|
| `dll` | fracn_dll (Efabless / RTE) | hardened LEF/LIB at integration |
| `sky130_ef_ip__rc_osc_16M` | RTimothyEdwards | analog GDS drop-in |
| `sky130_ef_ip__rc_osc_500k` | RTimothyEdwards | analog GDS drop-in |
| `por_macro` | local ([por_macro/](por_macro/)) | own LibreLane flow |

DFFRAM is **not** black-boxed — the behavioural RTL model is synthesised into standard-cell flops to remove the DFFRAM-compiler dependency (trade-off: +~16k cells).

## Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com).

```bash
make submodules     # one-time, after a fresh clone
make sim            # builds + runs tb/tb_apb_regs.v; expect 25/0 pass
make sim DUMP=1     # also dumps build/wave.vcd
make lint           # iverilog null-target compile check
```

The harness is split between `tb/include/tb_harness.vh` (DUT instance, clocks, reset, UART-APB driver, `check`, pass/fail counters with `$fatal` on failure) and per-test files `tb/tb_<name>.v`. `make sim TEST=<name>` selects the testbench module `tb_<name>` from `tb/tb_<name>.v`.

GitHub Actions runs lint + sim on every push (`.github/workflows/sim.yml`).

### UART baud rate

Baud = `xclk_freq / (BAUD_DIV × 16)`. With xclk = 12 MHz:

| DIV | Actual | Nearest standard | Error |
|---|---|---|---|
| **13** | **57 692** | **57 600** | **+0.16 %** (recommended) |
| 6 | 125 000 | 115 200 | +8.51 % |

## Synthesis

Requires [Yosys](https://github.com/YosysHQ/yosys) and the Sky130 PDK.

```bash
export PDK_ROOT=/path/to/sky130A
make synth
```

### Latest result — **32 192 cells**

| Block | Cells | % |
|---|---|---|
| AttoIO subsystem (RV32 + 2× DFFRAM + peripherals) | 22 673 | 70.4 % |
| └─ DFFRAM ×2 (synthesised as FFs) | 15 719 | 48.8 % |
| └─ AttoRV32 CPU | 2 683 | 8.3 % |
| └─ attoio_gpio/spi/timer/wdt/ctrl/memmux | 2 732 | 8.5 % |
| USB CDC (sie + endpoints + FIFOs + phy) | 2 945 | 9.1 % |
| nc_sercom (USART + SPI + I2C + FIFOs) | 1 504 | 4.7 % |
| apb_status | 929 | 2.9 % |
| apb_clk_ctrl | 347 | 1.1 % |
| UART-APB bridge | 243 | 0.8 % |
| Other glue (apb_usb_fifo, clk_div ×4, fll_top, etc.) | ~3 500 | 11.0 % |

Hard-macro instances preserved as opaque cells: 1× `dll`, 1× `por_macro`, 1× `sky130_ef_ip__rc_osc_16M`, 1× `sky130_ef_ip__rc_osc_500k`.

The macro-level hardening flow for `por_macro` lives at [por_macro/synth/](por_macro/synth/) and [por_macro/flow/librelane/](por_macro/flow/librelane/).

## UART debug protocol

**Command:** `0xDE 0xAD CMD ADDR[31:0] DATA[31:0]` (DATA omitted for reads)
**Response:** `STATUS DATA[31:0]` (DATA omitted for writes)

| CMD | Operation |
|---|---|
| `0x5A` | Read |
| `0xA5` | Write |

| STATUS | Meaning |
|---|---|
| `0xAC` | ACK |
| `0xEE` | Error |

## Repository layout

```
rtl/                  # project glue (project_macro, apb_*, fll_top, clk_*, sky130 stubs)
tb/                   # testbench harness + per-test files
  include/tb_harness.vh
  tb_apb_regs.v
sdc/                  # project-level SDC
synth/                # Yosys script + blackbox stubs + outputs
flow/                 # LibreLane configs
  project_macro_librelane/
  fracn_dll_librelane/
por_macro/            # All-digital PoR macro (own RTL, TB, synth, LibreLane flow)
  rtl/                  ring_osc.v, adpor.v, por_macro.v
  tb/                   tb_por_macro.v
  synth/                synth.ys (standalone)
  sdc/                  por_macro.sdc
  flow/librelane/       config.json + pin_order.cfg
nc_sercom/            # Vendored from github.com/nativechips/nc_lib (Apache-2.0)
  rtl/                  nc_sercom + protocol engines + nc_common
  UPSTREAM              provenance note
.github/workflows/
  sim.yml             # lint + sim on every push

# Submodules
AttoIO/                 # github.com/shalan/AttoIO
frv32/                  # github.com/shalan/attoRV32
usb_cdc/                # github.com/ulixxe/usb_cdc
uart_apb_master/        # github.com/shalan/uart_apb_master
fracn_dll/              # github.com/RTimothyEdwards/fracn_dll
sky130_ef_ip__rc_osc_16M/    # github.com/RTimothyEdwards/sky130_ef_ip__rc_osc_16M
sky130_ef_ip__rc_osc_500k/   # github.com/RTimothyEdwards/sky130_ef_ip__rc_osc_500k
```

Clone with submodules:

```bash
git clone --recursive https://github.com/shalan/Silicon-Sprint-Proj-1
# or after cloning:
git submodule update --init --recursive
```

## License

Apache-2.0
