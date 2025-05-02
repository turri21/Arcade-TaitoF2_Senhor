module TC0360PRI #(parameter SS_IDX=-1) (
    input clk,
    input ce_pixel,
    input reset,

    // CPU Interface
    input [15:0] cpu_din,
    output reg [15:0] cpu_dout,

    input        cs,
    input [2:0]  cpu_addr,
    input cpu_rw,
    input [1:0] cpu_ds_n,

    input [13:0] color_in0,
    input [13:0] color_in1,
    input [13:0] color_in2,
    output reg [13:0] color_out,

    ssbus_if.slave ssbus
);

reg [15:0] ctrl[8];

always_ff @(posedge clk) begin
    if (reset) begin
        ctrl[0] <= 0;
        ctrl[1] <= 0;
        ctrl[2] <= 0;
        ctrl[3] <= 0;
        ctrl[4] <= 0;
        ctrl[5] <= 0;
        ctrl[6] <= 0;
        ctrl[7] <= 0;
    end else begin
        if (cs) begin
            if (cpu_rw) begin
                cpu_dout <= ctrl[cpu_addr[2:0]];
            end else begin
                if (~cpu_ds_n[1]) ctrl[cpu_addr[2:0]][15:8] <= cpu_din[15:8];
                if (~cpu_ds_n[0]) ctrl[cpu_addr[2:0]][7:0]  <= cpu_din[7:0];
            end
        end

        ssbus.setup(SS_IDX, 8, 1);
        if (ssbus.access(SS_IDX)) begin
            if (ssbus.write) begin
                ctrl[ssbus.addr[2:0]] <= ssbus.data[15:0];
                ssbus.write_ack(SS_IDX);
            end else if (ssbus.read) begin
                ssbus.read_response(SS_IDX, { 48'b0, ctrl[ssbus.addr[2:0]] });
            end
        end
    end
end


wire [1:0] sel0 = color_in0[13:12];
wire [1:0] sel1 = color_in1[13:12];
wire [1:0] sel2 = ctrl[0][15:14];

wire [3:0] prio0 = ctrl[2][ 4 * sel0 +: 4 ];
wire [3:0] prio1 = ctrl[3][ 4 * sel1 +: 4 ];
wire [3:0] prio2 = ctrl[4][ 4 * sel1 +: 4 ];


always_ff @(posedge clk) begin
    if (ce_pixel) begin
        color_out <= color_in0;
        if (prio1 > prio0) begin
            if (prio2 > prio1) begin
                color_out <= color_in2;
            end else begin
                color_out <= color_in1;
            end
        end else if (prio2 > prio0) begin
            color_out <= color_in2;
        end
    end
end


endmodule
