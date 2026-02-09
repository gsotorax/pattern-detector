# Pattern Detector Documentation

## Overview

1. The Data Packet Processing Pipeline
In a modern SoC (System on Chip) or specialized NIC/DPU, packet processing follows a rigid but high-throughput flow. We move from raw bits on the wire to structured data ready for a CPU or AI accelerator.

Ingress & Framing: Data arrives via Physical Layer (PHY) and Media Access Control (MAC). The hardware strips the preamble and identifies frame boundaries.

Parsing (De-capsulation): A hardware parser (often a programmable state machine) "walks" through the headers (L2 Ethernet, L3 IP, L4 TCP/UDP).

Classification & Look-up: This is where the "intellectual property" of the design shines. Using TCAMs (Ternary Content Addressable Memory) or Hash Tables, the chip determines the packet's priority, security rules, and destination.

Modification & Egress: Headers might be rewritten (NAT, VLAN tagging) before being queued for transmission.

2. Pattern Detection: The "Needle in the Haystack"
Pattern detection is the bedrock of Deep Packet Inspection (DPI) and hardware-accelerated security.

Fixed Pattern Matching: Simple comparators checking for specific magic numbers or headers.

Regular Expression (RegEx) Engines: Used for complex signatures. These are typically implemented using Non-deterministic Finite Automata (NFA) or Deterministic Finite Automata (DFA) mapped into hardware gates or memory-based transitions.

Bit-Level Inspection: In custom silicon, we often use parallel "sliding windows" to scan for patterns across multiple clock cycles, ensuring we don't miss a pattern that straddles a 256-bit or 512-bit bus word.

## Functionality

### Pattern Detector algorithm

Our system must process packets of data. The packet interface provides up to 8 bytes per clock cycle using a 64-bit data signal. Each valid phase of a packet of data will be indicated by a valid signal set to ‘1’. The first cycle of a packet is indicated by a SOP signal set to ‘1’; this signal is ‘0’ otherwise. The last cycle of a packet is signalled by EOP set to ‘1’. When this last cycle occurs, a 3-bit length signal indicates the number of valid bytes in the range 0-7, where a value of 0 indicates that only the first byte is valid, and a value of 7 indicates that all
8 bytes are valid.

Packets have a minimum length of 1 byte and a maximum length of 1500bytes. The byte order on the data bus can be considered little-endian, with the first byte in the LSBs [7:0] and the last byte in the MSBs [63:56]. At the end of packet, the partially used data bus will only use the lowest ((length+1)*8) bits of data bus, the remainder being undefined. The receiver interface uses a clock called clk_net.

In summary, the receive interface has the following signals.
Receiver interface:
Clock: clk_net
Signals: valid, data[63:0] , SOP, EOP, length[2:0]

A similar interface is used to transmit to a host. This interface is on the clk_host clock domain and this clock is guaranteed to have higher frequency than clk_net. In addition to the signals provided on the receiver interface there is an 8-bit signal called buffer which is used to identify what the host should do with the data. This signal must be valid at the same time that EOP is ‘1’.

In summary, the host interface has the following signals.
Host interface: 
Clock: clk_host
Signals: valid, data[63:0] , SOP, EOP, length[2:0], buffer[7:0]

The system must process packets from the receiver interface and detect up to 4 patterns. When these patterns are detected, the value of buffer should be set to a value that uniquely identifies that pattern. The packets from the receiver interface must be passed to host interface, along with the buffer value. A buffer value of 0 is used to indicate the absence of a pattern match.

Matching packets contain a 4-byte value (PACKET_TYPE) at a fixed offset into the packet. The 4-byte value is always present in a single cycle of the packet transfer. Additionally, matching packets will have a valid 8-byte value at offset (SYMBOL_OFFSET) which matches one of four programmable values. Successful detection of a packet will result in a corresponding value of buffer being set.
