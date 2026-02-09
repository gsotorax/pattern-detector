import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly
import random

async def drive_packet(dut, data_stream, packet_len_bytes):
    """Drives a packet based on Maven spec: little-endian, 1-1500 bytes [cite: 96, 101, 102]"""
    num_cycles = (packet_len_bytes + 7) // 8
    last_cycle_len = (packet_len_bytes - 1) % 8

    await RisingEdge(dut.clk_net)
    dut.rx_valid.value = 1
    dut.rx_sop.value = 1
    
    for i in range(num_cycles):
        dut.rx_data.value = data_stream[i]
        if i == num_cycles - 1:
            dut.rx_eop.value = 1
            dut.rx_length.value = last_cycle_len
        
        await RisingEdge(dut.clk_net)
        dut.rx_sop.value = 0
        
    dut.rx_valid.value = 0
    dut.rx_eop.value = 0

@cocotb.test()
async def run_icarus_test(dut):
    """Main test loop for Icarus Verilog simulation"""
    
    # Start Clocks: Net (50MHz) and Host (100MHz)
    cocotb.start_soon(Clock(dut.clk_net, 20, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_host, 10, units="ns").start())

    # Initialize Signals (Crucial for Icarus to avoid 'z' or 'x' states)
    dut.aresetn.value = 0
    dut.rx_valid.value = 0
    dut.rx_sop.value = 0
    dut.rx_eop.value = 0
    
    # Global Reset
    await Timer(50, units="ns")
    dut.aresetn.value = 1
    await RisingEdge(dut.clk_net)

    # Test Case: Pattern 1 Match
    # PACKET_TYPE at offset 16 (Cycle 2), SYMBOL at offset 64 (Cycle 8)
    packet = [0] * 10
    packet[2] = 0xDEADBEEF # PACKET_TYPE_VAL
    packet[8] = 0xAABBCCDDEEFF0011 # i_symbol_pattern_1
    
    dut._log.info("Sending Matching Packet to Icarus...")
    await drive_packet(dut, packet, 72)
    
    # Wait for Host domain to process through Async FIFO
    for _ in range(20):
        await RisingEdge(dut.clk_host)
        if dut.tx_valid.value and dut.tx_eop.value:
            assert dut.tx_buffer.value == 1, f"Expected Buffer 1, got {dut.tx_buffer.value}"
            dut._log.info(f"SUCCESS: Pattern 1 detected. Buffer: {dut.tx_buffer.value}")

    await Timer(100, units="ns")


# ✅ CRITICAL: Pytest wrapper function
def test_pattern_detector_runner():
    import os
    from pathlib import Path
    from cocotb_tools.runner import get_runner
    
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = [
        proj_path / "sources/process_packets.sv",  # This file includes the other two
    ]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="system_top",
        always=True,
        includes=[proj_path / "sources"],  # Add include path for `include directives
    )
    
    runner.test(
        hdl_toplevel="system_top",
        test_module="test_pattern_detector_hidden"
    )