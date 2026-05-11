from machine import UART, Pin
import ustruct
import utime

SYNC_0 = 0xDE
SYNC_1 = 0xAD
CMD_READ = 0x5A
CMD_WRITE = 0xA5
STATUS_ACK = 0xAC
STATUS_ERR = 0xEE

class APBMaster:
    def __init__(self, id=0, baud=57600, tx=0, rx=1, timeout_ms=500):
        self.uart = UART(id, baudrate=baud, tx=Pin(tx), rx=Pin(rx))
        self.timeout_ms = timeout_ms

    def _write_byte(self, b):
        self.uart.write(bytes([b]))

    def _read_byte(self):
        deadline = utime.ticks_ms() + self.timeout_ms
        while utime.ticks_ms() < deadline:
            data = self.uart.read(1)
            if data:
                return data[0]
            utime.sleep_ms(1)
        return None

    def _flush(self):
        while self.uart.any():
            self.uart.read()

    def read(self, addr):
        self._flush()
        self._write_byte(SYNC_0)
        self._write_byte(SYNC_1)
        self._write_byte(CMD_READ)
        self._write_byte((addr >> 24) & 0xFF)
        self._write_byte((addr >> 16) & 0xFF)
        self._write_byte((addr >> 8) & 0xFF)
        self._write_byte(addr & 0xFF)

        status = self._read_byte()
        if status is None:
            raise RuntimeError("timeout waiting for status")
        if status == STATUS_ERR:
            raise RuntimeError("chip returned error (0xEE)")

        data = 0
        for i in range(4):
            b = self._read_byte()
            if b is None:
                raise RuntimeError("timeout waiting for data byte %d" % i)
            data = (data << 8) | b

        return data

    def write(self, addr, data):
        self._flush()
        self._write_byte(SYNC_0)
        self._write_byte(SYNC_1)
        self._write_byte(CMD_WRITE)
        self._write_byte((addr >> 24) & 0xFF)
        self._write_byte((addr >> 16) & 0xFF)
        self._write_byte((addr >> 8) & 0xFF)
        self._write_byte(addr & 0xFF)
        self._write_byte((data >> 24) & 0xFF)
        self._write_byte((data >> 16) & 0xFF)
        self._write_byte((data >> 8) & 0xFF)
        self._write_byte(data & 0xFF)

        status = self._read_byte()
        if status is None:
            raise RuntimeError("timeout waiting for status")
        if status == STATUS_ERR:
            raise RuntimeError("chip returned error (0xEE)")
        return True
