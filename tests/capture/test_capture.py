import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_memory_addressing(dut):
    # OV7670 PCLK is approx 24MHz
    cocotb.start_soon(Clock(dut.pclk, 42, units="ns").start())
    
    # 1. Reset the module via VSYNC
    dut.vsync.value = 1
    dut.href.value = 0
    dut.d.value = 0
    await Timer(100, units="ns")
    dut.vsync.value = 0
    
    await RisingEdge(dut.pclk)
    assert dut.addr.value.integer == 0, "Address should reset on VSYNC"

    # 2. Simulate 1 pixel of data coming from the camera (2 bytes)
    dut.href.value = 1
    
    # Byte 1 (e.g., Red/Green bits)
    dut.d.value = 0xF0 
    await RisingEdge(dut.pclk)
    
    # Byte 2 (e.g., Green/Blue bits)
    dut.d.value = 0x0F
    await RisingEdge(dut.pclk)
    
    # End of pixel data
    dut.href.value = 0
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)

    # 3. Verify Memory Write Enable and Address Increment
    assert dut.we.value == 1, "Write Enable was not asserted!"
    assert dut.addr.value.integer == 1, "Memory Address did not increment!"
    
    print(f"Captured 12-bit pixel data: {hex(dut.dout.value.integer)}")
    print("Memory addressing test passed.")