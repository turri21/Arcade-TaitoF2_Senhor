module TC0200OBJ #(parameter SS_IDX=-1) (
    input clk,

    input ce_13m,
    input ce_pixel,

    output reg [14:0] RA,
    input [15:0] Din,
    output [15:0] Dout,

    input RESET,
    output reg ERCSn, // TODO - what generates this
    output reg EBUSY,
    output reg RDWEn,

    output reg EDMAn, // TODO - is dma started by vblank?

    output [11:0] DOT,

    input EXHBLn,
    input EXVBLn,

    output reg HSYNCn,
    output reg VSYNCn,
    output reg HBLn,
    output reg VBLn,

    ddr_if.to_host ddr,

    ssbus_if.slave ssbus
);

ddr_if ddr_obj(), ddr_fb();

ddr_mux ddr_mux(
    .clk,
    .x(ddr),
    .a(ddr_obj),
    .b(ddr_fb)
);

// TODO
// State machine
//  DMA process
//  Iterate for drawing
//  Double buffering weirdness
// SDR ROM interface
// DDR framebuffer


// 256 cycles per sprite (13mhz)
// 213760 cycles total, 835 sprites
// 222176 cycles entire frame


// DDR Framebuffer Layout
// 512x512x16bpp x 2
// 10 bits of column address
// 8 bits of row address
// 1 bit of framebuffer address
// B_RRRRRRRR_CCCCCCCCCC
// 0x00000 - 0x7ffff

reg [15:0] work_buffer[8];
wire [13:0] inst_tile_code       =  work_buffer[0][13:0];
wire [7:0]  inst_x_zoom          =  work_buffer[1][7:0];
wire [7:0]  inst_y_zoom          =  work_buffer[1][15:8];
wire [11:0] inst_x_coord         =  work_buffer[6][11:0];
wire        inst_latch_extra     =  work_buffer[6][12];
wire        inst_latch_master    =  work_buffer[6][13];
wire        inst_use_extra       = ~work_buffer[6][14];
wire        inst_use_scroll      = ~work_buffer[6][15];
wire [11:0] inst_y_coord         =  work_buffer[7][11:0];
wire        inst_is_cmd          =  work_buffer[7][15];
wire [2:0]  inst_unk1            =  work_buffer[7][14:12];
wire [7:0]  inst_color           =  work_buffer[4][7:0];
wire        inst_x_flip          =  work_buffer[4][8];
wire        inst_y_flip          =  work_buffer[4][9];
wire        inst_use_latch_color = ~work_buffer[4][10];
wire        inst_next_seq        =  work_buffer[4][11];
wire        inst_use_latch_y     =  work_buffer[4][12];
wire        inst_inc_y           =  work_buffer[4][13];
wire        inst_use_latch_x     =  work_buffer[4][14];
wire        inst_inc_x           =  work_buffer[4][15];


typedef enum
{
    ST_IDLE = 0,
    ST_DMA_INIT,
    ST_DMA,
    ST_DRAW_INIT,
    ST_READ_START,
    ST_READ,
    ST_EVAL,
    ST_CHECK_BOUNDS,
    ST_READ_TILE,
    ST_READ_TILE_WAIT,
    ST_DRAW_ROW,
    ST_DRAW_ROW_WAIT
} draw_state_t;

draw_state_t obj_state = ST_IDLE;


reg [12:0] dma_cycle;
wire [14:0] dma_addr = {2'b00, dma_cycle[12:3], 3'b000};

reg scanout_buffer = 0;
wire draw_buffer = ~scanout_buffer;
reg fb_dirty[2 * 128 * 256];
reg [15:0] fb_dirty_scan_addr, fb_dirty_draw_addr, fb_dirty_base_addr;

reg [11:0] master_x, master_y, extra_x, extra_y;
reg [11:0] latch_x, latch_y;
reg prev_vbl_n, vbl_edge;

reg [31:0] draw_addr;
reg [3:0] draw_row;
reg [1:0] draw_col;

reg [(6 * 16)-1:0] tile_row[16];
reg [4:0] tile_burst;

function bit [(6 * 4)-1:0] deswizzle(input [31:0] d);
    bit [(6 * 4)-1:0] r;
    r[5:0]   = {d[17:16], d[3:0]};
    r[11:6]  = {d[19:18], d[7:4]};
    r[17:12] = {d[21:20], d[11:8]};
    r[23:18] = {d[23:22], d[15:12]};
    return r;
endfunction

function bit [63:0] to_16bpp(input [(6*16)-1:0] row, input [1:0] offset, input [7:0] color);
    bit [63:0] r;
    r[15:0]  = { 2'd0, color, row[ 0+(offset*24) +: 6] };
    r[31:16] = { 2'd0, color, row[ 6+(offset*24) +: 6] };
    r[47:32] = { 2'd0, color, row[12+(offset*24) +: 6] };
    r[63:48] = { 2'd0, color, row[18+(offset*24) +: 6] };
    return r;
endfunction




always @(posedge clk) begin
    bit [11:0] base_x, base_y;
    ddr_obj.acquire <= 0;

    prev_vbl_n <= VBLn;
    if (prev_vbl_n & ~VBLn) begin
        vbl_edge <= 1;
    end

    case(obj_state)
        ST_IDLE: begin
            ddr_obj.read <= 0;
            ddr_obj.write <= 0;

            EBUSY <= 0;
            ERCSn <= 1;
            RDWEn <= 1;
            EDMAn <= 1;

            if (vbl_edge) begin
                vbl_edge <= 0;
                obj_state <= ST_DMA_INIT;
            end
        end

        ST_DMA_INIT: begin
            EBUSY <= 1;
            EDMAn <= 0;
            dma_cycle <= 0;
            scanout_buffer <= ~scanout_buffer;
            obj_state <= ST_DMA;
        end

        ST_DMA: if (ce_13m) begin
            dma_cycle <= dma_cycle + 1;
            ERCSn <= 0;

            if (dma_cycle == 8191) begin
                EBUSY <= 0;
                RDWEn <= 1;
                ERCSn <= 1;
                EDMAn <= 1;
                obj_state <= ST_DRAW_INIT;
            end

            unique case (dma_cycle[2:0])
                0: begin
                    RA <= dma_addr + 15'd2;
                end
                1: work_buffer[1] <= Din;
                2: begin
                    RA <= dma_addr + 15'd3;
                end
                3: work_buffer[2] <= Din;
                4: begin
                    RA <= dma_addr + 15'd6;
                    Dout <= work_buffer[1];
                    RDWEn <= 0;
                end
                5: RDWEn <= 1;
                6: begin
                    RA <= dma_addr + 15'd7;
                    Dout <= work_buffer[2];
                    RDWEn <= 0;
                end
                7: RDWEn <= 1;
            endcase

        end
        ST_DRAW_INIT: begin
            RA <= 0;
            RDWEn <= 1;
            obj_state <= ST_READ_START;
        end

        ST_READ_START: if (ce_13m) begin
            if (RA[12:3] == 835 || vbl_edge) begin
                obj_state <= ST_IDLE;
            end else begin
                EBUSY <= 1;
                ERCSn <= 0;
                obj_state <= ST_READ;
            end
        end

        ST_READ: if (ce_13m) begin
            RA <= RA + 15'd1;
            work_buffer[RA[2:0]] <= Din;
            if (RA[2:0] == 3'b111) begin
                obj_state <= ST_EVAL;
                EBUSY <= 0;
                ERCSn <= 1;
            end
        end

        ST_EVAL: begin
            if (inst_is_cmd) begin
            end

            base_x = inst_x_coord + (inst_use_scroll ? ( master_x + (inst_use_extra ? extra_x : 12'd0) ) : 12'd0);
            base_y = inst_y_coord + (inst_use_scroll ? ( master_y + (inst_use_extra ? extra_y : 12'd0) ) : 12'd0);

            if (inst_latch_extra) begin
                extra_x <= base_x;
                extra_y <= base_y;
            end

            if (inst_latch_master) begin
                master_x <= base_x;
                master_y <= base_y;
            end

            if (inst_use_latch_y) begin
                latch_y <= latch_y + {7'd0, inst_inc_y, 4'd0};
            end else begin
                latch_y <= base_y + {7'd0, inst_inc_y, 4'd0};
            end
            if (inst_use_latch_x) begin
                latch_x <= latch_x + {7'd0, inst_inc_x, 4'd0};
            end else begin
                latch_x <= base_x + {7'd0, inst_inc_x, 4'd0};
            end

            if (inst_tile_code == 0) begin
                obj_state <= ST_READ_START;
            end else begin
                obj_state <= ST_CHECK_BOUNDS;
            end
        end

        ST_CHECK_BOUNDS: begin
            draw_addr <= OBJ_FB_DDR_BASE + { 13'd0, draw_buffer, latch_y[7:0], latch_x[8:2], 3'b000 };
            fb_dirty_draw_addr <= { draw_buffer, latch_y[7:0], latch_x[8:2] };
            fb_dirty_base_addr <= { draw_buffer, latch_y[7:0], latch_x[8:2] };
            if (latch_x > 400) begin
                obj_state <= ST_READ_START;
            end else if (latch_y > 240) begin
                obj_state <= ST_READ_START;
            end else begin
                obj_state <= ST_READ_TILE;
            end
        end

        ST_READ_TILE: begin
            ddr_obj.acquire <= 1;
            if (~ddr_obj.busy) begin
                ddr_obj.read <= 1;
                ddr_obj.burstcnt <= 32;
                ddr_obj.addr <= OBJ_DATA_DDR_BASE + {10'd0, inst_tile_code, 8'd0};
                tile_burst <= 0;
                obj_state <= ST_READ_TILE_WAIT;
            end
        end

        ST_READ_TILE_WAIT: begin
            ddr_obj.acquire <= 1;
            if (~ddr_obj.busy) begin
                ddr_obj.read <= 0;
                if (ddr_obj.rdata_ready) begin
                    tile_burst <= tile_burst + 1;
                    if (~tile_burst[0]) begin
                        tile_row[tile_burst[4:1]][(6*4)-1:0] <= deswizzle(ddr_obj.rdata[31:0]);
                        tile_row[tile_burst[4:1]][(6*8)-1:(6*4)] <= deswizzle(ddr_obj.rdata[63:32]);
                    end else begin
                        tile_row[tile_burst[4:1]][(6*12)-1:(6*8)] <= deswizzle(ddr_obj.rdata[31:0]);
                        tile_row[tile_burst[4:1]][(6*16)-1:(6*12)] <= deswizzle(ddr_obj.rdata[63:32]);
                    end

                    if (tile_burst == 31) begin
                        obj_state <= ST_DRAW_ROW;
                        draw_row <= 0;
                        draw_col <= 0;
                    end
                end
            end
        end

        ST_DRAW_ROW: begin
            ddr_obj.acquire <= 1;
            if (~ddr_obj.busy) begin
                ddr_obj.addr <= draw_addr + {13'd0, 1'd0, 4'd0, draw_row, 5'd0, draw_col, 3'b000 };
                ddr_obj.write <= 1;
                ddr_obj.burstcnt <= 1;
                ddr_obj.wdata <= to_16bpp(tile_row[draw_row], draw_col, inst_color);
                ddr_obj.byteenable <= 8'hff;
                draw_col <= draw_col + 1;
                if (draw_col == 3) begin
                    draw_row <= draw_row + 1;
                    if (draw_row == 15) begin
                        obj_state <= ST_DRAW_ROW_WAIT;
                    end
                end

                fb_dirty[fb_dirty_draw_addr] <= 1;
                fb_dirty_draw_addr <= fb_dirty_base_addr + { 5'd0, draw_row, 5'd0, draw_col };
             end
        end

        ST_DRAW_ROW_WAIT: begin
            ddr_obj.acquire <= 1;
            if (~ddr_obj.busy) begin
                fb_dirty[fb_dirty_draw_addr] <= 1;
                ddr_obj.write <= 0;
                obj_state <= ST_READ_START;
            end
        end


        default: begin
            obj_state <= ST_IDLE;
        end
    endcase
end



// Scan out
//

wire [8:0] H_START = 0;
wire [8:0] H_END = 424 - 1;
wire [8:0] HS_START = 400;
wire [8:0] HS_END = 408;
wire [8:0] HB_START = 320 - 1;
wire [8:0] HB_END = H_END;

wire [7:0] VS_START = 226;
wire [7:0] VS_END = 230;
wire [7:0] VB_START = 224 - 1;
wire [7:0] VB_END = 255;
wire [7:0] V_EXVBL_RESET = 8'hfa; // from signal trace


reg [8:0] hcnt;
reg [7:0] vcnt;
reg [63:0] line_buffer0[128];
reg [63:0] line_buffer1[128];
reg [6:0] burstidx;

wire [6:0] lb0_addr = vcnt[0] ? burstidx : (hcnt[8:2] + 6'd4);
wire [6:0] lb1_addr = ~vcnt[0] ? burstidx : (hcnt[8:2] + 6'd4);
wire [63:0] lb_dout = vcnt[0] ? line_buffer1[lb1_addr] : line_buffer0[lb0_addr];

reg ex_vbl_n_prev, vbl_n_prev;
reg ex_vbl_end, vbl_start;
reg scanout_active;
reg scanout_newline;

typedef enum { SCAN_IDLE, SCAN_START_READ, SCAN_WAIT_READ } scan_state_t;

scan_state_t scan_state = SCAN_IDLE;

always_comb begin
    unique case (hcnt[1:0])
        0: DOT = lb_dout[11:0];
        1: DOT = lb_dout[27:16];
        2: DOT = lb_dout[43:32];
        3: DOT = lb_dout[59:48];
    endcase
end

assign ddr_fb.write = 0;

always_ff @(posedge clk) begin
    if (ce_pixel) begin
        ex_vbl_n_prev <= EXVBLn;
        vbl_n_prev <= VBLn;
        if (EXVBLn & ~ex_vbl_n_prev) begin
            ex_vbl_end <= 1;
        end
        if (~VBLn & vbl_n_prev) begin
            //vbl_start <= 1;
            scanout_active <= 0;
        end

        hcnt <= hcnt + 1;
        if (hcnt == H_END) begin
            hcnt <= H_START;
            vcnt <= vcnt + 1;
            scanout_newline <= 1;

            if (ex_vbl_end) begin
                ex_vbl_end <= 0;
                scanout_active <= 1;
                vcnt <= V_EXVBL_RESET;
            end
        end

        HSYNCn <= ~(hcnt >= HS_START && hcnt <= HS_END);
        HBLn <= ~(hcnt >= HB_START && hcnt <= HB_END);
        VSYNCn <= ~(vcnt >= VS_START && vcnt <= VS_END);
        VBLn <= ~(vcnt >= VB_START); // && vcnt <= VB_END);
    end

    unique case(scan_state)
        SCAN_IDLE: begin
            ddr_fb.acquire <= 0;
            ddr_fb.read <= 0;
            if (scanout_newline) begin
                scan_state <= SCAN_START_READ;
                scanout_newline <= 0;
            end
        end

        SCAN_START_READ: begin
            ddr_fb.acquire <= 1;
            if (~ddr_fb.busy) begin
                ddr_fb.read <= 1;
                ddr_fb.burstcnt <= 80; // 320 / 4
                ddr_fb.addr <= OBJ_FB_DDR_BASE + { 13'd0, scanout_buffer, vcnt + 8'd1, 10'd16 };
                fb_dirty_scan_addr <= { scanout_buffer, vcnt + 8'd1, 7'd2 };
                burstidx <= 0;
                scan_state <= SCAN_WAIT_READ;
            end
        end

        SCAN_WAIT_READ: begin
            if (~ddr_fb.busy) begin
                ddr_fb.read <= 0;
                if (ddr_fb.rdata_ready) begin
                    if (vcnt[0]) begin
                        line_buffer0[lb0_addr] <= fb_dirty[fb_dirty_scan_addr] ? ddr_fb.rdata : 64'd0;
                    end else begin
                        line_buffer1[lb1_addr] <= fb_dirty[fb_dirty_scan_addr] ? ddr_fb.rdata : 64'd0;
                    end
                    burstidx <= burstidx + 1;

                    fb_dirty[fb_dirty_scan_addr] <= 0;
                    fb_dirty_scan_addr <= fb_dirty_scan_addr + 1;

                    if (burstidx + 1 == 80) begin
                        scan_state <= SCAN_IDLE;
                    end
                end
            end
        end
    endcase
end



endmodule


/*
        Sprite format:
        0000: ---xxxxxxxxxxxxx tile code (0x0000 - 0x1fff)
        0002: xxxxxxxx-------- sprite y-zoom level
              --------xxxxxxxx sprite x-zoom level

              0x00 - non scaled = 100%
              0x80 - scaled to 50%
              0xc0 - scaled to 25%
              0xe0 - scaled to 12.5%
              0xff - scaled to zero pixels size (off)

        [this zoom scale may not be 100% correct, see Gunfront flame screen]

        0004: ----xxxxxxxxxxxx x-coordinate (-0x800 to 0x07ff)
              ---x------------ latch extra scroll
              --x------------- latch master scroll
              -x-------------- don't use extra scroll compensation
              x--------------- absolute screen coordinates (ignore all sprite scrolls)
              xxxx------------ the typical use of the above is therefore
                               1010 = set master scroll
                               0101 = set extra scroll
        0006: ----xxxxxxxxxxxx y-coordinate (-0x800 to 0x07ff)
              x--------------- marks special control commands (used in conjunction with 00a)
                               If the special command flag is set:
              ---------------x related to sprite ram bank
              ---x------------ unknown (deadconx, maybe others)
              --x------------- unknown, some games (growl, gunfront) set it to 1 when
                               screen is flipped
        0008: --------xxxxxxxx color (0x00 - 0xff)
              -------x-------- flipx
              ------x--------- flipy
              -----x---------- if set, use latched color, else use & latch specified one
              ----x----------- if set, next sprite entry is part of sequence
              ---x------------ if clear, use latched y coordinate, else use current y
              --x------------- if set, y += 16
              -x-------------- if clear, use latched x coordinate, else use current x
              x--------------- if set, x += 16
        000a: only valid when the special command bit in 006 is set
              ---------------x related to sprite ram bank. I think this is the one causing
                               the bank switch, implementing it this way all games seem
                               to properly bank switch except for footchmp which uses the
                               bit in byte 006 instead.
              ------------x--- unknown; some games toggle it before updating sprite ram.
              ------xx-------- unknown (finalb)
              -----x---------- unknown (mjnquest)
              ---x------------ disable the following sprites until another marker with
                               this bit clear is found
              --x------------- flip screen

        000b - 000f : unused
*/


