//-------------------------------------------------------------------
//                              FIFO
//-------------------------------------------------------------------
// async_fifo.sv
// Asynchronous FIFO for clock domain crossing using Gray code pointers
module async_fifo #(
    parameter DATA_WIDTH = 77,
    parameter DEPTH      = 256
) (
    // Write Domain
    input  logic                 wr_clk,
    input  logic                 wr_rst,
    input  logic                 wr_en,
    input  logic [DATA_WIDTH-1:0]  wr_data,
    output logic                 full,

    // Read Domain
    input  logic                 rd_clk,
    input  logic                 rd_rst,
    input  logic                 rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                 empty
);
    // Calculate address width
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Write and read pointers (binary and Gray code)
    logic [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    logic [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;
    
    // Synchronized Gray code pointers
    logic [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    logic [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
    
    // Write domain logic
    always_ff @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_ptr_bin <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin <= wr_ptr_bin + 1;
            wr_ptr_gray <= (wr_ptr_bin + 1) ^ ((wr_ptr_bin + 1) >> 1);
        end
    end
    
    // Synchronize read pointer to write clock domain
    always_ff @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end
    
    // Full flag generation
    always_comb begin
        full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                 rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});
    end
    
    // Read domain logic
    always_ff @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_ptr_bin <= '0;
            rd_ptr_gray <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin <= rd_ptr_bin + 1;
            rd_ptr_gray <= (rd_ptr_bin + 1) ^ ((rd_ptr_bin + 1) >> 1);
        end
    end
    
    // Synchronize write pointer to read clock domain
    always_ff @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end
    
    // Empty flag generation
    always_comb begin
        empty = (rd_ptr_gray == wr_ptr_gray_sync2);
    end
    
endmodule
