import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

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
    
    # Cycle 3: WE should trigger immediately upon the 2nd byte finishing
    dut.href.value = 0
    await RisingEdge(dut.pclk)
    
    assert dut.we.value == 1, "Write Enable was not asserted!"
    assert int(dut.addr.value) == 0, "Address should still be 0 while WE is high"
    
    # Cycle 4: Address increments AFTER the write finishes
    await RisingEdge(dut.pclk)
    assert int(dut.addr.value) == 1, "Memory Address did not increment after write!"
    
    print("Memory addressing synchronized perfectly.")