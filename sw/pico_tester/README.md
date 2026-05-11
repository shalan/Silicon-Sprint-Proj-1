# Pico Test Probe — Wiring Diagram

## Pin Connections

```
  RPi Pico RP2040                Test Chip (Caravel pads)
  ───────────────                ────────────────────────
  GP0  (UART0 TX)  ───────────►  gpio_bot[0]  uart_rx
  GP1  (UART0 RX)  ◄───────────  gpio_bot[1]  uart_tx
  GP2  (PIO0 SM0)  ───────────►  gpio_bot[2]  xclk (12 MHz)
  GP3  (GPIO in)   ◄───────────  gpio_bot[9]  usb_cfg
  GP4  (PIO SM)    ◄───────────  gpio_bot[10] clk48m_mon
  GP5  (PIO SM)    ◄───────────  gpio_bot[6]  fll_mon
  GP6  (PIO SM)    ◄───────────  gpio_bot[7]  rc16m_mon
  GP7  (PIO SM)    ◄───────────  gpio_bot[8]  rc500k_mon
  GP8  (GPIO out)  ───────────►  gpio_bot[11] ext_rst_n
  GP9  (GPIO in)   ◄───────────  gpio_bot[5]  usb_pu

  GND              ────────────  GND
  3V3(OUT)         ───────────►  vccd1 (if powered from Pico)
```

## Setup

1. Flash MicroPython firmware on the Pico (rp2-pico-20240105-v1.22.1.uf2 or later)
2. Copy all `.py` files to the Pico:
   ```
   mpremote cp *.py :
   # or use Thonny IDE
   ```
3. Connect USB cable to PC, open serial terminal (115200 8N1):
   ```
   minicom -b 115200 -D /dev/ttyACM0
   # or: screen /dev/ttyACM0 115200
   ```
4. `main.py` starts automatically. Type `help` for commands.

## Quick Start

```
> clock on                # Start 12 MHz xclk
> fll on                  # Enable FLL (96 MHz, div=0x40)
> status                  # Check FLL active
> freq all                # Measure all monitor outputs
> monitor on all          # Enable all monitor outputs
> freq fll                # Measure FLL frequency
> counters                # Read internal frequency counters
> read 0x670C             # Read AttoIO version register
> reset                   # Pulse external reset
> test                    # Run full bring-up test suite
```

## Notes

- UART baud rate is 57600 (matching chip's BAUD_DIV=13 @ 12 MHz xclk)
- Frequency counter uses PIO edge counting with 1s gate window
- Clock generator uses PIO at system clock / (2 * target_mhz * 5)
  For 12 MHz output with 120 MHz system clock, divider = 2.0 (exact)
- ext_rst_n is active-low; Pico drives it high (deasserted) by default
