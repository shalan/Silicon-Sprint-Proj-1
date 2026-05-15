from uart_apb import APBMaster
from clock_gen import ClockGen
from freq_counter import FreqCounter
from reset_ctrl import ResetCtrl
from chip_cmds import (ChipCtrl, Sercom,
                       MON_FLL, MON_RC16M, MON_RC500K, MON_CLK, MON_CLK48M)
from test_suite import run_tests
import utime

apb = None
clk = None
fcnt = None
rst = None
chip = None
sercom = None

def init():
    global apb, clk, fcnt, rst, chip, sercom
    apb = APBMaster(id=0, baud=57600, tx=0, rx=1)
    clk = ClockGen(pin=2, target_mhz=12)
    fcnt = FreqCounter()
    rst = ResetCtrl(pin=8)
    chip = ChipCtrl(apb)
    sercom = Sercom(apb)

def cmd_help(args):
    print("""Commands:
  read <addr>              - APB read (e.g. read 0x0000)
  write <addr> <data>      - APB write (e.g. write 0x0000 0x00000101)
  dump <addr> [count]      - Read count words (default 16)
  reset [width_ms]         - Pulse external reset (default 10ms)
  clock on [freq_mhz]     - Start xclk (default 12 MHz)
  clock off                - Stop xclk
  fll on [div]             - Enable FLL (default div=0x40)
  fll off                  - Disable FLL
  fll bypass [0|1]         - Set/clear FLL bypass
  fll div <val>            - Set FLL divider
  rc16m on|off             - Enable/disable RC 16M
  rc500k on|off            - Enable/disable RC 500k
  monitor on <name>        - Enable monitor (fll/rc16m/rc500k/clk48m/all)
  monitor off <name>       - Disable monitor
  monitor div [fll] [rc16m] [rc500k] - Set monitor dividers
  freq [name] [gate_ms]    - Measure frequency (fll/rc16m/rc500k/clk48m/all)
  counters                 - Read internal frequency counters
  status                   - Read status register
  ctrl                     - Read CTRL register
  usb status               - Check USB configured pin
  usb write <hex_bytes>    - Write bytes to USB FIFO
  irq                      - Read chip-level IRQ status (0x2010)
  sercom read <off>        - sercom register read  (off = 0x000..0x1FF)
  sercom write <off> <val> - sercom register write
  sercom loopback [hex]    - Internal USART loopback round-trip
  test                     - Run bring-up test suite
  help                     - This message""")

def cmd_read(args):
    if not args:
        print("Usage: read <addr>")
        return
    addr = int(args[0], 0)
    val = apb.read(addr)
    print("0x%08X = 0x%08X" % (addr, val))

def cmd_write(args):
    if len(args) < 2:
        print("Usage: write <addr> <data>")
        return
    addr = int(args[0], 0)
    data = int(args[1], 0)
    apb.write(addr, data)
    print("0x%08X <- 0x%08X" % (addr, data))

def cmd_dump(args):
    if not args:
        print("Usage: dump <addr> [count]")
        return
    addr = int(args[0], 0)
    count = int(args[1], 0) if len(args) > 1 else 16
    for i in range(count):
        a = addr + i * 4
        val = apb.read(a)
        print("  0x%08X: 0x%08X" % (a, val))

def cmd_reset(args):
    width = int(args[0], 0) if args else 10
    rst.pulse(width)
    print("Reset pulsed (%d ms)" % width)

def cmd_clock(args):
    if not args:
        print("Clock: %s" % ("running %d MHz" % clk.target_mhz if clk.is_running() else "stopped"))
        return
    if args[0] == "on":
        mhz = int(args[1], 0) if len(args) > 1 else 12
        clk.target_mhz = mhz
        clk.start()
        print("Clock started: %d MHz" % mhz)
    elif args[0] == "off":
        clk.stop()
        print("Clock stopped")
    else:
        print("Usage: clock on [freq_mhz] | clock off")

def cmd_fll(args):
    if not args:
        print("Usage: fll on|off|bypass|div")
        return
    if args[0] == "on":
        div = int(args[1], 0) if len(args) > 1 else 0x40
        chip.fll_on(div=div)
        print("FLL enabled, div=0x%02X" % div)
    elif args[0] == "off":
        chip.fll_off()
        print("FLL disabled")
    elif args[0] == "bypass":
        en = True if len(args) < 2 or args[1] != "0" else False
        chip.fll_bypass(en)
        print("FLL bypass: %s" % ("ON" if en else "OFF"))
    elif args[0] == "div":
        if len(args) < 2:
            print("Usage: fll div <val>")
            return
        chip.fll_div(int(args[1], 0))
        print("FLL div = 0x%02X" % int(args[1], 0))
    else:
        print("Usage: fll on|off|bypass|div")

def cmd_rc16m(args):
    if not args:
        print("Usage: rc16m on|off")
        return
    if args[0] == "on":
        chip.rc16m_on()
        print("RC16M enabled")
    elif args[0] == "off":
        chip.rc16m_off()
        print("RC16M disabled")

def cmd_rc500k(args):
    if not args:
        print("Usage: rc500k on|off")
        return
    if args[0] == "on":
        chip.rc500k_on()
        print("RC500K enabled")
    elif args[0] == "off":
        chip.rc500k_off()
        print("RC500K disabled")

def _mon_bit(name):
    return {"fll": MON_FLL, "rc16m": MON_RC16M, "rc500k": MON_RC500K,
            "clk48m": MON_CLK48M, "clk": MON_CLK}.get(name)

def cmd_monitor(args):
    if len(args) < 2:
        print("Usage: monitor on|off <name|all>  or  monitor div [fll] [rc16m] [rc500k]")
        return
    if args[0] == "on":
        if args[1] == "all":
            chip.monitor_enable_all()
            print("All monitors enabled")
        else:
            bit = _mon_bit(args[1])
            if bit is None:
                print("Unknown: %s (fll/rc16m/rc500k/clk48m/clk/all)" % args[1])
                return
            chip.monitor_enable(bit)
            print("Monitor %s enabled" % args[1])
    elif args[0] == "off":
        if args[1] == "all":
            chip.monitor_disable_all()
            print("All monitors disabled")
        else:
            bit = _mon_bit(args[1])
            if bit is None:
                print("Unknown: %s" % args[1])
                return
            chip.monitor_disable(bit)
            print("Monitor %s disabled" % args[1])
    elif args[0] == "div":
        fll = int(args[1], 0) if len(args) > 1 else 0xFFFF
        rc16m = int(args[2], 0) if len(args) > 2 else 0xFFFF
        rc500k = int(args[3], 0) if len(args) > 3 else 0xFFFF
        chip.monitor_set_div(fll, rc16m, rc500k)
        print("Monitor dividers: FLL=0x%04X RC16M=0x%04X RC500K=0x%04X" % (fll, rc16m, rc500k))

def cmd_freq(args):
    name = args[0] if args else "all"
    gate = int(args[1], 0) if len(args) > 1 else 1000
    if name == "all":
        results = fcnt.measure_all(gate)
        for n, f in results.items():
            print("  %s: %s" % (n, "%d Hz" % f if isinstance(f, int) else f))
    else:
        try:
            hz = fcnt.measure(name, gate)
            print("%s: %d Hz" % (name, hz))
        except Exception as e:
            print("Error: %s" % e)

def cmd_counters(args):
    cnts = chip.read_freq_counters()
    print("FLL edges:  %d" % cnts["fll"])
    print("RC16M edges: %d" % cnts["rc16m"])
    print("REF edges:   %d" % cnts["ref"])

def cmd_status(args):
    s = chip.read_status()
    flags = []
    if s & 0x001: flags.append("fll_active")
    if s & 0x002: flags.append("fll48m_active")
    if s & 0x004: flags.append("rc16m_active")
    if s & 0x008: flags.append("rc500k_active")
    if s & 0x010: flags.append("fll_en")
    if s & 0x020: flags.append("rc16m_en")
    if s & 0x040: flags.append("rc500k_en")
    if s & 0x400: flags.append("fll_bypass")
    print("STATUS = 0x%08X [%s]" % (s, ", ".join(flags)))

def cmd_ctrl(args):
    c = chip.read_ctrl()
    print("CTRL = 0x%08X" % c)
    print("  fll_en=%d rc16m_en=%d rc500k_en=%d sel_mon=%d fll_bypass=%d usb_rst_n=%d" % (
        c & 1, (c >> 1) & 1, (c >> 2) & 1, (c >> 3) & 7, (c >> 6) & 1, (c >> 8) & 1))

def cmd_usb(args):
    if not args:
        print("Usage: usb status | write <hex_bytes>")
        return
    if args[0] == "status":
        print("USB configured: %s" % chip.usb_configured())
    elif args[0] == "write":
        if len(args) < 2:
            print("Usage: usb write <hex_bytes> (e.g. 48656C6C6F)")
            return
        data = bytes.fromhex(args[1])
        chip.usb_fifo_write(data)
        print("Wrote %d bytes to USB FIFO" % len(data))

def cmd_test(args):
    run_tests(apb, chip, rst, clk, fcnt, sercom=sercom)

def cmd_irq(args):
    irq = chip.irq_pending()
    print("IRQ status[0x2010] = 0x%08X  sercom=%s" %
          (irq["raw"], irq["sercom"]))

def cmd_sercom(args):
    if not args:
        print("Usage: sercom read <off> | write <off> <val> | loopback [hex]")
        return
    sub = args[0]
    if sub == "read" and len(args) >= 2:
        off = int(args[1], 0)
        print("sercom 0x%03X = 0x%08X" % (off, sercom.read(off)))
    elif sub == "write" and len(args) >= 3:
        off = int(args[1], 0); val = int(args[2], 0)
        sercom.write(off, val)
        print("sercom 0x%03X <- 0x%08X" % (off, val))
    elif sub == "loopback":
        payload = bytes.fromhex(args[1]) if len(args) >= 2 else None
        ok, sent, recv, info = sercom.usart_loopback_test(payload=payload)
        print("baud target=%d actual=%d (CLKDIV=%d)" %
              (info["baud_target"], info["baud_actual"], info["clkdiv"]))
        print("sent     = %s" % sent.hex())
        print("received = %s" % recv.hex())
        print("result   = %s" % ("PASS" if ok else "FAIL"))
    else:
        print("Usage: sercom read <off> | write <off> <val> | loopback [hex]")

COMMANDS = {
    "help": cmd_help,
    "read": cmd_read,
    "write": cmd_write,
    "dump": cmd_dump,
    "reset": cmd_reset,
    "clock": cmd_clock,
    "fll": cmd_fll,
    "rc16m": cmd_rc16m,
    "rc500k": cmd_rc500k,
    "monitor": cmd_monitor,
    "freq": cmd_freq,
    "counters": cmd_counters,
    "status": cmd_status,
    "ctrl": cmd_ctrl,
    "usb": cmd_usb,
    "irq": cmd_irq,
    "sercom": cmd_sercom,
    "test": cmd_test,
}

def process_line(line):
    line = line.strip()
    if not line or line.startswith("#"):
        return
    parts = line.split()
    cmd = parts[0].lower()
    args = parts[1:]
    if cmd in COMMANDS:
        try:
            COMMANDS[cmd](args)
        except Exception as e:
            print("Error: %s" % e)
    else:
        print("Unknown command: %s (type 'help')" % cmd)
