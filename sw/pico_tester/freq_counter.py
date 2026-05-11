import rp2
from machine import Pin
import utime

PIN_FLL_MON = 5
PIN_RC16M_MON = 6
PIN_RC500K_MON = 7
PIN_CLK48M_MON = 4

MONITOR_PINS = {
    "fll": PIN_FLL_MON,
    "rc16m": PIN_RC16M_MON,
    "rc500k": PIN_RC500K_MON,
    "clk48m": PIN_CLK48M_MON,
}

@rp2.asm_pio()
def _edge_counter():
    """Count rising edges. Each edge pushes one word to RX FIFO."""
    wrap_target()
    wait(1, pin, 0)
    in_(null, 1)
    push(block)
    wait(0, pin, 0)
    wrap()

class FreqCounter:
    def __init__(self):
        self.sms = {}

    def _get_sm(self, name, pin_num):
        if name in self.sms:
            return self.sms[name]
        sm_id = {"fll": 1, "rc16m": 2, "rc500k": 3, "clk48m": 4}.get(name, 1)
        sm = rp2.StateMachine(
            sm_id,
            _edge_counter,
            freq=10_000_000,
            in_base=Pin(pin_num),
        )
        self.sms[name] = sm
        return sm

    def measure(self, name, gate_ms=1000):
        if name not in MONITOR_PINS:
            raise ValueError("unknown monitor: %s (use: %s)" % (name, ", ".join(MONITOR_PINS)))
        pin_num = MONITOR_PINS[name]
        sm = self._get_sm(name, pin_num)

        sm.active(1)
        utime.sleep_ms(gate_ms)
        sm.active(0)

        count = 0
        while True:
            try:
                sm.get()
                count += 1
            except:
                break

        freq_hz = int(count * 1000 / gate_ms)
        return freq_hz

    def measure_all(self, gate_ms=1000):
        results = {}
        for name in MONITOR_PINS:
            try:
                f = self.measure(name, gate_ms)
                results[name] = f
            except Exception as e:
                results[name] = "error: %s" % e
        return results
