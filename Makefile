# ============================================================================
# Makefile — K-Means Hardware Accelerator
# Usage:
#   make sim_mult     → compile and run fixed_mult testbench
#   make wave_mult    → open GTKWave for fixed_mult
#   make clean        → remove build artifacts
# ============================================================================

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim
WAVE_DIR = sim/waveforms

# ── fixed_mult testbench ─────────────────────────────────────────────────────
TB_MULT_SRC = $(TB_DIR)/tb_fixed_mult.v $(RTL_DIR)/fixed_mult.v

sim_mult: $(WAVE_DIR)
	$(IVERILOG) -g2012 -o $(SIM_DIR)/tb_fixed_mult $(TB_MULT_SRC)
	$(VVP) $(SIM_DIR)/tb_fixed_mult

wave_mult:
	$(GTKWAVE) $(WAVE_DIR)/tb_fixed_mult.vcd &

# ── Create sim dirs ───────────────────────────────────────────────────────────
$(WAVE_DIR):
	mkdir -p $(WAVE_DIR)

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.out
	rm -f $(WAVE_DIR)/*.vcd

.PHONY: sim_mult wave_mult clean
