# Pico Test Probe — Setup & Usage Guide

## What You Need

- Raspberry Pi Pico (or Pico W) with soldered headers
- USB cable (micro-B or USB-C depending on Pico version)
- Jumper wires (at least 12)
- PC (macOS, Linux, or Windows)
- Breadboard (recommended)

## 1. Flash MicroPython Firmware

### Step 1: Download the firmware

Download the latest MicroPython UF2 file for the Pico:
- **Pico**: [https://micropython.org/download/RPI_PICO/](https://micropython.org/download/RPI_PICO/)
- **Pico W**: [https://micropython.org/download/RPI_PICO_W/](https://micropython.org/download/RPI_PICO_W/)

Look for a file named like `RPI_PICO-20240105-v1.22.1.uf2`.

### Step 2: Enter bootloader mode

1. Unplug the Pico from USB
2. **Hold down the BOOTSEL button** on the Pico (the only button on the board)
3. While holding BOOTSEL, plug the Pico into USB
4. Release BOOTSEL

The Pico appears as a USB mass storage drive named `RPI-RP2`.

### Step 3: Flash

Copy the `.uf2` file onto the `RPI-RP2` drive:

**macOS:**
```bash
cp RPI_PICO-*.uf2 /Volumes/RPI-RP2/
```

**Linux:**
```bash
cp RPI_PICO-*.uf2 /media/$USER/RPI-RP2/
```

**Windows:** Drag and drop the `.uf2` file onto the RPI-RP2 drive.

The Pico automatically reboots into MicroPython. The drive disappears — that's normal.

## 2. Install Tools on Your PC

### Option A: mpremote (recommended, command-line)

```bash
pip install mpremote
```

Verify the Pico is detected:
```bash
mpremote ls
```
You should see the Pico's internal filesystem (usually just `/boot.py`).

### Option B: Thonny IDE (beginner-friendly)

1. Download [Thonny](https://thonny.org/) for your OS
2. Open Thonny → Tools → Options → Interpreter
3. Select "MicroPython (Raspberry Pi Pico)"
4. Thonny will auto-detect the Pico

## 3. Copy the Test Probe Software

### With mpremote:

```bash
cd sw/pico_tester
mpremote cp main.py :
mpremote cp cli.py :
mpremote cp uart_apb.py :
mpremote cp clock_gen.py :
mpremote cp freq_counter.py :
mpremote cp reset_ctrl.py :
mpremote cp chip_cmds.py :
mpremote cp test_suite.py :
```

Or all at once:
```bash
mpremote cp *.py :
```

### With Thonny:

1. Open each `.py` file in Thonny
2. File → Save As → "Raspberry Pi Pico" device
3. Make sure `main.py` is saved with that exact name (it auto-runs on boot)

### Verify files are on the Pico:

```bash
mpremote ls
```
You should see all 8 `.py` files.

## 4. Wiring

Connect the Pico to the test chip using jumper wires:

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
```

### Chip-side pads not currently wired to the Pico

These exist on the chip but the Pico-tester does not exercise them
directly. Hook them up if you want to scope/measure or interact with
the on-chip peripheral through the package pins.

| Chip pad        | Signal       | Notes |
|-----------------|--------------|-------|
| `gpio_bot[12]`  | `adpor_mon`  | All-digital PoR pulse (~20.5 µs at TT). Pure monitor output; wire to a free GPIO + scope channel to watch the pulse on every power cycle. |
| `gpio_rt[2..7]` | `sercom_pad[0..5]` | nc_sercom USART/SPI/I2C pads. Wire up to drive a real serial device, **or** use the internal-loopback self-test (`sercom loopback`) which needs no external pins. |
| `gpio_top[0..13]` | `attoio_gpio[13:0]` | AttoIO GPIOs (driven by the on-chip RV32EC firmware). Not used by the Pico tester. |
| `gpio_bot[13..14]`, `gpio_rt[0,1,8]` | spare | Unused. |

**Important:**
- Connect GND between Pico and chip first
- Do NOT connect 3V3 unless the chip has no other power source
- Keep wires short (< 15 cm) for the xclk (12 MHz) signal
- The UART lines do not need level shifters (both sides are 3.3V)

### Breadboard Layout Tips

```
        Pico              Chip breakout
      ┌─────────┐       ┌──────────────┐
 GP0──┤TX       ├──GP9──►│ usb_pu       │
 GP1──┤RX       ├──GP8──►│ ext_rst_n    │
 GP2──┤PIO0     ├──GP7◄──│ rc500k_mon   │
      │         ├──GP6◄──│ rc16m_mon    │
      │  USB    ├──GP5◄──│ fll_mon      │
      │  to PC  ├──GP4◄──│ clk48m_mon   │
      │         ├──GP3◄──│ usb_cfg      │
  GND─┤GND      ├──GP0──►│ uart_rx      │
      └────┬────┘    GP1◄──│ uart_tx      │
           │              │              │
           └───── GND ────┤ GND          │
                          └──────────────┘
```

## 5. Using the CLI

### Connect to the Pico REPL

**macOS/Linux:**
```bash
# The Pico appears as /dev/tty.usbmodem* (macOS) or /dev/ttyACM0 (Linux)
screen /dev/tty.usbmodem* 115200
# or:
minicom -b 115200 -D /dev/tty.usbmodem*
# or via mpremote:
mpremote
```

**Windows:** Use PuTTY or Thonny's shell at 115200 baud.

**Or via mpremote:**
```bash
mpremote
```

### If main.py doesn't start automatically

Press `Ctrl+D` to soft-reboot the Pico, or:
```python
>>> import main
```

### You should see:

```
==================================================
  USB CDC Test Chip — Pico Debug Probe
==================================================
Initializing...
Ready. Type 'help' for commands.

>
```

## 6. Command Reference

### Basic APB Access

```
> read 0x0000                  # Read CTRL register
> write 0x0000 0x00000101      # Write CTRL register
> dump 0x6000 4                # Read 4 words starting at 0x6000
```

### Clock Control

```
> clock on                     # Start 12 MHz xclk via PIO
> clock on 6                   # Start 6 MHz xclk instead
> clock off                    # Stop xclk
> clock                        # Show clock status
```

### FLL Control

```
> fll on                       # Enable FLL (div=0x40 = 8.0)
> fll on 0x80                  # Enable FLL with div=16.0 (for 6 MHz xclk)
> fll off                      # Disable FLL
> fll bypass                   # Bypass FLL (xclk directly to USB)
> fll bypass 0                 # Clear bypass
> fll div 0x40                 # Change FLL divider only
```

FLL divider format: 8-bit `{5-bit integer, 3-bit fractional (eighths)}`
- `0x40` = 8.0 → 96 MHz from 12 MHz xclk
- `0x80` = 16.0 → 96 MHz from 6 MHz xclk
- `0x4C` = 9.75 → 97.5 MHz from 10 MHz xclk

### RC Oscillators

```
> rc16m on                     # Enable 16 MHz RC oscillator
> rc16m off                    # Disable
> rc500k on                    # Enable 500 kHz RC oscillator
> rc500k off                   # Disable
```

### Monitor Outputs

```
> monitor on fll               # Enable FLL 96M monitor
> monitor on rc16m             # Enable RC 16M monitor
> monitor on rc500k            # Enable RC 500k monitor
> monitor on clk48m            # Enable 48M monitor
> monitor on all               # Enable all monitors
> monitor off all              # Disable all monitors
> monitor div 9999 9999 9999   # Set divider for FLL/RC16M/RC500K
```

Divider formula: `f_out = f_in / (2 × (div + 1))`
- FLL 96 MHz with div=9999 → 96M/20000 = 4,800 Hz
- RC 16 MHz with div=9999 → 16M/20000 = 800 Hz

### Frequency Measurement

```
> freq fll                     # Measure FLL monitor (1s gate)
> freq rc16m                   # Measure RC 16M monitor
> freq all                     # Measure all enabled monitors
> freq fll 500                 # Measure with 500ms gate (faster, less accurate)
```

**Note:** The monitor must be enabled and have a divider set before measuring.
For high-frequency outputs (96 MHz, 48 MHz), use a large divider to bring
the frequency below the PIO counter's maximum rate (~5 MHz).

### Status & Diagnostics

```
> status                       # Read status register (decoded)
> ctrl                         # Read CTRL register (decoded)
> counters                     # Read internal frequency counters
> usb status                   # Check if USB is configured
```

### USB FIFO

```
> usb write 48656C6C6F         # Write "Hello" bytes to USB FIFO
```

### Reset

```
> reset                        # Pulse ext_rst_n for 10ms
> reset 100                    # Pulse ext_rst_n for 100ms
```

### IRQ status (chip-level aggregator)

```
> irq                          # Read 0x2010
                               # -> "IRQ status[0x2010] = 0x00000000 attoio=False sercom=False"
```

Bit 0 = AttoIO `irq_to_host`, bit 1 = nc_sercom `irq_o`. Poll-only; bits
clear when the source peripheral deasserts.

### nc_sercom (USART / SPI / I2C, APB slot 4 at 0x8000)

```
> sercom read 0x000             # Read CR
> sercom read 0xFFC             # Read ID register
> sercom write 0x020 0xDEADBEEF # Write IM
> sercom loopback               # Internal USART loopback round-trip
> sercom loopback 5AA500FF      # Loopback with custom payload (hex)
```

The `sercom loopback` command needs **no external wiring**: it sets the
LOOPBACK bit in MODECFG (0x123 internal), enables USART mode at
115 200 baud (CLKDIV ≈ 6), pushes the bytes through DR, and reads them
back through the same DR.

### Automated Testing

```
> test                         # Run 12-test bring-up suite
```

This will:
1. Reset the chip
2. Start xclk
3. Enable FLL
4. Enable RC oscillators
5. Check frequency counters
6. Measure monitor outputs
7. Test FLL bypass
8. Test USB FIFO
9. Test external reset
10. Verify AttoIO register access
11. Read IRQ status (expect 0 at idle)
12. nc_sercom reachability + USART loopback round-trip

## 7. Typical Bring-Up Sequence

```
> reset                        # Clean start
> clock on                     # Start 12 MHz xclk
> read 0x0000                  # Verify CTRL defaults (0x00000100)
> fll on                       # Enable FLL
> status                       # Check FLL active
> rc16m on                     # Enable RC oscillators
> rc500k on
> monitor div 9999 9999 9999   # Set monitor dividers
> monitor on all               # Enable all monitors
> freq all                     # Measure all frequencies
> counters                     # Check internal counters
> usb status                   # Check USB configured
> read 0x670C                  # Read AttoIO version
> dump 0x6000 16               # Dump AttoIO registers
> test                         # Run full test suite
```

## 8. Troubleshooting

### Pico not detected

- Try a different USB cable (some are power-only)
- Hold BOOTSEL while plugging in to re-flash firmware
- Check `ls /dev/tty.usbmodem*` (macOS) or `ls /dev/ttyACM*` (Linux)

### "timeout waiting for status"

- Check UART wiring: GP0→chip uart_rx, GP1←chip uart_tx
- Make sure xclk is running (`clock on`) — the UART bridge needs a clock
- Try `reset` first — chip might be in a bad state
- Verify GND is connected between Pico and chip

### Frequency measurement returns 0

- Make sure the monitor is enabled (`monitor on fll`)
- Set a divider (`monitor div 9999`)
- Check wiring from chip monitor pin to Pico GP pin
- Some monitors only work when the source is enabled (FLL, RC OSC)

### "chip returned error (0xEE)"

- The APB address might be invalid
- The target slave might not exist at that address
- Try a known-good address like `read 0x0000`

### mpremote tips

```bash
mpremote                    # Connect to REPL
mpremote ls                 # List files on Pico
mpremote cp file.py :       # Copy file to Pico
mpremote rm :file.py        # Delete file from Pico
mpremote run script.py      # Run a script without copying it
mpremote reset              # Soft reset the Pico
```

## 9. Updating the Software

If you make changes to the Python files:

```bash
cd sw/pico_tester
mpremote cp *.py :
```

Then press `Ctrl+D` in the REPL to soft-reboot, or:

```python
>>> import machine
>>> machine.reset()
```

## 10. Notes

- UART baud rate is 57600 (matching chip's BAUD_DIV=13 @ 12 MHz xclk)
- Frequency counter uses PIO edge counting — accurate to ±1 count
- Clock generator uses PIO — output is a clean 50% duty cycle square wave
- ext_rst_n is active-low; Pico drives it high (deasserted) by default
- The Pico's USB REPL runs at 115200 baud (separate from the UART to the chip)
- All signal levels are 3.3V — no level shifters needed
