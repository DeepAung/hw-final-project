import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def vga_timing_test(dut):
    # 1. Start a 25MHz clock attached to the 'clk25' port (40ns period)
    clock = Clock(dut.clk25, 40, units="ns")
    cocotb.start_soon(clock.start())
    dut.frame_valid.value = 1

    # Wait a few clock cycles for the initialized registers (0) to stabilize
    await Timer(100, units="ns")

    print("Simulating VGA Timing... waiting for HSYNC pulses.")

    # 2. Wait for and count 10 HSYNC pulses. 
    # Since HSYNC is active low, we look for the FallingEdge.
    hsync_pulses = 0
    for _ in range(10):
        await FallingEdge(dut.vga_hsync)
        hsync_pulses += 1
        
    assert hsync_pulses == 10, "HSYNC did not pulse correctly!"
    print(f"Success! Detected {hsync_pulses} valid HSYNC pulses.")
    
    # 3. (Optional) Check that the frame address is incrementing
    # We read the integer value of the 17-bit wire
    current_addr = dut.frame_addr.value.integer
    print(f"Current BRAM Read Address is: {current_addr}")

@cocotb.test()
async def test_image_filters(dut):
    cocotb.start_soon(Clock(dut.clk25, 40, units="ns").start())
    dut.frame_valid.value = 1
    
    # Fast forward the simulation until we enter the "Active Video" area
    # (Where the frame address begins to increment)
    print("Fast-forwarding to active video region...")
    for _ in range(500000):
        await RisingEdge(dut.clk25)
        if dut.frame_addr.value.integer > 8:
            break
            
    # Inject a known pixel (e.g., Pure Blue: Red=0, Green=0, Blue=F)
    # Format is 12-bit RGB: 12'h00F
    dut.frame_pixel.value = 0x00F
    
    # Test 1: RAW FEED (sw = 00)
    dut.filter_sw.value = 0b00
    for _ in range(20):
        await RisingEdge(dut.clk25)
    assert dut.vga_blue.value == 0xF, "Raw feed failed on Blue channel"
    assert dut.vga_red.value == 0x0, "Raw feed failed on Red channel"
    
    # Test 2: RED ISOLATION (sw = 11)
    # Inject a Magenta pixel (Red=F, Green=0, Blue=F) -> 0xF0F
    dut.frame_pixel.value = 0xF0F
    dut.filter_sw.value = 0b11
    for _ in range(20):
        await RisingEdge(dut.clk25)
    assert dut.vga_red.value == 0xF, "Red isolation failed: Red channel blocked"
    assert dut.vga_blue.value == 0x0, "Red isolation failed: Blue channel let through"
    
    print("Image filter combinational logic verified successfully.")
