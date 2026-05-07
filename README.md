
## TODO Task

### Task 1: Fix the core data path
- Connect `vga_display.frame_addr` to `display_addr`
- Remove unused dead signals or repurpose them correctly
- Ensure the dual-port RAM read path is valid
- Validate top.v and top_test.v for correct signal flow

### Task 2: Add filter selection logic
- Create a filter selection module driven by Basys 3 switches
- Implement three filters, for example:
  1. Grayscale
  2. Color inversion (negative)
  3. Threshold / binary image
- Add a raw-video mode as the default path
- Place the filter between BRAM output and VGA output

### Task 3: Improve VGA timing and scaling
- Decide whether to support:
  - true 320x240 with 2×2 pixel doubling, or
  - full 640x480 real output
- Fix vga_display.v to use correct horizontal/vertical counters and blanking
- Optionally use vga_controller.v to simplify timing generation
- Make the video window scale properly instead of just centering the 320x240 frame

### Task 4: Validate camera capture and SCCB config
- Verify `I2C_AV_Config` completes and optionally expose `Config_Done`
- Check camera_capture.v for correct byte assembly and HREF/VSYNC handling
- Confirm that pixel write address increments correctly per captured pixel
- Add status LED or debug output if possible

### Task 5: Add simulation and documentation
- Write testbenches for:
  - `camera_capture`
  - VGA timing and frame address generator
  - filter modules
  - SCCB/OV7670 config state machine
- Prepare the final report and block diagram
- Document clock domains, BRAM usage, and filter switching logic

## Issues and Incomplete Parts

### 1. Top-level integration problems
- top.v declares `display_addr` but never connects it to `vga_display.frame_addr`
- `vga_x`, `vga_y`, `video_on`, and `rgb_reg` are declared but unused
- top.v uses `vga_display` output bus incorrectly: the BRAM read address path is broken

### 2. Missing image processing filters
- No filter module exists in the repository
- No filter selection mechanism using switches or buttons
- No path to choose between raw video and filtered video

### 3. VGA output / scaling issues
- vga_display.v centers a 320x240 image inside 640x480, but does not perform correct 2×2 pixel doubling
- The design is not implementing a proper lower-resolution display mode or a true 640x480 output
- vga_controller.v is present but not used in top.v; the project has redundant/display logic confusion

### 4. Camera capture and memory concerns
- camera_capture.v writes up to `76800` pixels, which matches 320x240, but there is no visible support for 320x200
- The capture logic may be fragile because it does not clearly handle line resets or odd pixel timing
- `Config_Done` from `I2C_AV_Config` is not used anywhere, so camera initialization has no verified handshake

### 5. SCCB / OV7670 config and debug
- The I2C config logic exists, but there is no runtime status/output to prove it completed successfully
- top_test.v includes an ILA probe, but top.v does not include any debug visibility

### 6. Missing testbench and simulation support
- There are no visible comprehensive testbenches for:
  - VGA timing
  - camera capture
  - memory address generation
  - filter logic
  - SCCB configuration

### 7. Constraints and packaging
- The XDC file maps camera pins correctly, but there is no evidence the VGA pins are actually used in the top-level netlist if top.v is broken
- The project may need a cleaned top-level port definition and constraints matching the actual `.xdc`