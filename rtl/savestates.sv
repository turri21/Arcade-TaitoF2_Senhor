interface ssbus_if #(parameter COUNT = 8)();
    logic [63:0] data;
    logic [31:0] addr;
    logic [COUNT-1:0] select;
    logic write;
    logic read;
    logic query;
    logic [63:0] data_out[COUNT];
    logic [COUNT-1:0] ack;

    function logic access(int idx);
        return select[idx] & ~query & (read | write);
    endfunction

    task setup(int idx, input [31:0] count, input [1:0] width);
        if (idx >= 0) begin
            ack[idx] <= 0;
            if (select[idx] & query) begin
                data_out[idx] <= { idx[7:0], 22'b0, width, count };
                ack[idx] <= 1;
            end
        end
    endtask

    task read_response(int idx, input [63:0] dout);
        if (idx >= 0) begin
            data_out[idx] <= dout;
            ack[idx] <= 1;
        end
    endtask

    task write_ack(int idx);
        if (idx >= 0) begin
            ack[idx] <= 1;
        end
    endtask

    modport master(
        output data, addr, select, write, read, query,
        input data_out, ack
    );

    modport slave(
        input data, addr, select, write, read, query,
        output data_out, ack,
        import access,
        import setup,
        import read_response,
        import write_ack
    );
endinterface

module save_state_data(
    input clk,
    input reset,

    output     [31:0] ddr_addr,
    output     [63:0] ddr_wdata,
    input      [63:0] ddr_rdata,
    output            ddr_read,
    output            ddr_write,
    output      [7:0] ddr_burstcnt,
    output      [7:0] ddr_byteenable,
    input             ddr_busy,
    input             ddr_read_complete,

    input             read_start,
    input             write_start,
    output            busy,

    ssbus_if.master   ssbus
);

// Instantiate the memory_stream module
memory_stream memory_stream (
    .clk(clk),
    .reset(reset),

    // Memory interface
    .ddr_addr(ddr_addr),
    .ddr_wdata(ddr_wdata),
    .ddr_rdata(ddr_rdata),
    .ddr_read(ddr_read),
    .ddr_write(ddr_write),
    .ddr_burstcnt(ddr_burstcnt),
    .ddr_byteenable(ddr_byteenable),
    .ddr_busy(ddr_busy),
    .ddr_read_complete(ddr_read_complete),

    .read_req(ssbus.read),
    .read_data(ssbus.data_out),
    .data_ack(ssbus.ack),

    .write_req(ssbus.write),
    .write_data(ssbus.data),

    .start_addr(32'd0),
    .length(32'h00100000),
    .read_start(read_start),
    .write_start(write_start),
    .busy(busy),

    .chunk_select(ssbus.select),
    .chunk_address(ssbus.addr),
    .query_req(ssbus.query)
);


endmodule

