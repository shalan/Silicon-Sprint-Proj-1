import utime


def run_tests(apb, chip, reset, clk, fcnt, sercom=None):
    results = []

    def check(name, cond):
        status = "PASS" if cond else "FAIL"
        results.append((name, status))
        print("  [%s] %s" % (status, name))

    print("=== Chip Bring-Up Tests ===\n")

    print("--- Test 1: System Reset ---")
    reset.pulse(50)
    ctrl = chip.read_ctrl()
    check("CTRL default = 0x00000100", ctrl == 0x00000100)

    print("--- Test 2: Clock Generation ---")
    clk.start()
    utime.sleep_ms(100)
    check("xclk running at %d MHz" % clk.target_mhz, clk.is_running())

    print("--- Test 3: FLL Enable ---")
    chip.fll_on(div=0x40)
    utime.sleep_ms(50)
    ctrl = chip.read_ctrl()
    check("FLL enabled (CTRL[0]=1)", ctrl & 1 == 1)

    print("--- Test 4: RC Oscillators ---")
    chip.rc16m_on()
    chip.rc500k_on()
    utime.sleep_ms(10)
    ctrl = chip.read_ctrl()
    check("RC16M enabled (CTRL[1]=1)", ctrl & 2 == 2)
    check("RC500K enabled (CTRL[2]=1)", ctrl & 4 == 4)

    print("--- Test 5: Frequency Counters (internal) ---")
    utime.sleep_ms(100)
    cnts = chip.read_freq_counters()
    print("    FLL edges:  %d" % cnts["fll"])
    print("    RC16M edges: %d" % cnts["rc16m"])
    print("    REF edges:   %d" % cnts["ref"])
    check("REF counter ~1000000", 900000 < cnts["ref"] < 1100000)

    print("--- Test 6: Monitor Outputs ---")
    chip.monitor_enable_all()
    chip.monitor_set_div(fll_div=9999, rc16m_div=9999, rc500k_div=9999)
    utime.sleep_ms(100)

    try:
        fll_hz = fcnt.measure("fll", gate_ms=500)
        print("    FLL monitor:  %d Hz (expected ~4800)" % fll_hz)
        check("FLL monitor active", fll_hz > 100)
    except Exception as e:
        check("FLL monitor: %s" % e, False)

    try:
        rc16m_hz = fcnt.measure("rc16m", gate_ms=500)
        print("    RC16M monitor: %d Hz (expected ~800)" % rc16m_hz)
        check("RC16M monitor active", rc16m_hz > 50)
    except Exception as e:
        check("RC16M monitor: %s" % e, False)

    print("--- Test 7: FLL Bypass ---")
    chip.fll_bypass(True)
    utime.sleep_ms(10)
    ctrl = chip.read_ctrl()
    check("FLL bypass (CTRL[6]=1)", ctrl & 0x40 == 0x40)
    chip.fll_bypass(False)

    print("--- Test 8: USB FIFO Write ---")
    try:
        chip.usb_fifo_write(b"Hello")
        check("USB FIFO write OK", True)
    except Exception as e:
        check("USB FIFO write: %s" % e, False)

    print("--- Test 9: External Reset ---")
    chip.fll_on()
    utime.sleep_ms(10)
    reset.pulse(10)
    utime.sleep_ms(20)
    ctrl = chip.read_ctrl()
    check("Ext reset clears CTRL", ctrl == 0x00000100)

    print("--- Test 10: AttoIO Register Access ---")
    try:
        ver = apb.read(0x670C)
        print("    AttoIO VERSION = 0x%08X" % ver)
        check("AttoIO accessible", True)
    except Exception as e:
        check("AttoIO: %s" % e, False)

    # ------------------------------------------------------------------
    # New: IRQ status aggregator (0x2010). At rest, no peripheral should
    # be asserting an IRQ, so the register reads 0.
    # ------------------------------------------------------------------
    print("--- Test 11: IRQ status idle ---")
    try:
        irq = chip.irq_pending()
        print("    IRQ status[0x2010] = 0x%08X" % irq["raw"])
        check("IRQ idle at reset", irq["raw"] == 0x00000000)
    except Exception as e:
        check("IRQ status: %s" % e, False)

    # ------------------------------------------------------------------
    # New: nc_sercom reachability + internal USART loopback round-trip.
    # Uses the LOOPBACK bit in MODECFG so no external wiring is needed.
    # ------------------------------------------------------------------
    print("--- Test 12: nc_sercom reachable + USART loopback ---")
    if sercom is None:
        check("sercom driver not wired in", False)
    else:
        try:
            # IM register is full 32-bit R/W — quick reachability ping.
            sercom.write(0x020, 0xCAFEBEEF)
            got = sercom.read(0x020)
            check("sercom IM R/W (0x8020)", got == 0xCAFEBEEF)
            sercom.write(0x020, 0x00000000)

            ok, sent, recv, info = sercom.usart_loopback_test(
                payload=b"\x5A\xA5\x00\xFF\x12\x34\x56\x78",
                baud=115200,
            )
            print("    sercom USART: baud target=%d actual=%d (CLKDIV=%d)" %
                  (info["baud_target"], info["baud_actual"], info["clkdiv"]))
            print("    sent     = %s" % sent.hex())
            print("    received = %s" % recv.hex())
            check("USART loopback round-trip", ok)
        except Exception as e:
            check("sercom: %s" % e, False)

    clk.stop()

    passed = sum(1 for _, s in results if s == "PASS")
    failed = sum(1 for _, s in results if s == "FAIL")
    print("\n=== Results: %d passed, %d failed ===" % (passed, failed))
    if failed:
        print("FAILED tests:")
        for name, status in results:
            if status == "FAIL":
                print("  - %s" % name)
    return failed == 0
