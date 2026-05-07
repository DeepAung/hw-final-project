# Real-Time Video Capture and Processing System

## Project Overview
This project implements a real-time video capture and VGA display system on the Basys 3 FPGA board using the OV7670 camera module.

The design captures video from the camera, stores it in Block RAM, and outputs it to a VGA monitor. The implementation includes a working camera configuration path, a frame buffer, VGA timing generation, and three hardware image filters switchable through slide switches.

## Current Status
- Camera configuration via SCCB/I2C is present in `verilog/camera_config.v` and `verilog/sccb_sender.v`
- Camera capture logic is implemented in `verilog/camera_capture.v`
- Frame buffer is instantiated as `blk_mem_gen_0`
- VGA timing and readout are implemented in `verilog/vga_display.v`
- Three image filters are available:
  - `sw = 00`: raw video feed
  - `sw = 01`: grayscale
  - `sw = 10`: binary threshold
  - `sw = 11`: red channel isolation
- Baseline target is 320x240 captured video displayed on a 640x480 VGA signal
- Extra credit 640x480 capture is not yet implemented and is not required for the baseline

## Repository Structure

### `verilog/`
- `top.v`
  - Top-level integration of camera interface, BRAM, SCCB configuration, and VGA display
  - Connects the OV7670 camera signals to capture logic and maps output to VGA signals
  - Includes switch input `sw[1:0]` for filter selection

- `camera_capture.v`
  - Captures pixel data from OV7670 using `pclk`, `href`, and `vsync`
  - Builds 12-bit RGB pixels from sequential camera bytes
  - Generates write addresses and enables for frame buffer writes

- `camera_config.v`
  - Implements camera configuration using a LUT of OV7670 register settings
  - Uses SCCB via `I2C_Controller` to program the camera at startup

- `vga_display.v`
  - Generates VGA sync signals at 640x480 @ 60Hz
  - Calculates BRAM read addresses for displaying the 320x240 captured frame
  - Applies selected image filter to the read pixel values

- `clock_gen.v`
  - Creates 25 MHz and 50 MHz clocks from the Basys-3 100 MHz input clock
  - Provides the camera `XCLK` and VGA pixel clock source

- `debounce.v`
  - Debounces the reset input using a 50 MHz clock

- `sccb_sender.v`
  - Implements the low-level SCCB / I2C controller used by `camera_config.v`
  - Handles write and read transactions to the camera registers

### `vivado/`
- Contains Vivado project files and generated constraints

### `vivado/vivado.srcs/constrs_1/imports/verilog/Basys-3-Master.xdc`
- Board constraint file for Basys 3 pin mapping
- Includes camera pins and VGA output pins
- Switch constraints for `sw[0]` and `sw[1]` are enabled for filter selection

## What has been implemented
1. OV7670 camera initialization via SCCB
2. Camera capture from the OV7670 module into a dual-port BRAM frame buffer
3. VGA timing generation for 640x480 output
4. Reading the stored frame buffer and displaying the captured image
5. Image filter switching using slide switches

## What to do next
1. Synthesize the design in Vivado
2. Confirm the active constraint file is the one used by the project
3. Test on Basys 3 hardware with OV7670 and VGA monitor
4. Verify:
   - camera image appears on screen
   - `vga_hsync` and `vga_vsync` are correct
   - slide switch filter selection works
   - the displayed image is stable

## Notes
- This repository currently targets the baseline project requirements.
- The current implementation is not a full native 640x480 camera capture solution.
- If you want to add extra credit later, the next step is to redesign the memory and camera capture path for real 640x480 data.
