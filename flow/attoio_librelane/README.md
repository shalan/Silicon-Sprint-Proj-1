# attoio_wrap — project-level hardening override

Project-specific LibreLane / OpenLane config for `attoio_wrap`, a thin
wrapper (rtl/attoio_wrap.v) that instantiates the upstream `attoio_macro`
and hides its unused `hp0/hp1/hp2` host-peripheral bundles (144 ports
dropped). The hardened macro therefore has a clean **two-side** pin
layout with nothing on E or W.

## Floorplan

```
                ┌──────────────────────────────┐
   gpio_top ───►│  N (84 pins:                 │
   pad ring     │     pad_in[13:0],            │
                │     pad_out[13:0],           │
                │     pad_oe[13:0],            │
                │     pad_dm[41:0])            │
                │                              │
                │       attoio_wrap            │
                │  (wrapper -> attoio_macro,   │
                │   RV32 + 1KB DFFRAM)         │
                │                              │
                │  S (88 pins: APB + clk/rst) ◄│─── apb_splitter
                └──────────────────────────────┘
                       (E,W: empty)
```

Each pad's signals are kept contiguous on the N face (`in`, `out`, `oe`,
then its 3 `dm` bits) to mirror the per-pad bundle ordering used on
project_macro's top edge -- abutment becomes one-to-one.

This makes the integration step at project_macro level trivial: all
GPIO routes go upward to the top pad ring, all APB routes go downward
to the bus, no crossing.

## Files

| File | Purpose |
|---|---|
| `config.json` | LibreLane config; reuses AttoIO RTL from the submodule via `dir::../../AttoIO/...` paths. |
| `pin_order.cfg` | Constrains pad_* → N, APB+clk+rst+irq → S, hp_* → E/W. |
| `attoio_pnr.sdc` | P&R constraints (copied from `AttoIO/flow/librelane/`). |
| `attoio_signoff.sdc` | Sign-off STA constraints. |

The upstream `AttoIO/flow/librelane/` is left untouched so the AttoIO
submodule remains usable standalone.

## Running

With the existing OpenLane 2.2.9 in the nix store:

```bash
export PDK_ROOT=$HOME/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
/nix/store/70vzqyyj1nvg3gxdi553xmcrajjydknm-python3.12-openlane-2.2.9/bin/openlane \
    --pdk-root "$PDK_ROOT" \
    --run-tag attoio-2side \
    flow/attoio_librelane/config.json
```

Outputs land in `runs/attoio-2side/` next to the config.

## Floorplan sizing notes

- Pin count constraint: N side carries 176 pins (pad_in[15:0],
  pad_out[15:0], pad_oe[15:0], pad_ctl[127:0]). At a typical 4 µm
  pitch in the M2/M3 layer, the macro needs ≥ ~700 µm of width on
  the N face.
- Cell area: AttoIO with the two DFFRAMs synthesises into ~22 k
  cells at ~5 µm²/cell average → ~110 000 µm² of cell area. At
  `FP_CORE_UTIL = 70`, the core box should be ~155 000 µm².
- `FP_ASPECT_RATIO = 1.8` gives roughly a 530 × 295 µm core, which
  satisfies both constraints with some margin. Bump if routing
  congests on the N face.
