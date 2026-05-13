# SPDX-License-Identifier: Apache-2.0
#
# Use bash with pipefail so a non-zero exit from iverilog/vvp is not
# masked by the trailing `tee`.
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

PROJ     := $(shell pwd)
RTL_DIR  := $(PROJ)/rtl
UART_DIR := $(PROJ)/uart_apb_master/rtl
USB_DIR  := $(PROJ)/usb_cdc/usb_cdc
IOP_DIR  := $(PROJ)/AttoIO/rtl
IOP_MOD  := $(PROJ)/AttoIO/models
RV32_DIR := $(PROJ)/frv32/rtl
BUILD    := $(PROJ)/build
TB_DIR   := $(PROJ)/tb
TB_INC   := $(TB_DIR)/include

IVERILOG := iverilog
VVP      := vvp

# Select which testbench to build / run. The TB top module is `tb_$(TEST)`
# and its source file is `tb/tb_$(TEST).v`. Each testbench includes
# tb/include/tb_harness.vh for the shared DUT + driver infrastructure.
TEST ?= apb_regs
TB_TOP := tb_$(TEST)
TB_SRC := $(TB_DIR)/$(TB_TOP).v

# Optional: pass DUMP=1 to enable VCD dump (`+dumpwave` plusarg)
DUMP ?= 0
ifeq ($(DUMP),1)
VVP_ARGS := +dumpwave
else
VVP_ARGS :=
endif

RTL_SRCS = \
	$(RTL_DIR)/project_macro.v \
	$(RTL_DIR)/fll_top.v \
	$(RTL_DIR)/fll_sim.v \
	$(RTL_DIR)/apb_clk_ctrl.v \
	$(RTL_DIR)/apb_status.v \
	$(RTL_DIR)/apb_usb_fifo.v \
	$(RTL_DIR)/clk_mux_2to1.v \
	$(RTL_DIR)/clk_div.v \
	$(RTL_DIR)/sky130_ef_ip__rc_osc_16M.v \
	$(RTL_DIR)/sky130_ef_ip__rc_osc_500k.v \
	$(RTL_DIR)/sky130_stubs.v \
	$(UART_DIR)/uart_apb_master.v \
	$(UART_DIR)/uart_rx.v \
	$(UART_DIR)/uart_tx.v \
	$(UART_DIR)/baud_gen.v \
	$(UART_DIR)/cmd_parser.v \
	$(UART_DIR)/resp_builder.v \
	$(UART_DIR)/apb_master.v \
	$(UART_DIR)/apb_splitter.v \
	$(UART_DIR)/uart_apb_sys.v

USB_SRCS := $(wildcard $(USB_DIR)/*.v)

IOP_SRCS = \
	$(IOP_DIR)/attoio_macro.v \
	$(IOP_DIR)/attoio_apb_if.v \
	$(IOP_DIR)/attoio_memmux.v \
	$(IOP_DIR)/attoio_gpio.v \
	$(IOP_DIR)/attoio_spi.v \
	$(IOP_DIR)/attoio_timer.v \
	$(IOP_DIR)/attoio_wdt.v \
	$(IOP_DIR)/attoio_ctrl.v \
	$(IOP_MOD)/dffram_rtl.v \
	$(RV32_DIR)/attorv32.v

# Discover any test sources so `make sim TEST=<name>` works for new TBs.
TB_SRCS := $(TB_SRC)
TB_INCS := $(wildcard $(TB_INC)/*.vh)

SIM_FLAGS = -g2005 -DSIMULATION -Wall -I$(TB_INC)

SYNTH_DIR := $(PROJ)/synth
PDK_DIR   := $(shell echo /Users/mshalan/work/pdks/volare/sky130/versions/*/sky130A)
LIB_FILE  := $(PDK_DIR)/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

.PHONY: all sim clean lint synth submodules show help

all: sim

help:
	@echo "Targets:"
	@echo "  make submodules       # init git submodules (required before first build)"
	@echo "  make sim [TEST=name] [DUMP=1]"
	@echo "                        # build + run testbench tb/tb_<name>.v (default: apb_regs)"
	@echo "  make lint [TEST=name] # iverilog null-target compile check"
	@echo "  make synth            # Yosys synthesis"
	@echo "  make clean            # remove build/"

# One-shot submodule init. Run after a fresh clone.
submodules:
	git submodule update --init --recursive

# Sanity check: fail early if a submodule is missing key sources
$(UART_DIR)/uart_apb_master.v $(IOP_DIR)/attoio_macro.v $(RV32_DIR)/attorv32.v:
	@echo "ERROR: submodule source missing: $@"
	@echo "       run 'make submodules' (or 'git submodule update --init --recursive')"
	@exit 1

$(BUILD):
	mkdir -p $(BUILD)

FILELIST := $(BUILD)/filelist.$(TEST).f

$(FILELIST): $(RTL_SRCS) $(USB_SRCS) $(IOP_SRCS) $(TB_SRCS) $(TB_INCS) | $(BUILD)
	@echo "Generating filelist for TEST=$(TEST)..."
	@rm -f $@
	@for f in $(RTL_SRCS); do echo $$f >> $@; done
	@for f in $(USB_SRCS); do echo $$f >> $@; done
	@for f in $(IOP_SRCS); do echo $$f >> $@; done
	@for f in $(TB_SRCS); do echo $$f >> $@; done

SIM_VVP := $(BUILD)/sim.$(TEST).vvp

$(SIM_VVP): $(FILELIST)
	$(IVERILOG) $(SIM_FLAGS) -f $< -o $@ -s $(TB_TOP)
	@echo "Build OK: $@"

# iverilog's vvp returns 0 even on $fatal, so we additionally grep the run log
# for failure markers and fail the target accordingly. pipefail (via SHELLFLAGS)
# still catches the rare case where vvp itself crashes.
sim: $(SIM_VVP)
	@$(VVP) $< $(VVP_ARGS) 2>&1 | tee $(BUILD)/sim.$(TEST).log; \
	vvp_status=$${PIPESTATUS[0]}; \
	if [ $$vvp_status -ne 0 ]; then \
	  echo "ERROR: vvp exited with status $$vvp_status"; exit $$vvp_status; \
	fi; \
	if grep -qE '\*\*\* SOME TESTS FAILED \*\*\*|^FATAL:|TIMEOUT - simulation' $(BUILD)/sim.$(TEST).log; then \
	  echo "ERROR: testbench reported failure (see $(BUILD)/sim.$(TEST).log)"; \
	  exit 1; \
	fi; \
	if ! grep -q 'ALL TESTS PASSED' $(BUILD)/sim.$(TEST).log; then \
	  echo "ERROR: did not find 'ALL TESTS PASSED' marker (see $(BUILD)/sim.$(TEST).log)"; \
	  exit 1; \
	fi

clean:
	rm -rf $(BUILD)

lint: $(FILELIST)
	$(IVERILOG) $(SIM_FLAGS) -t null -f $< -s $(TB_TOP)

show:
	@cat $(BUILD)/sim.$(TEST).log

synth: synth/synth.ys synth/blackbox_stubs.v
	yosys synth/synth.ys 2>&1 | tee $(SYNTH_DIR)/synth.log
	@echo ""
	@echo "=== Synthesis Summary ==="
	@grep 'cells$$' $(SYNTH_DIR)/project_macro.stat | tail -1
	@echo "Netlist: $(SYNTH_DIR)/project_macro.v"
	@ls -la $(SYNTH_DIR)/project_macro.v
