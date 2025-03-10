module tc0100scn_shifter #(
    parameter PALETTE_WIDTH=8,
    parameter PIXEL_WIDTH=4)
(
    input clk,
    input ce_pixel,
    input load,

    input [2:0] tap,
    input [(PIXEL_WIDTH * 8) - 1:0] gfx_in,
    input [PALETTE_WIDTH - 1:0] palette_in,
    output [PIXEL_WIDTH + PALETTE_WIDTH - 1:0] dot_out
);

localparam DOT_WIDTH = (PALETTE_WIDTH + PIXEL_WIDTH);
localparam SHIFT_END = (DOT_WIDTH * 16) - 1;

reg [SHIFT_END:0] shift;

assign dot_out = shift[(SHIFT_END - (DOT_WIDTH * tap)) -: DOT_WIDTH];

always_ff @(posedge clk) begin
    if (ce_pixel) begin
        shift[SHIFT_END:DOT_WIDTH] <= shift[SHIFT_END-DOT_WIDTH:0];
        if (load) begin
            int i;
            for( i = 0; i < 8; i = i + 1 ) begin
                shift[(DOT_WIDTH * i) +: DOT_WIDTH] <= { palette_in, gfx_in[(PIXEL_WIDTH * i) +: PIXEL_WIDTH] };
            end
        end
    end
end

endmodule

module TC0100SCN(
    input clk,
    input ce_13m,
    output ce_pixel, // TODO - does this generate it?

    input reset,

    // CPU interface
    input [17:1] VA,
    input [15:0] Din,
    output reg [15:0] Dout,
    input LDSn,
    input UDSn,
    input SCCSn,
    input RW,
    output DACKn,

    // RAM interface
    output     [14:0] SA,
    input      [15:0] SDin,
    output     [15:0] SDout,
    output reg        WEUPn,
    output reg        WELOn,
    output            SCE0n,
    output            SCE1n,

    // ROM interface
    output reg [20:0] rom_address,
    input      [31:0] rom_data,
    output reg        rom_req,
    input             rom_ack,


    // Video interface
    output [14:0] SC,
    output HSYNn,
    output HBLOn,
    output VSYNn,
    output VBLOn,
    output OLDH,
    output OLDV,
    input IHLD, // FIXME - confirm inputs
    input IVLD
);

reg dtack_n;
reg prev_cs_n;

reg ram_pending = 0;
reg ram_access = 0;
reg [15:0] ram_addr;


reg [9:0] full_hcnt;
reg [8:0] hcnt, vcnt;

reg [15:0] ctrl[8];

wire [15:0] bg0_x = ctrl[0];
wire [15:0] bg1_x = ctrl[1];
wire [15:0] fg0_x = ctrl[2];
wire [15:0] bg0_y = ctrl[3];
wire [15:0] bg1_y = ctrl[4];
wire [15:0] fg0_y = ctrl[5];
wire bg0_en = ~ctrl[6][0];
wire bg1_en = ~ctrl[6][1];
wire fg0_en = ~ctrl[6][2];
wire bg0_prio = ctrl[6][3];
wire wide = ctrl[6][4];
wire flip = ctrl[7][0];


assign DACKn = SCCSn ? 0 : dtack_n;
assign SA = ram_addr[14:0];
assign SCE0n = ram_addr[15];
assign SCE1n = ~ram_addr[15];
assign SDout = Din;
assign ce_pixel = ce_13m & full_hcnt[0];

assign HSYNn = full_hcnt < (320 * 2);
assign HBLOn = full_hcnt < (320 * 2);
assign VSYNn = vcnt < 200;
assign VBLOn = vcnt < 200;


assign SC = |bg0_dot[3:0] ? { 3'd0, bg0_dot } : ( |bg1_dot[3:0] ? { 3'd0, bg1_dot } : { 15'd0 } );

wire [5:0] col_count = full_hcnt[9:4];
reg [3:0] state;

always @(posedge clk) begin
    bit [8:0] h, v;
    if (reset) begin
        full_hcnt <= 0;
        hcnt <= 0;
        vcnt <= 0;
    end else if (ce_13m) begin
        full_hcnt <= full_hcnt + 1;
        if (ce_pixel) hcnt <= hcnt + 1;
        if (~|full_hcnt[3:0]) begin
            if (hcnt == 7 && col_count < 2) begin
                hcnt <= 0;
            end
        end

        if (full_hcnt == 847) begin /* 424 * 2 - 1 */
            full_hcnt <= 0;
            hcnt <= 0;
            vcnt <= vcnt + 1;
            if (vcnt == 261) begin
                vcnt <= 0;
            end
        end
    end
end

wire [3:0] access_cycle = full_hcnt[3:0];
wire line_start = ~|full_hcnt[9:4];

wire [8:0] bg0_hofs = bg0_x[8:0] + bg0_rowscroll[8:0];
wire [8:0] bg1_hofs = bg1_x[8:0] + bg1_rowscroll[8:0];
reg [31:0] bg0_gfx;
wire [31:0] bg1_gfx = rom_data;
wire [11:0] bg0_dot, bg1_dot;
reg [15:0] bg0_rowscroll, bg1_rowscroll;
reg [15:0] bg1_colscroll;
reg [15:0] bg0_code, bg1_code;
reg [15:0] bg0_attrib, bg1_attrib;
reg [15:0] fg0_code, fg0_gfx;

reg [47:0] fg_shift;

wire [31:0] bg0_gfx_swizzle = { bg0_gfx[31], bg0_gfx[23], bg0_gfx[15], bg0_gfx[7],
                                bg0_gfx[30], bg0_gfx[22], bg0_gfx[14], bg0_gfx[6],
                                bg0_gfx[29], bg0_gfx[21], bg0_gfx[13], bg0_gfx[5],
                                bg0_gfx[28], bg0_gfx[20], bg0_gfx[12], bg0_gfx[4],
                                bg0_gfx[27], bg0_gfx[19], bg0_gfx[11], bg0_gfx[3],
                                bg0_gfx[26], bg0_gfx[18], bg0_gfx[10], bg0_gfx[2],
                                bg0_gfx[25], bg0_gfx[17], bg0_gfx[ 9], bg0_gfx[1],
                                bg0_gfx[24], bg0_gfx[16], bg0_gfx[ 8], bg0_gfx[0] };


tc0100scn_shifter bg0_shift(
    .clk, .ce_pixel,
    .tap(bg0_hofs[2:0]),
    .gfx_in(bg0_gfx),
    .palette_in(bg0_attrib[7:0]),
    .dot_out(bg0_dot),
    .load(access_cycle == 15)
);

tc0100scn_shifter bg1_shift(
    .clk, .ce_pixel,
    .tap(bg1_hofs[2:0]),
    .gfx_in(bg1_gfx),
    .palette_in(bg1_attrib[7:0]),
    .dot_out(bg1_dot),
    .load(access_cycle == 15)
);

always @(posedge clk) begin
    bit [8:0] h, v;

    if (ce_pixel) begin
        fg_shift[47:2] <= fg_shift[45:0];
    end

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
            if (VA[17]) begin // control access
                if (RW) begin
                    Dout <= ctrl[VA[3:1]];
                end else begin
                    if (~UDSn) ctrl[VA[3:1]][15:8] <= Din[15:8];
                    if (~LDSn) ctrl[VA[3:1]][7:0]  <= Din[7:0];
                end
                dtack_n <= 0;
            end else begin // ram access
                ram_pending <= 1;
            end
        end else if (SCCSn) begin
            dtack_n <= 1;
        end

        case(access_cycle)
            // BG0 Address Attrib or Rowscroll
            0: begin
                if (line_start) begin
                    ram_addr <= { 8'b0_11_00000, vcnt[7:0] };
                end else begin
                    h = hcnt + bg0_hofs;
                    v = vcnt + bg0_y[8:0];
                    ram_addr <= { 3'b0_00, v[8:3], h[8:3], 1'b0 };
                end
            end
            // BG0 Store Attrib or Rowscroll
            1: begin
                if (line_start) begin
                    bg0_rowscroll <= SDin;
                end else begin
                    bg0_attrib <= SDin;
                end
            end
            // BG0 Address Tile code
            2: ram_addr[0] <= 1;
            // BG0 Store Tile code, start ROM read
            3: begin
                bg0_code <= SDin;
                v = vcnt + bg0_y[8:0];
                rom_address <= { SDin, v[2:0], 2'b0 };
                rom_req <= ~rom_req;
            end
            // BG1 Address Colscroll
            4: begin
                h = hcnt;
                ram_addr <= { 10'b0111_000000, h[8:3] };
            end
            // BG1 Store Colscroll
            5: bg1_colscroll <= SDin;
            // FG0 Address GFX
            6: begin
                v = vcnt + fg0_y[8:0];
                ram_addr <= { 5'b0_0110, fg0_code[7:0], v[2:0] };
            end
            // FG0 Store GFX
            7: fg0_gfx <= SDin;
            // BG1 Address Attrib or Rowscroll
            8: begin
                if (line_start) begin
                    ram_addr <= { 8'b01100010, vcnt[7:0] };
                end else begin
                    h = hcnt + bg1_hofs;
                    v = vcnt + bg1_y[8:0] + bg1_colscroll[8:0];
                    ram_addr <= { 3'b0_10, v[8:3], h[8:3], 1'b0 };
                end
            end
            // BG1 Store Attrib or Rowscroll
            9: begin
                if (line_start) begin
                    bg1_rowscroll <= SDin;
                end else begin
                    bg1_attrib <= SDin;
                end
            end
            // BG1 Address Tile code
            10: ram_addr[0] <= 1;
            // BG1 Store Tile code, start ROM read
            11: begin
                bg1_code <= SDin;

                bg0_gfx <= rom_data;
                v = vcnt + bg1_y[8:0] + bg1_colscroll[8:0];
                rom_address <= { SDin, v[2:0], 2'b0 };
                rom_req <= ~rom_req;
            end
            // FG0 Address tile code
            12: begin
                h = hcnt + fg0_x[8:0];
                v = vcnt + fg0_y[8:0];
                ram_addr <= { 4'b0_010, v[8:3], h[8:3] };
            end
            // FG0 Store tile code
            13: begin
                fg0_code <= SDin;
                ram_access <= ram_pending;
            end
            // Address CPU access
            14: begin
                ram_addr <= VA[16:1];
                WEUPn <= ~ram_access | UDSn | RW;
                WELOn <= ~ram_access | LDSn | RW;

                fg_shift[15:0] <= { fg0_gfx[15], fg0_gfx[7],
                                    fg0_gfx[14], fg0_gfx[6],
                                    fg0_gfx[13], fg0_gfx[5],
                                    fg0_gfx[12], fg0_gfx[4],
                                    fg0_gfx[11], fg0_gfx[3],
                                    fg0_gfx[10], fg0_gfx[2],
                                    fg0_gfx[ 9], fg0_gfx[1],
                                    fg0_gfx[ 8], fg0_gfx[0] };
            end
            // Finish CPU access
            15: begin
                if (ram_access) begin
                    ram_access <= 0;
                    ram_pending <= 0;
                    dtack_n <= 0;
                    Dout <= SDin;
                end
            end
            default: begin
            end
        endcase
    end
end

endmodule

