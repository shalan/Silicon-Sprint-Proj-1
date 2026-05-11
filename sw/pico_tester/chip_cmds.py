from machine import Pin

PIN_USB_CFG = 3
PIN_USB_PU = 9

ADDR_CTRL = 0x0000
ADDR_FLL_DIV = 0x0004
ADDR_FLL_DCO = 0x0008
ADDR_FLL_MON_DIV = 0x000C
ADDR_RC16M_MON_DIV = 0x0010
ADDR_RC500K_MON_DIV = 0x0014
ADDR_CLK_MON_DIV = 0x0018
ADDR_MON_EN = 0x001C
ADDR_USB_PAD = 0x0020
ADDR_STATUS = 0x2000
ADDR_FLL_CNT = 0x2004
ADDR_RC16M_CNT = 0x2008
ADDR_REF_CNT = 0x200C
ADDR_USB_FIFO = 0x4000

MON_FLL = 0
MON_RC16M = 1
MON_RC500K = 2
MON_CLK = 3
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
