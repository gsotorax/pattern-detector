`timescale 1ns/1ps
//-------------------------------------------------------------------
//                               TOP
//-------------------------------------------------------------------
`include "async_fifo.sv"
`include "pattern_detector.sv"
module system_top (
    // Receiver Interface
    input  logic        clk_net,
    input  logic        aresetn,
    input  logic        rx_valid,
    input  logic [63:0] rx_data,
    input  logic        rx_sop,
    input  logic        rx_eop,
    input  logic [2:0]  rx_length,

    // Host Interface
    input  logic        clk_host,
    output logic        tx_valid,
    output logic [63:0] tx_data,
    output logic        tx_sop,
    output logic        tx_eop,
    output logic [2:0]  tx_length,
    output logic [7:0]  tx_buffer
);
    // Wires for connecting Packet FIFO
    logic        packet_fifo_wr_en;
    logic [76:0] packet_fifo_wdata;
    logic        packet_fifo_full;
    logic        packet_fifo_rd_en;
    logic [76:0] packet_fifo_rdata;
    logic        packet_fifo_empty;

    // Wires for connecting Buffer FIFO
    logic [7:0]  buffer_val_to_fifo;
    logic        buffer_val_valid;
    logic        buffer_fifo_full;
    logic        buffer_fifo_rd_en;
    logic [7:0]  buffer_val_from_fifo;
    logic        buffer_fifo_empty;

    // Instantiate Pattern Detector
    pattern_detector detector (
        .clk_net(clk_net),
        .aresetn(aresetn),
        .i_valid(rx_valid),
        .i_data(rx_data),
        .i_sop(rx_sop),
        .i_eop(rx_eop),
        // Connect programmable patterns (could be registers)
        .i_symbol_pattern_1(64'hAABBCCDDEEFF0011),
        .i_symbol_pattern_2(64'h1122334455667788),
        .i_symbol_pattern_3(64'hDEADBEEFDEADBEEF),
        .i_symbol_pattern_4(64'hFEEDBEEFDEADFAAF),
        .o_buffer_val(buffer_val_to_fifo),
        .o_buffer_val_valid(buffer_val_valid)
    );

    // --- Write Logic (clk_net domain) ---
    assign packet_fifo_wr_en = rx_valid;
    assign packet_fifo_wdata = {rx_eop, rx_sop, rx_length, rx_data};

    // Packet Data FIFO (WIDTH = 1 EOP + 1 SOP + 3 LENGTH + 64 DATA = 77 bits)
    async_fifo #(
        .DATA_WIDTH(77),
        .DEPTH(256)
    ) packet_fifo_inst (
        .wr_clk(clk_net),
        .wr_rst(~aresetn),
        .wr_en(packet_fifo_wr_en),
        .wr_data(packet_fifo_wdata),
        .full(packet_fifo_full),
        .rd_clk(clk_host),
        .rd_rst(~aresetn),
        .rd_en(packet_fifo_rd_en),
        .rd_data(packet_fifo_rdata),
        .empty(packet_fifo_empty)
    );

    // Buffer Value FIFO (WIDTH = 8 bits)
    async_fifo #(
        .DATA_WIDTH(8),
        .DEPTH(32)
    ) buffer_fifo_inst (
        .wr_clk(clk_net),
        .wr_rst(~aresetn),
        .wr_en(buffer_val_valid), // Write only on EOP of incoming packet
        .wr_data(buffer_val_to_fifo),
        .full(buffer_fifo_full),
        .rd_clk(clk_host),
        .rd_rst(~aresetn),
        .rd_en(buffer_fifo_rd_en), // Read only on EOP of outgoing packet
        .rd_data(buffer_val_from_fifo),
        .empty(buffer_fifo_empty)
    );

    // --- Read Logic (clk_host domain) ---
    assign tx_valid = !packet_fifo_empty;
    assign packet_fifo_rd_en = tx_valid; // Simplified: always read if data is available

    // Deconstruct data from FIFO
    assign tx_eop    = packet_fifo_rdata[76];
    assign tx_sop    = packet_fifo_rdata[75];
    assign tx_length = packet_fifo_rdata[74:72];
    assign tx_data   = packet_fifo_rdata[63:0];

    // Read from buffer FIFO only when the packet EOP is being sent
    assign buffer_fifo_rd_en = tx_valid && tx_eop;
    assign tx_buffer = (tx_eop) ? buffer_val_from_fifo : 8'b0;

endmodule

