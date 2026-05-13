<!--
Copyright (c) 2025 nativechips.ai
Author: SERCOM Development Team
License: Apache License 2.0
-->

# nc_sercom - Serial Communication Interface (SERCOM)

## Overview

`nc_sercom` is a flexible serial communication interface IP supporting **USART, SPI, and I2C** protocols. It features a standard APB3 host interface, configurable FIFOs, DMA support, and interrupt-driven operation. The IP is characterized in the SKY130 HD flow.

## Key Features

| Feature | Description |
|---------|-------------|
| **Multi-protocol** | USART, SPI, I2C in one configurable IP |
| **Data Rates** | Configurable baud/clock divider |
| **FIFOs** | 4-deep TX/RX FIFOs (configurable 2-16 entries) |
| **DMA** | TX/RX DMA support with configurable thresholds |
| **Interrupts** | Event-driven: TX empty, RX not empty, errors, transfer complete |
| **Pads** | Up to 6 configurable pads with flexible pin mapping |
| **Power** | Low power mode with clock gating when idle |
| **Testing** | Loopback mode for built-in self-test |

## Quick Start

```bash
# Run basic verification
make -C nc_sercom verify

# Validate unified file/layout conventions
make -C nc_sercom check-layout

# Run naming convention gate on top-level RTL ports
make -C nc_sercom check-naming

# Run synthesis + PPA
make -C nc_sercom ppa

# Run gate-level verification
make -C nc_sercom verify-synth
```

## Protocol Support

### USART (Universal Synchronous/Asynchronous RX/TX)
- Data bits: 5, 6, 7, 8, 9
- Stop bits: 1, 2
- Parity: None, Even, Odd
- Baud rates: Up to f_PERIPH/16
- Hardware flow control: RTS/CTS (optional)

### SPI (Serial Peripheral Interface)
- Modes: Master, Slave
- Clock polarity/phase: CPOL=0/1, CPHA=0/1
- Data order: MSB/LSB first
- Frame sizes: 8, 16, 32 bits
- Chip selects: Up to 4 (internal)

### I2C (Inter-Integrated Circuit)
- Speed: Standard (100kHz), Fast (400kHz), Fast+ (1MHz)
- Addressing: 7-bit, 10-bit
- Modes: Master, Slave
- Features: General call, clock stretching, SMBus compatible

## File Structure

```text
nc_sercom/
├── README.md
├── Makefile
├── nc_sercom.yaml
├── nc_sercom.reg.yaml
├── rtl/
│   ├── nc_sercom.f
│   ├── nc_sercom.v
│   ├── nc_sercom_usart_tx.v
│   ├── nc_sercom_usart_rx.v
│   ├── nc_sercom_spi.v
│   └── nc_sercom_i2c.v
├── tb/
│   ├── nc_sercom_verify.f
│   ├── nc_sercom_protocol_simple_verify.f
│   ├── nc_sercom_protocol_verify.f
│   ├── nc_sercom_irq_verify.f
│   ├── nc_sercom_errors_verify.f
│   ├── nc_sercom_dma_verify.f
│   ├── nc_sercom_stress_verify.f
│   ├── tb_nc_sercom.sv
│   ├── tb_nc_sercom_protocol_simple.sv
│   ├── tb_nc_sercom_protocol.sv
│   ├── tb_nc_sercom_irq.sv
│   ├── tb_nc_sercom_errors.sv
│   ├── tb_nc_sercom_dma.sv
│   └── tb_nc_sercom_stress.sv
├── docs/
│   ├── architecture.md
│   └── datasheet.md
├── synth/
│   ├── nc_sercom.sdc
│   ├── nc_sercom.syn.v
│   └── nc_sercom.gl.v
├── fw/
│   ├── nc_sercom.h
│   └── drivers/
│       ├── nc_sercom_drv.h
│       ├── nc_sercom_drv.c
│       └── CONTRACT_V1.md
└── tmp/                 # generated artifacts (ignored/cleanable)
```

## Target Specifications (Latest PPA, March 6, 2026)

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Library** | SKY130 HD (`sky130_fd_sc_hd`) | LMS/OpenSTA flow |
| **Clock Target** | 10 ns (100 MHz) | `PCLK` |
| **Cells** | 3,852 | Excluding `$scopeinfo` |
| **Area** | 38,804.7168 um² (0.038805 mm²) | Post-synthesis |
| **Timing (SS)** | WNS/TNS = -2.37 / -304.33 ns | setup-limited |
| **Timing (TT)** | WNS/TNS = 0.00 / 0.00 ns | meets target |
| **Power (SS)** | 2.80 mW total | VCD-based |
| **Power (TT)** | 3.48 mW total | VCD-based |

## Pin Configuration

The SERCOM supports flexible pad mapping for each protocol:

### USART Pin Mapping (TXPO/RXPO)

| TXPO | PAD0 | PAD1 | PAD2 | PAD3 |
|------|------|------|------|------|
| 00 | TX | RX | XCK | - |
| 01 | TX | RX | RTS | CTS |

### SPI Pin Mapping (DOPO/DIPO)

| DOPO | MOSI | MISO | SCK | SS |
|------|------|------|-----|-----|
| 00 | PAD0 | PAD2 | PAD3 | PAD1 |
| 01 | PAD2 | PAD0 | PAD3 | PAD1 |

### I2C Pin Mapping

| Mode | SDA | SCL |
|------|-----|-----|
| Fixed | PAD0 | PAD1 |

## Baud Rate Examples

| Target | f_periph | TIMING.CLKDIV Value |
|--------|----------|---------------------|
| USART 115200 baud | 48 MHz | 25 |
| SPI 4 MHz | 48 MHz | 5 |
| I2C 400 kHz | 48 MHz | 59 |

## Development Status (March 6, 2026)

| Item | Status |
|------|--------|
| RTL Ready | ✅ |
| Verified | ✅ |
| Documented | ✅ |
| Synthesis Ready | ✅ |
| PPA Ready | ✅ |
| FPGA Validated | ⏳ |
| ASIC Validated | ⏳ |

## License

Apache License 2.0

## References

- MCU Peripheral Register Specification v1.2
- AMBA APB Protocol Specification
- USART, SPI, I2C Protocol Standards
