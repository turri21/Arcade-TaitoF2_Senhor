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
    output     [19:0] AD,
    input      [15:0] RD,

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

wire [5:0] col_count = full_hcnt[9:4];
reg [3:0] state;

always @(posedge clk) begin
    bit [8:0] hcnt;
    bit [8:0] h, v;
    if (reset) begin
        full_hcnt <= 0;
        hcnt <= 0;
        vcnt <= 0;
    end else if (ce_13m) begin
        full_hcnt <= full_hcnt + 1;
        if (~|full_hcnt[3:0]) begin
            hcnt <= hcnt + 1;
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
wire line_start = ~&full_hcnt[9:4];

reg [15:0] bg0_rowscroll, bg1_rowscroll;
reg [15:0] bg1_colscroll;
reg [15:0] bg0_code, bg1_code;
reg [15:0] bg0_attrib, bg1_attrib;
reg [15:0] fg0_code, fg0_gfx;

always @(posedge clk) begin
    bit [8:0] h, v;
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
            0: begin
                h = hcnt + bg0_x[8:0] + bg0_rowscroll[8:0];
                v = vcnt + bg0_y[8:0];
                ram_addr <= { 3'b0_00, v[8:3], h[8:3], 1'b0 };
            end
            1: bg0_code <= SDin;
            2: ram_addr[0] <= 1;
            3: bg0_attrib <= SDin;
            4: begin
                h = hcnt;
                ram_addr <= { 9'b0111_00000, h[8:3], 1'b0 };
            end
            5: bg1_colscroll <= SDin;
            6: begin
                h = hcnt + fg0_x[8:0];
                v = vcnt + fg0_y[8:0];
                ram_addr <= { 4'b0_011, v[8:3], h[8:3] };
            end
            7: fg0_gfx <= SDin;
            8: begin
                h = hcnt + bg1_x[8:0] + bg1_rowscroll[8:0];
                v = vcnt + bg1_y[8:0] + bg1_colscroll[8:0];
                ram_addr <= { 3'b0_10, v[8:3], h[8:3], 1'b0 };
            end
            9: bg1_code <= SDin;
            10: ram_addr[0] <= 1;
            11: bg1_attrib <= SDin;
            12: begin
                h = hcnt + fg0_x[8:0];
                v = vcnt + fg0_y[8:0];
                ram_addr <= { 4'b0_010, v[8:3], h[8:3] };
            end
            13: begin
                fg0_code <= SDin;
                ram_access <= ram_pending;
            end
            14: begin
                ram_addr <= VA[16:1];
                WEUPn <= ~ram_access | UDSn | RW;
                WELOn <= ~ram_access | LDSn | RW;
            end
            15: if (ram_access) begin
                ram_access <= 0;
                ram_pending <= 0;
                dtack_n <= 0;
                Dout <= SDin;
            end
            default: begin
            end
        endcase
    end
end

endmodule

