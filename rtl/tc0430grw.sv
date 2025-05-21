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
    output reg [11:0] SA,
    input      [15:0] SDin,
    output     [15:0] SDout,
    output reg        WEUPn,
    output reg        WELOn,

    // ROM interface
    output reg [26:0] rom_address,
    input      [15:0] rom_data,
    output reg        rom_req,
    input             rom_ack,


    // Video interface
    output reg [5:0] SC,

    // assume it is positioned using sync,
    // FIXME - confirm what video signals are inputs
    input HBLANKn,
    input VBLANKn,

    ssbus_if.slave ssbus
);

reg dtack_n;
reg prev_cs_n;

reg ram_pending = 0;
reg ram_access = 0;

reg [15:0] ctrl[8];

wire [23:0] origin_x = { ctrl[0][7:0], ctrl[1] };
wire [23:0] dxx = { {8{ctrl[2][15]}}, ctrl[2] };
wire [23:0] dyx = { {8{ctrl[6][15]}}, ctrl[6] };
wire [23:0] origin_y = { ctrl[4][7:0], ctrl[5] };
wire [23:0] dxy = { {8{ctrl[3][15]}}, ctrl[3] };
wire [23:0] dyy = { {8{ctrl[7][15]}}, ctrl[7] };


assign DACKn = SCCSn ? 0 : dtack_n;
assign SDout = Din;

reg [23:0] row_x, row_y;
reg [23:0] cur_x, cur_y;

wire [2:0] pixel_x = cur_x[14:12];
wire [5:0] tile_x = cur_x[20:15];
wire [2:0] pixel_y = cur_y[14:12];
wire [5:0] tile_y = cur_y[20:15];


reg prev_vblank_n, prev_hblank_n;

//assign SC = { 4'b0, tile_x[0] ^ tile_y[0], 1'b1 };

always @(posedge clk) begin
    if (ce_pixel) begin
        prev_hblank_n <= HBLANKn;
        prev_vblank_n <= VBLANKn;

        if (~HBLANKn & prev_hblank_n & VBLANKn) begin
            row_x <= row_x + dxy;
            row_y <= row_y + dyy;
            cur_x <= row_x + dxy;
            cur_y <= row_y + dyy;
        end else if (~VBLANKn & prev_vblank_n) begin
            row_x <= origin_x;
            row_y <= origin_y;
            cur_x <= origin_x;
            cur_y <= origin_y;
        end else if (VBLANKn & HBLANKn ) begin
            cur_x <= cur_x + dxx;
            cur_y <= cur_y + dyx;
        end
    end
end

//wire [3:0] access_cycle = full_hcnt[3:0];

reg [1:0] color_hi;
reg [1:0] nibble;
reg valid_pixel;

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
                ram_pending <= 1;
            end
        end else if (SCCSn) begin
            dtack_n <= 1;
        end

        if (ce_pixel) begin
            if (|SDin[13:0]) begin
                rom_address <= PIVOT_ROM_SDR_BASE[26:0] + { 8'b0, SDin[13:0], pixel_y[2:0], pixel_x[2], 1'b0 };
                rom_req <= ~rom_req;
                color_hi <= SDin[15:14];
                nibble <= pixel_x[1:0];
                valid_pixel <= 1;
            end else begin
                valid_pixel <= 0;
            end

            if (valid_pixel) begin
                case(nibble)
                1: SC <= { color_hi, rom_data[ 3:0 ] };
                0: SC <= { color_hi, rom_data[ 7:4 ] };
                3: SC <= { color_hi, rom_data[ 11:8 ] };
                2: SC <= { color_hi, rom_data[ 15:12 ] };
                endcase
            end else begin
                SC <= 6'd0;
            end

            SA <= VA[11:0];
            if (ram_pending) begin
                WELOn <= RW | LDSn;
                WEUPn <= RW | UDSn;
                ram_access <= 1;
                ram_pending <= 0;
            end
        end else begin
            SA <= { tile_y, tile_x };
            if (ram_access) begin
                Dout <= SDin;
                dtack_n <= 0;
                ram_access <= 0;
            end
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

