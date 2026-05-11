import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def mock_camera_ack(dut):
    """Simulates a camera pulling I2C_SDAT low to ACK transmissions."""
    while True:
        await RisingEdge(dut.iCLK)
        
        # In sccb_sender.v, SDO == 0 means the FPGA is listening for an ACK.
        if dut.sccb_sender.SDO.value == 0:
            dut.I2C_SDAT.value = 0
        else:
            # In cocotb 2.0, we can directly assign "Z" for High-Impedance
            dut.I2C_SDAT.value = "Z"

@cocotb.test()
async def test_sccb_state_machine(dut):
    # 25MHz System Clock
    cocotb.start_soon(Clock(dut.iCLK, 40, unit="ns").start())
    
    # Start our fake camera running in the background
    cocotb.start_soon(mock_camera_ack(dut))
    
    # Apply Active-Low Reset
    dut.iRST_N.value = 0
    await Timer(200, unit="ns")
    dut.iRST_N.value = 1
    
    print("Waiting for I2C configuration engine to start...")
    
    lut_incremented = False
    for _ in range(200000): 
        await RisingEdge(dut.iCLK)
        
        if int(dut.LUT_INDEX.value) > 0:
            lut_incremented = True
            break
            
    assert lut_incremented, "SCCB state machine failed to increment LUT_INDEX!"
    print(f"Success! State machine advanced to LUT_INDEX: {int(dut.LUT_INDEX.value)}")