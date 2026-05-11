# Makefile
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Define the path to your project root (up two directories from tests/vga)
PROJ_ROOT := $(shell pwd)/../..

# Point to the actual Verilog source file
VERILOG_SOURCES += $(PROJ_ROOT)/verilog/vga_display.v

TOPLEVEL = vga_display
MODULE = test_vga

include $(shell cocotb-config --makefiles)/Makefile.sim