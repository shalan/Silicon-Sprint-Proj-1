PROJ     := $(shell pwd)
RTL_DIR  := $(PROJ)/rtl
UART_DIR := $(PROJ)/uart_apb_master/rtl
USB_DIR  := $(PROJ)/usb_cdc/usb_cdc
BUILD    := $(PROJ)/build

IVERILOG := iverilog
VVP      := vvp

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

TB_DIR  := $(PROJ)/tb

TB_SRCS = \
	$(TB_DIR)/tb_project_macro.v

SIM_FLAGS = -g2005 -DSIMULATION -Wall

SYNTH_DIR := $(PROJ)/synth
PDK_DIR   := $(shell echo /Users/mshalan/work/pdks/volare/sky130/versions/*/sky130A)
LIB_FILE  := $(PDK_DIR)/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

.PHONY: all sim clean lint synth

all: sim

$(BUILD):
	mkdir -p $(BUILD)

FILELIST := $(BUILD)/filelist.f

$(FILELIST): $(RTL_SRCS) $(USB_SRCS) $(TB_SRCS) | $(BUILD)
	@echo "Generating filelist..."
	@rm -f $@
	@for f in $(RTL_SRCS); do echo $$f >> $@; done
	@for f in $(USB_SRCS); do echo $$f >> $@; done
	@for f in $(TB_SRCS); do echo $$f >> $@; done

SIM_VVP := $(BUILD)/sim.vvp

$(SIM_VVP): $(FILELIST)
	$(IVERILOG) $(SIM_FLAGS) -f $< -o $@ -s tb_project_macro
	@echo "Build OK: $@"

sim: $(SIM_VVP)
	$(VVP) $< 2>&1 | tee $(BUILD)/sim.log

clean:
	rm -rf $(BUILD)

lint: $(FILELIST)
	$(IVERILOG) $(SIM_FLAGS) -t null -f $< -s tb_project_macro

show:
	@cat $(BUILD)/sim.log

synth: synth/synth.ys synth/dff_map.v synth/blackbox_stubs.v
	yosys synth/synth.ys 2>&1 | tee $(SYNTH_DIR)/synth.log
	@echo ""
	@echo "=== Synthesis Summary ==="
	@grep 'cells$$' $(SYNTH_DIR)/project_macro.stat | tail -1
	@echo "Netlist: $(SYNTH_DIR)/project_macro.v"
	@ls -la $(SYNTH_DIR)/project_macro.v
