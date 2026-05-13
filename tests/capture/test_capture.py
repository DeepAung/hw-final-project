import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer


async def send_pixel(dut, first_byte, second_byte):
    dut.d.value = first_byte
    await FallingEdge(dut.pclk)
    dut.d.value = second_byte
    await FallingEdge(dut.pclk)
    await Timer(1, unit="ps")


async def end_line(dut):
    dut.href.value = 0
    await FallingEdge(dut.pclk)
    await Timer(1, unit="ps")


@cocotb.test()
async def test_frame_bounds_and_addressing(dut):
    cocotb.start_soon(Clock(dut.pclk, 42, unit="ns").start())

    dut.vsync.value = 1
    dut.href.value = 0
    dut.d.value = 0
    await Timer(100, unit="ns")
    dut.vsync.value = 0

    await FallingEdge(dut.pclk)
    assert int(dut.we.value) == 0, "VSYNC should suppress writes"

    # The first active pixel is written to address 0.
    dut.href.value = 1
    await send_pixel(dut, 0xF0, 0x0F)
    assert int(dut.we.value) == 1, "First pixel was not written"
    assert int(dut.addr.value) == 0, "First pixel should map to address 0"
    assert int(dut.dout.value) == 0xF07, "RGB565 to RGB444 conversion is wrong"

    # Pixels advance horizontally within the current line.
    await send_pixel(dut, 0x0F, 0xF0)
    assert int(dut.we.value) == 1, "Second pixel was not written"
    assert int(dut.addr.value) == 1, "Second pixel should map to address 1"

    await end_line(dut)

    # The next line starts at address 320 after HREF falls.
    dut.href.value = 1
    await send_pixel(dut, 0xAA, 0x55)
    assert int(dut.we.value) == 1, "First pixel on second line was not written"
    assert int(dut.addr.value) == 320, "Second line should start at address 320"

    # VSYNC resets the line and pixel counters for a new frame.
    dut.href.value = 0
    dut.vsync.value = 1
    await FallingEdge(dut.pclk)
    dut.vsync.value = 0
    await FallingEdge(dut.pclk)

    dut.href.value = 1
    await send_pixel(dut, 0x12, 0x34)
    assert int(dut.we.value) == 1, "First pixel after VSYNC was not written"
    assert int(dut.addr.value) == 0, "VSYNC should reset the next frame to address 0"

    print("Frame-bounded capture addressing verified.")
