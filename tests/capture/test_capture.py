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
async def test_line_aware_windowing(dut):
    cocotb.start_soon(Clock(dut.pclk, 42, unit="ns").start())

    dut.vsync.value = 1
    dut.href.value = 0
    dut.d.value = 0
    await Timer(100, unit="ns")
    dut.vsync.value = 0

    await FallingEdge(dut.pclk)
    assert int(dut.addr.value) == 0, "Address should reset on VSYNC"

    # Default capture parameters skip the first two source lines.
    for _ in range(2):
        dut.href.value = 1
        await send_pixel(dut, 0xF0, 0x0F)
        assert dut.we.value == 0, "CROP_TOP line should not be written"
        await end_line(dut)

    # On the first captured line, the first four pixels are skipped.
    dut.href.value = 1
    for _ in range(4):
        await send_pixel(dut, 0x12, 0x34)
        assert dut.we.value == 0, "CROP_LEFT pixel should not be written"

    await send_pixel(dut, 0xF0, 0x0F)
    assert dut.we.value == 1, "First in-window pixel was not written"
    assert int(dut.addr.value) == 0, "First in-window pixel should map to address 0"
    assert int(dut.dout.value) == 0xF07, "RGB565 to RGB444 conversion is wrong"

    await send_pixel(dut, 0x0F, 0xF0)
    assert dut.we.value == 1, "Second in-window pixel was not written"
    assert int(dut.addr.value) == 1, "Second in-window pixel should map to address 1"

    await end_line(dut)

    # Next captured line starts at address 320 after the same left crop.
    dut.href.value = 1
    for _ in range(4):
        await send_pixel(dut, 0x56, 0x78)
        assert dut.we.value == 0, "Left crop should apply on every line"

    await send_pixel(dut, 0xAA, 0x55)
    assert dut.we.value == 1, "First pixel on second captured line was not written"
    assert int(dut.addr.value) == 320, "Second captured line should start at address 320"

    print("Line-aware capture windowing verified.")
