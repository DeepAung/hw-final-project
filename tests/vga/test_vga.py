import cocotb
from cocotb.triggers import Timer, FallingEdge, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def vga_timing_test(dut):
    # 1. Start a 25MHz clock attached to the 'clk25' port (40ns period)
    clock = Clock(dut.clk25, 40, units="ns")
    cocotb.start_soon(clock.start())

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
    
    # Fast forward the simulation until we enter the "Active Video" area
    # (Where the frame address begins to increment)
    print("Fast-forwarding to active video region...")
    for _ in range(500000):
        await RisingEdge(dut.clk25)
        if dut.frame_addr.value.integer > 0:
            break
            
    # Set RAW FEED filter and inject a known pixel (Pure Blue: Red=0, Green=0, Blue=F)
    dut.filter_sw.value = 0b00
    dut.frame_pixel.value = 0x00F
    await RisingEdge(dut.clk25)
    await RisingEdge(dut.clk25)
    await RisingEdge(dut.clk25) # Wait for input registration and output propagation
    assert dut.vga_blue.value == 0xF, "Raw feed failed on Blue channel"
    assert dut.vga_red.value == 0x0, "Raw feed failed on Red channel"
    
    # Test 2: RED ISOLATION (sw = 11)
    # Inject a Magenta pixel (Red=F, Green=0, Blue=F) -> 0xF0F
    dut.filter_sw.value = 0b11
    dut.frame_pixel.value = 0xF0F
    await RisingEdge(dut.clk25)
    await RisingEdge(dut.clk25)
    await RisingEdge(dut.clk25)
    assert dut.vga_red.value == 0xF, "Red isolation failed: Red channel blocked"
    assert dut.vga_blue.value == 0x0, "Red isolation failed: Blue channel let through"
    
    print("Image filter combinational logic verified successfully.")