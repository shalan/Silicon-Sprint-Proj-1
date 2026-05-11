from machine import Pin
import utime

PIN_EXT_RST = 8

class ResetCtrl:
    def __init__(self, pin=PIN_EXT_RST):
        self.pin = Pin(pin, Pin.OUT, value=1)

    def assert_reset(self):
        self.pin(0)

    def deassert_reset(self):
        self.pin(1)

    def pulse(self, width_ms=10):
        self.assert_reset()
        utime.sleep_ms(width_ms)
        self.deassert_reset()
        utime.sleep_ms(10)

    def is_asserted(self):
        return self.pin() == 0
