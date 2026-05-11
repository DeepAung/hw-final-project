TEST_DIRS := tests/vga tests/capture tests/sccb

.PHONY: all test clean $(TEST_DIRS)

all: test

test: $(TEST_DIRS)
	@echo "========================================"
	@echo " ALL TESTBENCHES PASSED SUCCESSFULLY"
	@echo "========================================"

$(TEST_DIRS):
	@echo "----------------------------------------"
	@echo "Running tests in $@"
	@echo "----------------------------------------"
	@$(MAKE) -C $@

clean:
	@echo "Cleaning all test directories..."
	@for dir in $(TEST_DIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	@echo "Cleanup complete."