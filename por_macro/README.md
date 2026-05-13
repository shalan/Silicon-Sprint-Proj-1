# por_macro — All-digital Power-on-Reset (characterization macro)

Self-contained PoR generator for Sky130. Adapted from
[shalan/ADPoR](https://github.com/shalan/ADPoR), wrapped with a free-running
ring oscillator and a clock divider so the macro needs **no external clock
and no external reset** — it bootstraps purely from VDD ramp.

The output is intended to be routed to a GPIO pad for scope/LA monitoring
only; it is **not** used as a system reset elsewhere in the chip.

## Block diagram

```
        enable
          │
          ▼
       ┌─────┐     ┌─────┐     ┌────────────────────────┐
       │NAND2│──►──│ INV │──►─ ... ─►──│ 15× clkdlybuf4s50_1 │──┐
       └─────┘     └─────┘             └────────────────────────┘ │
          ▲                                                       │
          └───────────────────────────────────────────────────────┘
                              loop (5 inversions, ~62 MHz nominal)
                                  │ ro_clk
                                  ▼
                          ┌──────────────┐
                          │  /64 ripple  │   por_clk (~1 MHz)
                          │   divider    │────────────────┐
                          └──────────────┘                │
                                                          ▼
                          ┌───────────────────────────────────────┐
                          │  ADPOR (4 × 24-bit shift registers,   │
                          │   2 fed with '1, 2 fed with '0;        │
                          │   AND of four comparators = rst_n)    │
                          └───────────────────────────────────────┘
                                              │
                                              ▼  por_n_out
                          (also fed back as enable = ~por_n_out)
```

## Pulse-width budget

`Pulse = LENGTH × T_POR_CLK = 24 × (T_RO × 64)`

| Corner | RO     | POR-clk  | Pulse width |
|--------|--------|----------|-------------|
| FF     | ~130 MHz | ~2.0 MHz | **~12 µs** |
| TT     | ~62 MHz  | ~1.0 MHz | **~25 µs** (nominal) |
| SS     | ~30 MHz  | ~0.5 MHz | **~51 µs** |

Behavioral simulation produces **~24 µs** (matches TT prediction).

## Cell budget (pre-layout)

| Block              | Cells |
|--------------------|-------|
| Ring oscillator    | 20    |
| /64 divider        | ~8    |
| ADPOR shift regs   | 96 (4 × 24 dfrtp) |
| ADPOR comparators  | ~16   |
| **Total**          | **~140–150** |

## Self-disable / power profile

Once `por_n_out` deasserts (goes HIGH), the feedback inverts to
`enable = 0`. The NAND2 in the ring osc forces a stable HIGH on the
loop and oscillation stops. With no clock, the divider and the ADPOR
shift registers freeze in their settled state, so `por_n_out` is
latched HIGH for the lifetime of the power supply.

Active duty cycle is therefore just the PoR pulse itself — typical
dynamic energy per power-on event is on the order of **a few nJ**;
quiescent current after that is leakage only.

The macro re-arms automatically on the next power cycle.

## Files

| File                  | Purpose |
|-----------------------|---------|
| `rtl/ring_osc.v`      | Enableable ring oscillator (behavioral sim model + ASIC notes) |
| `rtl/adpor.v`         | LENGTH-parameterized ADPOR shift-register PoR core |
| `rtl/por_macro.v`     | Top: RO + divider + ADPOR + enable feedback |
| `tb/tb_por_macro.v`   | Unit testbench (pulse-width window + RO-halt check) |
| `Makefile`            | Local `make sim` / `make lint` |
| `flow/librelane/`     | Hardening config (placeholder) |

## Ports

```verilog
module por_macro (
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    output por_n_out         // active-low PoR pulse
);
```

No inputs. The macro is fully self-contained.

## Simulation

```bash
make sim    # iverilog + vvp, prints PASS/FAIL summary, exits non-zero on failure
make lint   # iverilog -t null compile check
```

The DUT initialises every flop to `$random` under `\`SIMULATION` so the
behavior matches silicon coming out of power-on.

## ASIC hardening — important note

The RTL view of `ring_osc.v` is a **simulation-only behavioral model**. A
combinational inverter loop will not survive logic synthesis. The
hardening flow must replace this module's body with a hand-instantiated
gate-level netlist using `sky130_fd_sc_hd` primitives, with
`(* keep = "true" *)` and `(* dont_touch = "true" *)` attributes on every
instance and on the loop net. See `flow/librelane/` for the hardening
configuration (placeholder; to be filled in when the macro is taped out).

## Integration

The top-level [`project_macro`](../rtl/project_macro.v) instantiates this
macro and routes `por_n_out` to `gpio_bot[12]` for off-chip
characterization. The signal is **not** consumed by any internal logic.
