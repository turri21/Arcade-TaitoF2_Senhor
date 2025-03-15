module memory_stream
(
    input               clk,
    input               reset,

    // Memory interface (64-bit bus)
    output reg [31:0]   mem_addr,
    output reg [63:0]   mem_wdata,
    input      [63:0]   mem_rdata,
    output reg          mem_read,
    output reg          mem_write,
    input               mem_busy,
    input               mem_read_complete,

    // 8-bit stream interface for reading from memory
    output reg          write_req,
    output reg [63:0]   write_data,
    input               data_ack,

    // 8-bit stream interface for writing to memory
    output reg          read_req,
    input      [63:0]   read_data,

    // Control signals
    input      [31:0]   start_addr,
    input      [31:0]   length,
    input               read_start,
    input               write_start,

    output reg          query_req,
    output reg [31:0]   chunk_address,
    output reg [7:0]    chunk_index,

    output              busy
);

    typedef enum
    {
        IDLE,
        READ_MEM_REQ,
        READ_MEM_WAIT,
        READ_STREAM,
        WRITE_GATHER,
        WRITE_MEM_REQ,
        WRITE_MEM_WAIT,
        QUERY_GATHER_NEXT,
        QUERY_GATHER_WAIT,
        QUERY_SCATTER_WAIT
    } state_t;

    state_t state;

    assign busy = state != IDLE;

    logic [2:0] word_end[4] = { 3'b111, 3'b011, 3'b001, 3'b000 };

    // Counters for reading/writing
    reg [31:0] end_addr;
    reg [31:0] current_addr;
    reg [2:0]  word_counter;  // 0-7 for tracking position in 64-bit word
    reg [63:0] buffer;        // Buffer for read/write operations
    reg [31:0] chunk_remaining;
    reg [3:0]  query_delay;
    reg [1:0]  chunk_width;


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            mem_read <= 0;
            mem_write <= 0;
            write_req <= 0;
            read_req <= 0;
            word_counter <= 0;
            query_req <= 0;
            chunk_index <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    // Default signals
                    mem_read <= 0;
                    mem_write <= 0;
                    write_req <= 0;
                    read_req <= 0;
                    chunk_index <= 0;
                    chunk_remaining <= 0;
                    current_addr <= start_addr;
                    end_addr <= start_addr + length;
                    word_counter <= 0;
                    buffer <= 64'h0;

                    // Check for start signals
                    if (read_start) begin
                        state <= READ_MEM_REQ;
                    end else if (write_start) begin
                        state <= QUERY_GATHER_NEXT;
                    end
                end

                READ_MEM_REQ: begin
                    if (current_addr >= end_addr) begin
                        state <= IDLE;
                    end else if (!mem_busy) begin
                        mem_addr <= current_addr & 32'hFFFFFFF8; // Align to 8-byte boundary
                        current_addr <= current_addr + 8;
                        mem_read <= 1;
                        state <= READ_MEM_WAIT;
                    end
                end

                READ_MEM_WAIT: begin
                    mem_read <= 0;
                    if (mem_read_complete) begin
                        buffer <= mem_rdata;
                        if (chunk_remaining == 0) begin
                            if (&mem_rdata[63:56]) begin
                                state <= IDLE;
                            end else begin
                                chunk_remaining <= mem_rdata[31:0];
                                chunk_width <= mem_rdata[33:32];
                                chunk_index <= mem_rdata[63:56];
                                write_req <= 1;
                                query_req <= 1;
                                query_delay <= 0;
                                state <= QUERY_SCATTER_WAIT;
                            end
                        end else begin
                            state <= READ_STREAM;
                        end
                    end
                end

                QUERY_SCATTER_WAIT: begin
                    if (data_ack) begin
                        query_req <= 0;
                        write_req <= 0;
                        state <= READ_MEM_REQ;
                        chunk_address <= 0;
                    end else if (&query_delay) begin
                        write_req <= 0;
                        query_req <= 0;
                        current_addr <= current_addr + ((chunk_remaining + 32'd7) & 32'hFFFFFFF8);
                        chunk_remaining <= 0;
                        state <= READ_MEM_REQ;
                    end else begin
                        query_delay <= query_delay + 1;
                    end
                end

                READ_STREAM: begin
                    if (chunk_remaining == 0) begin
                        // Done with all reading
                        state <= READ_MEM_REQ;
                        write_req <= 0;
                    end else begin
                        case(chunk_width)
                            0: case (word_counter)
                                3'd0: write_data[7:0] <= buffer[7:0];
                                3'd1: write_data[7:0] <= buffer[15:8];
                                3'd2: write_data[7:0] <= buffer[23:16];
                                3'd3: write_data[7:0] <= buffer[31:24];
                                3'd4: write_data[7:0] <= buffer[39:32];
                                3'd5: write_data[7:0] <= buffer[47:40];
                                3'd6: write_data[7:0] <= buffer[55:48];
                                3'd7: write_data[7:0] <= buffer[63:56];
                                default: begin end
                            endcase
                            1: case (word_counter)
                                3'd0: write_data[15:0] <= buffer[15:0];
                                3'd1: write_data[15:0] <= buffer[31:16];
                                3'd2: write_data[15:0] <= buffer[47:32];
                                3'd3: write_data[15:0] <= buffer[63:48];
                                default: begin end
                            endcase
                            2: case (word_counter)
                                3'd0: write_data[31:0] <= buffer[31:0];
                                3'd1: write_data[31:0] <= buffer[63:32];
                                default: begin end
                            endcase
                            3: begin
                                write_data[63:0] <= buffer[63:0];
                            end
                        endcase

                        if (data_ack & write_req) begin
                            // Advance to next byte
                            if (word_counter == word_end[chunk_width]) begin
                                // Need to fetch next word
                                word_counter <= 0;
                                state <= READ_MEM_REQ;
                            end
                            else begin
                                word_counter <= word_counter + 1;
                            end

                            chunk_remaining <= chunk_remaining - 1;
                            chunk_address <= chunk_address + 1;
                            write_req <= 0;
                        end else if (~write_req) begin
                            write_req <= 1;
                        end
                    end
                end

                QUERY_GATHER_NEXT: begin
                    if (chunk_index == 254) begin
                        buffer <= ~64'd0;
                        chunk_remaining <= 0;
                        chunk_index <= 255;
                        state <= WRITE_MEM_REQ;
                    end else if (chunk_index == 255) begin
                        state <= IDLE;
                    end else begin
                        chunk_index <= chunk_index + 1;
                        read_req <= 1;
                        query_req <= 1;
                        state <= QUERY_GATHER_WAIT;
                        query_delay <= 0;
                    end
                end

                QUERY_GATHER_WAIT: begin
                    if (data_ack) begin
                        chunk_remaining <= read_data[31:0];
                        chunk_width <= read_data[33:32];
                        buffer[33:0] <= read_data[33:0];
                        buffer[63:56] <= chunk_index;
                        chunk_address <= 0;
                        query_req <= 0;
                        read_req <= 0;
                        state <= WRITE_MEM_REQ;
                    end else if (&query_delay) begin
                        state <= QUERY_GATHER_NEXT;
                    end else begin
                        query_delay <= query_delay + 1;
                    end
                end

                WRITE_GATHER: begin
                    // Wait for incoming data
                    if (chunk_remaining == 0) begin
                        // Check if we have partially filled buffer to write
                        if (word_counter != 0) begin
                            state <= WRITE_MEM_REQ;
                        end
                        else begin
                            state <= QUERY_GATHER_NEXT;
                        end
                    end
                    else if (data_ack & read_req) begin
                        // Store incoming byte in buffer
                        case (chunk_width)
                            0: case (word_counter)
                                3'd0: buffer[7:0] <= read_data[7:0];
                                3'd1: buffer[15:8] <= read_data[7:0];
                                3'd2: buffer[23:16] <= read_data[7:0];
                                3'd3: buffer[31:24] <= read_data[7:0];
                                3'd4: buffer[39:32] <= read_data[7:0];
                                3'd5: buffer[47:40] <= read_data[7:0];
                                3'd6: buffer[55:48] <= read_data[7:0];
                                3'd7: buffer[63:56] <= read_data[7:0];
                                default: begin end
                            endcase
                            1: case (word_counter)
                                3'd0: buffer[15:0] <= read_data[15:0];
                                3'd1: buffer[31:16] <= read_data[15:0];
                                3'd2: buffer[47:32] <= read_data[15:0];
                                3'd3: buffer[63:48] <= read_data[15:0];
                                default: begin end
                            endcase
                            2: case (word_counter)
                                3'd0: buffer[31:0] <= read_data[31:0];
                                3'd1: buffer[63:32] <= read_data[31:0];
                                default: begin end
                            endcase
                            3: begin
                                buffer[63:0] <= read_data[63:0];
                            end
                        endcase

                        if (word_counter == word_end[chunk_width]) begin
                            // Buffer full, write to memory
                            word_counter <= 0;
                            state <= WRITE_MEM_REQ;
                        end
                        else begin
                            word_counter <= word_counter + 1;
                        end

                        chunk_remaining <= chunk_remaining - 1;
                        chunk_address <= chunk_address + 1;
                        read_req <= 0;
                    end else if (~read_req) begin
                        read_req <= 1;
                    end
                end

                WRITE_MEM_REQ: begin
                    if (current_addr >= end_addr) begin
                        state <= IDLE;
                    end else if (!mem_busy) begin
                        mem_addr <= current_addr & 32'hFFFFFFF8; // Align to 8-byte boundary
                        current_addr <= current_addr + 8;
                        mem_wdata <= buffer;
                        mem_write <= 1;
                        state <= WRITE_MEM_WAIT;
                    end
                end

                WRITE_MEM_WAIT: begin
                    mem_write <= 0;
                    if (!mem_busy) begin
                        if (chunk_remaining == 0) begin
                            state <= QUERY_GATHER_NEXT;
                        end
                        else begin
                            state <= WRITE_GATHER;
                            buffer <= 64'h0;
                        end
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

