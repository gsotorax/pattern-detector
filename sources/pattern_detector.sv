//-------------------------------------------------------------------
// pattern_detector.sv
// Operating in the clk_net domain, this is the core logic block. 
// It inspects the incoming packet data. It contains a byte counter and the logic to compare packet data at specific offsets against the programmable PACKET_TYPE and SYMBOL values. It determines the correct buffer value for the entire packet.
//-------------------------------------------------------------------
module pattern_detector #(
    parameter PACKET_TYPE_OFFSET = 16, // Fixed offset for PACKET_TYPE
    parameter SYMBOL_OFFSET      = 64, // Fixed offset for SYMBOL_OFFSET
    parameter PACKET_TYPE_VAL    = 32'hDEADBEEF
) (
	// This initial block operates on the slower clk_net. 
    // It receives the incoming packet data, including the valid, data, SOP, and EOP signals..
  

    input  logic             clk_net,
    input  logic             aresetn,

    // Receiver Interface
    input  logic             i_valid,
    input  logic [63:0]      i_data,
    input  logic             i_sop,
    input  logic             i_eop,

    // Programmable Symbol Patterns
    input  logic [63:0]      i_symbol_pattern_1,
    input  logic [63:0]      i_symbol_pattern_2,
    input  logic [63:0]      i_symbol_pattern_3,
    input  logic [63:0]      i_symbol_pattern_4,

    // Output to Buffer FIFO
    output logic [7:0]       o_buffer_val,
    output logic             o_buffer_val_valid
);

    // Byte counter for tracking offset within the packet
    logic [10:0] byte_offset;  // Up to 1500 bytes
    
    // Internal state registers
    logic packet_type_match;
    logic [2:0] symbol_match;  // Bit mask for which symbol matched (1-4)
    
    // State machine for packet processing
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;
    
    state_t state;
    
    // Calculate which cycle contains the offset
    localparam PACKET_TYPE_CYCLE = PACKET_TYPE_OFFSET / 8;
    localparam SYMBOL_CYCLE = SYMBOL_OFFSET / 8;
    
    always_ff @(posedge clk_net or negedge aresetn) begin
        if (!aresetn) begin
            byte_offset <= 0;
            packet_type_match <= 0;
            symbol_match <= 0;
            state <= IDLE;
            o_buffer_val <= 0;
            o_buffer_val_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    o_buffer_val_valid <= 0;
                    if (i_valid && i_sop) begin
                        byte_offset <= 8;  // First cycle has 8 bytes
                        packet_type_match <= 0;
                        symbol_match <= 0;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    if (i_valid) begin
                        // Check for PACKET_TYPE at the right offset
                        if (byte_offset == (PACKET_TYPE_OFFSET + 8)) begin
                            // Data is little-endian, PACKET_TYPE is in lower 32 bits
                            if (i_data[31:0] == PACKET_TYPE_VAL) begin
                                packet_type_match <= 1;
                            end
                        end
                        
                        // Check for SYMBOL at the right offset
                        if (byte_offset == (SYMBOL_OFFSET + 8)) begin
                            if (i_data == i_symbol_pattern_1) begin
                                symbol_match <= 3'b001;  // Pattern 1
                            end else if (i_data == i_symbol_pattern_2) begin
                                symbol_match <= 3'b010;  // Pattern 2
                            end else if (i_data == i_symbol_pattern_3) begin
                                symbol_match <= 3'b011;  // Pattern 3
                            end else if (i_data == i_symbol_pattern_4) begin
                                symbol_match <= 3'b100;  // Pattern 4
                            end
                        end
                        
                        // Handle EOP
                        if (i_eop) begin
                            // Generate buffer value based on matches
                            if (packet_type_match && (symbol_match != 0)) begin
                                o_buffer_val <= {5'b0, symbol_match};
                            end else begin
                                o_buffer_val <= 0;
                            end
                            o_buffer_val_valid <= 1;
                            state <= IDLE;
                        end else begin
                            byte_offset <= byte_offset + 8;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
