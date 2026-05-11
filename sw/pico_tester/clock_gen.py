import rp2
from machine import Pin, freq
import utime

PIN_XCLK = 2

@rp2.asm_pio(sideset_init=rp2.PIO.OUT_LOW)
def _clock_gen():
    """Toggle pin at PIO clock / 10. System clock 120 MHz -> 12 MHz output."""
    set(pins, 1)          .side(1)  [4]
    set(pins, 0)          .side(0)  [4]

class ClockGen:
    def __init__(self, pin=PIN_XCLK, target_mhz=12):
        self.pin = pin
        self.target_mhz = target_mhz
        self.sm = None
        self._running = False
        self._orig_freq = freq()

    def start(self):
        if self._running:
            return
        self._orig_freq = freq()
        pio_freq = self._orig_freq
        div = pio_freq / (self.target_mhz * 1_000_000 * 10)
        self.sm = rp2.StateMachine(
            0,
            _clock_gen,
            freq=pio_freq,
            div=div,
            sideset_base=Pin(self.pin)
        )
        self.sm.active(1)
        self._running = True

    def stop(self):
        if not self._running:
            return
        if self.sm:
            self.sm.active(0)
            self.sm = None
        Pin(self.pin, Pin.OUT, value=0)
        self._running = False

    def is_running(self):
        return self._running

    def set_freq(self, mhz):
        was_running = self._running
        if was_running:
            self.stop()
        self.target_mhz = mhz
        if was_running:
            self.start()
