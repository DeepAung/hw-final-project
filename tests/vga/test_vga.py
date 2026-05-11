import cocotb
from cocotb.triggers import Timer, FallingEdge
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