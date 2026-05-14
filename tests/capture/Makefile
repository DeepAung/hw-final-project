SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PROJ_ROOT := $(shell pwd)/../..
VERILOG_SOURCES += $(PROJ_ROOT)/verilog/camera_capture.v
TOPLEVEL = camera_capture
MODULE = test_capture
include $(PROJ_ROOT)/tests/cocotb_wave.mk
include $(shell cocotb-config --makefiles)/Makefile.sim
