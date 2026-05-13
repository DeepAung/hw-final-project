# Real-Time Video Capture and VGA Display System

This project implements a real-time OV7670 camera capture pipeline for the Digilent Basys 3 FPGA board. The design configures the camera over SCCB/I2C, captures RGB565 camera data into a 320x240 frame buffer, reads the frame back at VGA timing, and displays it on a 640x480 VGA output with selectable image filters.

## Features

- Basys 3 top-level integration in `verilog/top.v`
- OV7670 camera configuration through SCCB/I2C
- RGB565 camera input conversion to 12-bit RGB444 pixels
- 320x240 frame buffer stored in Vivado block RAM IP
- 640x480 @ 60 Hz VGA timing
- 2x pixel scaling from 320x240 memory to 640x480 display
- Runtime filter selection with `sw[1:0]`
- Cocotb simulation tests for VGA timing/filtering, camera capture, and SCCB startup behavior

## Hardware Behavior

The top-level design targets these external devices:

- Basys 3 100 MHz clock: `clk_100MHz`
- Center button reset: `btnC`
- OV7670 camera module: `OV7670_*`
- VGA monitor: `vga_rgb`, `vga_hsync`, `vga_vsync`
- Slide switches `sw[1:0]` for filter mode selection

The camera capture path writes the first 320 pixels from each of the first 240 active camera lines into the frame buffer. The VGA path reads that 320x240 frame with 2x pixel scaling to fill the 640x480 output.

Filter modes:

| `sw[1:0]` | Mode             | Output behavior |
|-----------|------------------|-----------------|
| `00`      | Raw video        | RGB444 frame-buffer pixel |
| `01`      | Grayscale        | Weighted grayscale approximation |
| `10`      | Binary threshold | Black/white threshold from grayscale |
| `11`      | Red isolation    | Red channel only |

## Design Overview

```text
OV7670 camera
    |
    | pclk, href, vsync, data[7:0]
    v
camera_capture.v
    |
    | write address, RGB444 pixel, write enable
    v
blk_mem_gen_0 dual-port frame buffer
    |
    | read address, RGB444 pixel
    v
vga_display.v
    |
    | RGB444 pixel + sw[1:0]
    v
image_filter.v
    |
    | sync + filtered RGB
    v
VGA monitor
```

`clock_gen.v` creates the 25 MHz clock used for VGA timing and camera `XCLK`. For Icarus simulation it uses a small divider behind `__ICARUS__`; for Vivado synthesis it instantiates the generated `clk_wiz_0` IP.

## Repository Layout

```text
.
|-- Makefile
|-- README.md
|-- tests/
|   |-- capture/    # Cocotb tests for camera_capture.v
|   |-- sccb/       # Cocotb tests for camera_config.v + sccb_sender.v
|   `-- vga/        # Cocotb tests for vga_display.v
|-- verilog/
|   |-- top.v
|   |-- camera_capture.v
|   |-- camera_config.v
|   |-- sccb_sender.v
|   |-- image_filter.v
|   |-- vga_display.v
|   |-- clock_gen.v
|   `-- Basys-3-Master.xdc
`-- vivado/
    `-- vivado.xpr  # Vivado project with generated IP files
```

Key source files:

- `verilog/top.v`: connects camera capture, frame buffer, SCCB configuration, clock generation, and VGA display.
- `verilog/camera_capture.v`: tracks OV7670 `href`/`vsync`, converts RGB565 bytes to RGB444, and writes bounded 320x240 pixels to frame memory.
- `verilog/camera_config.v`: steps through the OV7670 register configuration LUT and drives the SCCB controller.
- `verilog/sccb_sender.v`: low-level SCCB/I2C transaction engine.
- `verilog/image_filter.v`: applies the selected raw, grayscale, threshold, or red-isolation filter to one RGB444 pixel.
- `verilog/vga_display.v`: generates VGA counters/sync, reads frame-buffer addresses, performs 2x scaling, and registers filtered output pixels.
- `verilog/clock_gen.v`: supplies the 25 MHz clock path for simulation and hardware.
- `verilog/Basys-3-Master.xdc`: Basys 3 pin constraints for clock, reset button, switches, camera, and VGA output.

## Simulation

Install the simulation dependencies:

```sh
pip install cocotb
sudo apt install iverilog
```

Run the active test suite from the repository root:

```sh
make test
```

Run an individual testbench:

```sh
make -C tests/vga
make -C tests/capture
make -C tests/sccb
```

Clean generated simulation output:

```sh
make clean
```

The top-level `make test` target currently runs `tests/vga`, `tests/capture`, and `tests/sccb`. A legacy `tests/clock` directory exists, but it is not part of the top-level test target because it expects an older `clk_50MHz` output that is no longer present in `clock_gen.v`.

## Vivado Build

1. Open `vivado/vivado.xpr` in Vivado.
2. Confirm `verilog/top.v` is the top module.
3. Confirm the Basys 3 constraints are active and match the expected OV7670 wiring.
4. Regenerate or validate the generated IP blocks if Vivado reports stale IP:
   - `clk_wiz_0`
   - `blk_mem_gen_0`
5. Run synthesis, implementation, and bitstream generation.
6. Program the Basys 3 and connect the OV7670 camera and VGA display.

## Current Status

Implemented:

- OV7670 SCCB configuration path
- Camera capture and RGB565-to-RGB444 conversion
- 320x240 frame-buffer addressing
- VGA 640x480 timing and sync output
- Pixel-doubled display of the captured frame
- Raw, grayscale, binary threshold, and red-isolation filters
- Cocotb tests for the core capture, VGA, and SCCB modules

Known limitations:

- The design stores a 320x240 frame and scales it to 640x480. It does not capture native 640x480 frames.
- Hardware behavior depends on the OV7670 module wiring matching `verilog/Basys-3-Master.xdc`.
- Generated Vivado run artifacts are present under `vivado/`; these may change when Vivado synthesis or implementation is rerun.
