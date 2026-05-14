WAVES ?= 1

TEST_WAVE_DIR ?= $(abspath $(PROJ_ROOT)/tests)
TEST_WAVE_FILE ?= $(TEST_WAVE_DIR)/$(TOPLEVEL).fst

.PHONY: all
all: sim
	@cp "$(SIM_BUILD)/$(TOPLEVEL).fst" "$(TEST_WAVE_FILE)"
	@echo "Wrote waveform: $(TEST_WAVE_FILE)"

clean::
	@$(RM) -f "$(TEST_WAVE_FILE)"
