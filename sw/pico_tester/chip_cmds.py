from machine import Pin
import utime

PIN_USB_CFG = 3
PIN_USB_PU = 9

# ----------------------------------------------------------------------
# APB slot base addresses (8 KB slots, see project_macro pin map)
# ----------------------------------------------------------------------
ADDR_CTRL          = 0x0000
ADDR_FLL_DIV       = 0x0004
ADDR_FLL_DCO       = 0x0008
ADDR_FLL_MON_DIV   = 0x000C
ADDR_RC16M_MON_DIV = 0x0010
ADDR_RC500K_MON_DIV= 0x0014
ADDR_CLK_MON_DIV   = 0x0018
ADDR_MON_EN        = 0x001C
ADDR_USB_PAD       = 0x0020

ADDR_STATUS        = 0x2000
ADDR_FLL_CNT       = 0x2004
ADDR_RC16M_CNT     = 0x2008
ADDR_REF_CNT       = 0x200C
ADDR_IRQ_STATUS    = 0x2010   # chip-level IRQ aggregator (RO)

ADDR_USB_FIFO      = 0x4000
ADDR_ATTOIO        = 0x6000
ADDR_SERCOM        = 0x8000

# IRQ status register bits (at ADDR_IRQ_STATUS)
IRQ_ATTOIO         = 1 << 0
IRQ_SERCOM         = 1 << 1

MON_FLL    = 0
MON_RC16M  = 1
MON_RC500K = 2
MON_CLK    = 3
MON_CLK48M = 4


class ChipCtrl:
    def __init__(self, apb):
        self.apb = apb

    def read_ctrl(self):
        return self.apb.read(ADDR_CTRL)

    def write_ctrl(self, val):
        return self.apb.write(ADDR_CTRL, val)

    def fll_on(self, div=0x40):
        ctrl = self.apb.read(ADDR_CTRL)
        ctrl = (ctrl & ~(1 << 6)) | (1 << 0) | (1 << 8)
        self.apb.write(ADDR_CTRL, ctrl)
        self.apb.write(ADDR_FLL_DIV, div)

    def fll_off(self):
        ctrl = self.apb.read(ADDR_CTRL)
        ctrl = ctrl & ~(1 << 0)
        self.apb.write(ADDR_CTRL, ctrl)

    def fll_bypass(self, enable=True):
        ctrl = self.apb.read(ADDR_CTRL)
        if enable:
            ctrl = ctrl | (1 << 6)
        else:
            ctrl = ctrl & ~(1 << 6)
        self.apb.write(ADDR_CTRL, ctrl)

    def fll_div(self, div):
        self.apb.write(ADDR_FLL_DIV, div)

    def rc16m_on(self):
        ctrl = self.apb.read(ADDR_CTRL)
        self.apb.write(ADDR_CTRL, ctrl | (1 << 1))

    def rc16m_off(self):
        ctrl = self.apb.read(ADDR_CTRL)
        self.apb.write(ADDR_CTRL, ctrl & ~(1 << 1))

    def rc500k_on(self):
        ctrl = self.apb.read(ADDR_CTRL)
        self.apb.write(ADDR_CTRL, ctrl | (1 << 2))

    def rc500k_off(self):
        ctrl = self.apb.read(ADDR_CTRL)
        self.apb.write(ADDR_CTRL, ctrl & ~(1 << 2))

    def monitor_enable(self, mon_bit):
        en = self.apb.read(ADDR_MON_EN)
        self.apb.write(ADDR_MON_EN, en | (1 << mon_bit))

    def monitor_disable(self, mon_bit):
        en = self.apb.read(ADDR_MON_EN)
        self.apb.write(ADDR_MON_EN, en & ~(1 << mon_bit))

    def monitor_enable_all(self):
        self.apb.write(ADDR_MON_EN, 0x1F)

    def monitor_disable_all(self):
        self.apb.write(ADDR_MON_EN, 0x00)

    def monitor_set_div(self, fll_div=0xFFFF, rc16m_div=0xFFFF, rc500k_div=0xFFFF):
        self.apb.write(ADDR_FLL_MON_DIV, fll_div)
        self.apb.write(ADDR_RC16M_MON_DIV, rc16m_div)
        self.apb.write(ADDR_RC500K_MON_DIV, rc500k_div)

    def read_status(self):
        return self.apb.read(ADDR_STATUS)

    def read_freq_counters(self):
        fll = self.apb.read(ADDR_FLL_CNT)
        rc16m = self.apb.read(ADDR_RC16M_CNT)
        ref = self.apb.read(ADDR_REF_CNT)
        return {"fll": fll, "rc16m": rc16m, "ref": ref}

    # ------------------------------------------------------------------
    # Chip-level IRQ aggregator (0x2010, read-only).
    # ------------------------------------------------------------------
    def read_irq(self):
        return self.apb.read(ADDR_IRQ_STATUS)

    def irq_pending(self):
        v = self.read_irq()
        return {
            "attoio": bool(v & IRQ_ATTOIO),
            "sercom": bool(v & IRQ_SERCOM),
            "raw":    v,
        }

    def usb_fifo_write(self, data):
        for b in data:
            if isinstance(b, int):
                self.apb.write(ADDR_USB_FIFO, b)
            else:
                self.apb.write(ADDR_USB_FIFO, ord(b))

    def usb_fifo_read(self):
        return self.apb.read(ADDR_USB_FIFO)

    def usb_configured(self):
        pin = Pin(PIN_USB_CFG, Pin.IN)
        return pin() == 1


# ======================================================================
# nc_sercom — USART/SPI/I2C peripheral (APB slot 4, 0x8000)
# Register map mirrors nc_sercom/nc_sercom.reg.yaml v2.0.
# ======================================================================

# Standard front-end (0x000-0x0FF)
SERCOM_CR        = 0x000   # Control                                  R/W
SERCOM_SR        = 0x004   # Status                                   RO
SERCOM_DR        = 0x008   # Data                                     R/W
SERCOM_IM        = 0x020   # Interrupt Mask                           R/W
SERCOM_RIS       = 0x024   # Raw IRQ Status                           RO
SERCOM_MIS       = 0x028   # Masked IRQ Status                        RO
SERCOM_ICR       = 0x02C   # Interrupt Clear                          W
SERCOM_DMACR     = 0x040   # DMA Control                              R/W
SERCOM_TXLVL     = 0x044   # TX FIFO level                            RO
SERCOM_RXLVL     = 0x048   # RX FIFO level                            RO
SERCOM_FIFOCTRL  = 0x050   # FIFO control                             R/W
SERCOM_FIFOSTR   = 0x054   # FIFO status                              RO
# Extension space (0x100+)
SERCOM_MODECFG   = 0x100   # Mode configuration (loopback, pinout)    R/W
SERCOM_TIMING    = 0x104   # CLKDIV (baud)                            R/W
SERCOM_ADDR      = 0x108   # I2C address                              R/W
SERCOM_FRAME     = 0x10C   # USART frame config                       R/W
SERCOM_I2C_CMD   = 0x110
SERCOM_I2C_STAT  = 0x114
SERCOM_SPI_CS    = 0x118
SERCOM_SPI_CFG   = 0x11C
SERCOM_USART_ST  = 0x120
SERCOM_USART_RTO = 0x124
SERCOM_FEATURE   = 0xFF8
SERCOM_ID        = 0xFFC

# CR bits
CR_EN     = 1 << 0
CR_SRST   = 1 << 1
CR_MODE_USART = 0 << 2
CR_MODE_SPI   = 1 << 2
CR_MODE_I2C   = 2 << 2
CR_LPMEN  = 1 << 4
CR_DBGEN  = 1 << 5
CR_TXEN   = 1 << 8
CR_RXEN   = 1 << 9

# SR bits
SR_TXE   = 1 << 0
SR_RXNE  = 1 << 1
SR_BUSY  = 1 << 2
SR_ERR   = 1 << 3
SR_IDLE  = 1 << 4
SR_TC    = 1 << 5

# MODECFG bits
MODECFG_LOOPBACK = 1 << 23
MODECFG_MSBFRST  = 1 << 20

# Default PCLK for sercom = xclk = 12 MHz
SERCOM_PCLK_HZ = 12_000_000


class Sercom:
    """Driver for nc_sercom on APB slot 4 (0x8000)."""

    def __init__(self, apb, base=ADDR_SERCOM):
        self.apb = apb
        self.base = base

    # Low-level register access ------------------------------------------------
    def read(self, off):
        return self.apb.read(self.base + off)

    def write(self, off, val):
        return self.apb.write(self.base + off, val)

    # Status helpers -----------------------------------------------------------
    def sr(self):
        return self.read(SERCOM_SR)

    def tx_empty(self):    return bool(self.sr() & SR_TXE)
    def rx_not_empty(self): return bool(self.sr() & SR_RXNE)
    def busy(self):        return bool(self.sr() & SR_BUSY)
    def err(self):         return bool(self.sr() & SR_ERR)
    def idle(self):        return bool(self.sr() & SR_IDLE)
    def tc(self):          return bool(self.sr() & SR_TC)

    # ID / feature -------------------------------------------------------------
    def id(self):
        return self.read(SERCOM_ID)

    def feature(self):
        return self.read(SERCOM_FEATURE)

    # Soft reset ---------------------------------------------------------------
    def reset(self):
        """Pulse CR.SRST (self-clearing). Leaves macro disabled."""
        self.write(SERCOM_CR, CR_SRST)
        # SRST is self-clearing — give one APB cycle for the side-effects
        utime.sleep_ms(1)

    # ---- USART configuration -------------------------------------------------
    def usart_setup(self, baud, loopback=False, msb_first=False, frame=0):
        """
        Configure for USART at the requested baud (PCLK=12 MHz).
        baud      : target bits/sec (e.g. 57600, 115200)
        loopback  : route TX -> RX internally (no external wiring needed)
        msb_first : MSB-first transmission order
        frame     : FRAME register raw value (0 = 8N1)
        """
        self.reset()
        clkdiv = max(0, (SERCOM_PCLK_HZ // (16 * baud)) - 1)
        modecfg = 0
        if loopback:  modecfg |= MODECFG_LOOPBACK
        if msb_first: modecfg |= MODECFG_MSBFRST
        self.write(SERCOM_MODECFG, modecfg)
        self.write(SERCOM_TIMING,  clkdiv & 0xFFFF)
        self.write(SERCOM_FRAME,   frame)
        # Enable: USART mode, TX + RX, peripheral on
        self.write(SERCOM_CR, CR_EN | CR_MODE_USART | CR_TXEN | CR_RXEN)
        return {"baud_target": baud,
                "clkdiv": clkdiv,
                "baud_actual": SERCOM_PCLK_HZ // (16 * (clkdiv + 1))}

    def write_byte(self, b, timeout_ms=10):
        """Block until TX FIFO has room, then push one byte."""
        deadline = utime.ticks_add(utime.ticks_ms(), timeout_ms)
        while not self.tx_empty():
            if utime.ticks_diff(deadline, utime.ticks_ms()) < 0:
                raise RuntimeError("sercom: TX FIFO full (timeout)")
        self.write(SERCOM_DR, b & 0xFF)

    def read_byte(self, timeout_ms=10):
        """Block until RX FIFO has data, then pop one byte."""
        deadline = utime.ticks_add(utime.ticks_ms(), timeout_ms)
        while not self.rx_not_empty():
            if utime.ticks_diff(deadline, utime.ticks_ms()) < 0:
                raise RuntimeError("sercom: RX timeout")
        return self.read(SERCOM_DR) & 0xFF

    # ---- Self-test: USART internal loopback ----------------------------------
    def usart_loopback_test(self, payload=None, baud=115200):
        """
        Configure sercom in USART loopback mode, push `payload` bytes,
        and verify they round-trip through the internal TX->RX path.
        No external wiring required. Returns (ok, sent, received).
        """
        if payload is None:
            payload = b"\x5A\xA5\x00\xFF\x12\x34\x56\x78"
        info = self.usart_setup(baud=baud, loopback=True)
        received = bytearray()
        for b in payload:
            self.write_byte(b)
            received.append(self.read_byte(timeout_ms=20))
        ok = bytes(received) == bytes(payload)
        return ok, bytes(payload), bytes(received), info
