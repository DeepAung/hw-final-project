import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_clock_frequencies(dut):
    # Start the 100MHz Basys 3 base clock (10ns period)
    cocotb.start_soon(Clock(dut.clk_100MHz, 10, unit="ns").start())
    
    # Apply reset
    dut.reset.value = 1
    await Timer(50, unit="ns")
    dut.reset.value = 0
    await Timer(50, unit="ns")

    print("Measuring 25 MHz Clock Period...")
    await RisingEdge(dut.clk_25MHz)
    t1 = get_sim_time(units="ns")
    await RisingEdge(dut.clk_25MHz)
    t2 = get_sim_time(units="ns")
    
    # 25 MHz = 40ns period
    assert (t2 - t1) == 40, f"Expected 40ns period for 25MHz, got {t2-t1}ns"
    print(f"PASS: 25 MHz clock measured perfectly at {t2-t1}ns.")

    print("Measuring 50 MHz Clock Period...")
    await RisingEdge(dut.clk_50MHz)
    t1 = get_sim_time(units="ns")
    await RisingEdge(dut.clk_50MHz)
    t2 = get_sim_time(units="ns")
    
    # 50 MHz = 20ns period
    assert (t2 - t1) == 20, f"Expected 20ns period for 50MHz, got {t2-t1}ns"
    print(f"PASS: 50 MHz clock measured perfectly at {t2-t1}ns.")