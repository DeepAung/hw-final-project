SIM ?= icarus
TOPLEVEL_LANG ?= verilog
PROJ_ROOT := $(shell pwd)/../..
VERILOG_SOURCES += $(PROJ_ROOT)/verilog/camera_config.v
VERILOG_SOURCES += $(PROJ_ROOT)/verilog/sccb_sender.v
TOPLEVEL = I2C_AV_Config
MODULE = test_sccb
include $(PROJ_ROOT)/tests/cocotb_wave.mk
include $(shell cocotb-config --makefiles)/Makefile.sim
