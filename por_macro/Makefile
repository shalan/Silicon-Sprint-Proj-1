# SPDX-License-Identifier: Apache-2.0
#
# Local Makefile for the por_macro unit testbench.
# Run from this directory: `make sim`.

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

HERE  := $(shell pwd)
BUILD := $(HERE)/build

RTL_SRCS = \
	$(HERE)/rtl/ring_osc.v \
	$(HERE)/rtl/adpor.v \
	$(HERE)/rtl/por_macro.v

TB_SRC := $(HERE)/tb/tb_por_macro.v

IVERILOG := iverilog
VVP      := vvp
SIM_FLAGS = -g2005 -DSIMULATION -Wall

.PHONY: all sim clean lint synth

all: sim

synth: synth/synth.ys $(RTL_SRCS)
	yosys synth/synth.ys 2>&1 | tee synth/synth.log
	@echo ""
	@echo "=== por_macro synthesis summary ==="
	@grep -E '^\s+[0-9]+ +sky130' synth/por_macro.stat | tail -30
	@echo ""
	@ls -la synth/por_macro.v synth/por_macro.json 2>/dev/null

$(BUILD):
	mkdir -p $(BUILD)

SIM_VVP := $(BUILD)/tb_por_macro.vvp

$(SIM_VVP): $(RTL_SRCS) $(TB_SRC) | $(BUILD)
	$(IVERILOG) $(SIM_FLAGS) -o $@ -s tb_por_macro $(RTL_SRCS) $(TB_SRC)

sim: $(SIM_VVP)
	@$(VVP) $< 2>&1 | tee $(BUILD)/tb_por_macro.log; \
	vvp_status=$${PIPESTATUS[0]}; \
	if [ $$vvp_status -ne 0 ]; then \
	  echo "ERROR: vvp exited with status $$vvp_status"; exit $$vvp_status; \
	fi; \
	if ! grep -q 'ALL TESTS PASSED' $(BUILD)/tb_por_macro.log; then \
	  echo "ERROR: testbench did not report pass"; exit 1; \
	fi

lint:
	$(IVERILOG) $(SIM_FLAGS) -t null -s tb_por_macro $(RTL_SRCS) $(TB_SRC)

clean:
	rm -rf $(BUILD)
