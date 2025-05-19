// Don't know what the pin names are, so basing them on TC0100SCN

module TC0430GRW #(parameter SS_IDX=-1) (
    input clk,
    input ce_13m,
    input ce_pixel,

    input reset,

    // CPU interface
    input [12:0] VA,
    input [15:0] Din,
    output reg [15:0] Dout,
    input LDSn,
    input UDSn,
    input SCCSn,
    input RW,
    output DACKn,

    // RAM interface
    output     [11:0] SA,
    input      [15:0] SDin,
    output     [15:0] SDout,
    output reg        WEUPn,
    output reg        WELOn,

    // ROM interface
    output reg [20:0] rom_address,
    input      [15:0] rom_data,
    output reg        rom_req,
    input             rom_ack,


    // Video interface
    output [5:0] SC,

    // assume it is positioned using sync,
    // FIXME - confirm what video signals are inputs
    input HSYNn,
    input VSYNn,

    ssbus_if.slave ssbus
);

reg dtack_n;
reg prev_cs_n;

reg ram_pending = 0;
reg ram_access = 0;
reg [11:0] ram_addr;

reg [15:0] ctrl[8];

wire [23:0] origin_x = { ctrl[0][7:0], ctrl[1] };
wire [23:0] dxx = { {8{ctrl[2][15]}}, ctrl[2] };
wire [23:0] dyx = { {8{ctrl[3][15]}}, ctrl[3] };
wire [23:0] origin_y = { ctrl[4][7:0], ctrl[5] };
wire [23:0] dxy = { {8{ctrl[6][15]}}, ctrl[6] };
wire [23:0] dyy = { {8{ctrl[7][15]}}, ctrl[7] };


assign DACKn = SCCSn ? 0 : dtack_n;
assign SA = ram_addr[11:0];
assign SDout = Din;

reg [23:0] row_x, row_y;
reg [23:0] cur_x, cur_y;

reg prev_vsync_n, prev_hsync_n;

assign SC = { 4'b0, cur_x[16] ^ cur_y[16], 1'b1 };

always @(posedge clk) begin
    if (ce_pixel) begin
        prev_hsync_n <= HSYNn;
        prev_vsync_n <= VSYNn;

        if (HSYNn & ~prev_hsync_n) begin
            row_x <= row_x + dxy;
            row_y <= row_y + dyy;
            cur_x <= row_x + dxy;
            cur_y <= row_y + dyy;
        end else if (VSYNn & ~prev_vsync_n) begin
            row_x <= origin_x;
            row_y <= origin_y;
            cur_x <= origin_x;
            cur_y <= origin_y;
        end else begin
            cur_x <= cur_x + dxx;
            cur_y <= cur_y + dyx;
        end
    end
end

//wire [3:0] access_cycle = full_hcnt[3:0];

always @(posedge clk) begin
    bit [8:0] v;
    bit [5:0] h;

    if (reset) begin
        dtack_n <= 1;
        ram_pending <= 0;
        ram_access <= 0;
    end else if (ce_13m) begin
        WEUPn <= 1;
        WELOn <= 1;
        // CPu interface handling
        prev_cs_n <= SCCSn;
        if (~SCCSn & prev_cs_n) begin // CS edge
            if (VA[12]) begin // control access
                if (RW) begin
                    Dout <= ctrl[VA[2:0]];
                end else begin
                    if (~UDSn) ctrl[VA[2:0]][15:8] <= Din[15:8];
                    if (~LDSn) ctrl[VA[2:0]][7:0]  <= Din[7:0];
                end
                dtack_n <= 0;
            end else begin // ram access
                dtack_n <= 0; //FIXME
                ram_pending <= 1;
            end
        end else if (SCCSn) begin
            dtack_n <= 1;
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

endmodule

