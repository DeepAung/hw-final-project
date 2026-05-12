import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

@cocotb.test()
async def test_memory_addressing(dut):
    cocotb.start_soon(Clock(dut.pclk, 42, unit="ns").start())
    
    dut.vsync.value = 1
    dut.href.value = 0
    dut.d.value = 0
    await Timer(100, unit="ns")
    dut.vsync.value = 0
    
    await RisingEdge(dut.pclk)
    assert int(dut.addr.value) == 0, "Address should reset on VSYNC"

    dut.href.value = 1
    
    # Byte 1 
    dut.d.value = 0xF0 
    await RisingEdge(dut.pclk)
    
    # Byte 2 
    dut.d.value = 0x0F
    await RisingEdge(dut.pclk)
    
    # WE is generated on the falling PCLK edge and held for the next rising
    # edge, matching the BRAM write clock.
    dut.href.value = 0
    await FallingEdge(dut.pclk)
    
    assert dut.we.value == 1, "Write Enable was not asserted!"
    assert int(dut.addr.value) == 0, "Address should still be 0 while WE is high"
    
    # Cycle 4: Address increments AFTER the write finishes
    await FallingEdge(dut.pclk)
    assert int(dut.addr.value) == 1, "Memory Address did not increment after write!"
    
    print("Memory addressing synchronized perfectly.")
