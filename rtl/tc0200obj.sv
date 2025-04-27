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

    // bank switching and extension support
    output reg code_modify_req,
    output [13:0] code_original,
    input [19:0] code_modified,

    input [12:0] debug_idx,

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
// FB alignment



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
//

// horizontal video: htotal=424, hfp=20, hs=64, vbp=20
// vertical video:   vtotal=262, vfp=16, vs=6,  vbp=16

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
wire        inst_reuse_color     =  work_buffer[4][10];
wire        inst_next_seq        =  work_buffer[4][11];
wire        inst_use_latch_y     =  work_buffer[4][12];
wire        inst_inc_y           =  work_buffer[4][13];
wire        inst_use_latch_x     =  work_buffer[4][14];
wire        inst_inc_x           =  work_buffer[4][15];
reg         inst_debug;

assign code_original = inst_tile_code;
wire [19:0] tile_code = code_modified;

typedef enum
{
    ST_IDLE = 0,
    ST_DMA_INIT,
    ST_DMA,
    ST_DRAW_INIT,
    ST_READ_START,
    ST_READ,
    ST_EVAL,
    ST_EVAL2,
    ST_CHECK_BOUNDS,
    ST_READ_TILE,
    ST_READ_TILE_WAIT,
    ST_DRAW_TILE1,
    ST_DRAW_TILE2,
    ST_DRAW_TILE3
} draw_state_t;

draw_state_t obj_state = ST_IDLE;


reg [12:0] dma_cycle;
wire [14:0] dma_addr = {2'b00, dma_cycle[12:3], 3'b000};

reg scanout_buffer = 0;
wire draw_buffer = ~scanout_buffer;

wire fb_dirty_scan, fb_dirty_is_set;
reg fb_dirty_scan_clear;
reg [15:0] fb_dirty_scan_addr;
wire [15:0] fb_dirty_draw_addr = { draw_buffer, shifter_addr };

reg fb_dirty_set;
reg [15:0] fb_dirty_set_addr;

dualport_ram_unreg #(.WIDTH(1), .WIDTHAD(16)) fb_dirty_buffer
(
    // Port A
    .clock_a(clk),
    .wren_a(fb_dirty_scan_clear),
    .address_a(fb_dirty_scan_addr),
    .data_a(0),
    .q_a(fb_dirty_scan),

    // Port B
    .clock_b(clk),
    .wren_b(fb_dirty_set),
    .address_b(fb_dirty_set ? fb_dirty_set_addr : fb_dirty_draw_addr),
    .data_b(1),
    .q_b(fb_dirty_is_set)
);

reg [11:0] master_x, master_y, extra_x, extra_y;
reg [11:0] latch_x, latch_y;
reg [7:0]  latch_color;
reg prev_vbl_n, vbl_edge;

reg [31:0] draw_addr;
reg [3:0] draw_row;
reg [1:0] draw_col;

reg [(6 * 16)-1:0] tile_row[16];
reg [4:0] tile_burst;

wire [7:0] read_tile_burstcnt;
wire read_tile_complete;
wire [63:0] shifter_data;
wire [7:0] shifter_be;
wire [14:0] shifter_addr;
wire shifter_ready, shifter_done;
reg shifter_read;
reg bpp6 = 0;

tc0200obj_data_shifter shifter(
    .clk,
    .reset(obj_state == ST_EVAL),
    .bpp6,
    .burstcnt(read_tile_burstcnt),
    .load_complete(read_tile_complete),

    .x(latch_x),
    .y(latch_y),
    .flip_x(inst_x_flip),
    .flip_y(inst_y_flip),
    .color(latch_color),

    .out_data(shifter_data),
    .out_be(shifter_be),
    .out_ready(shifter_ready),
    .out_read(shifter_read),
    .out_addr(shifter_addr),
    .out_done(shifter_done),

    .din(inst_debug ? 64'hffffffffffffffff : ddr_obj.rdata),
    .load(ddr_obj.rdata_ready && (obj_state == ST_READ_TILE_WAIT))
);

reg [17:0] read_pacing;
reg test_pause = 0;
    
reg [11:0] base_x, base_y;
reg prev_seq;

always @(posedge clk) begin
    ddr_obj.acquire <= 0;
    code_modify_req <= 0;

    prev_vbl_n <= VBLn;
    if (prev_vbl_n & ~VBLn) begin
        vbl_edge <= 1;
    end

    if (ce_13m) begin
        read_pacing <= read_pacing + 1;
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
        ST_DRAW_INIT: if (ce_13m) begin
            read_pacing <= 0;
            RA <= 0;
            RDWEn <= 1;
            obj_state <= ST_READ_START;
        end

        ST_READ_START: if (ce_13m) begin
            if (RA[12:3] == 835 || vbl_edge) begin
                obj_state <= ST_IDLE;
            end else begin
                if (read_pacing[17:8] >= RA[12:3]) begin
                    EBUSY <= 1;
                    ERCSn <= 0;
                    obj_state <= ST_READ;
                    inst_debug <= {1'b0, RA[14:3]} == debug_idx;
                end
            end
        end

        ST_READ: if (ce_13m) begin
            RA <= RA + 15'd1;
            work_buffer[RA[2:0]] <= Din;
            if (RA[2:0] == 3'b101) begin
                code_modify_req <= 1;
            end
            if (RA[2:0] == 3'b111) begin
                obj_state <= ST_EVAL;
                EBUSY <= 0;
                ERCSn <= 1;
            end
        end

        ST_EVAL: begin
            if (inst_is_cmd) begin
            end
            
            if (inst_next_seq & ~prev_seq) begin
                base_x = inst_x_coord + (inst_use_scroll ? ( master_x + (inst_use_extra ? extra_x : 12'd0) ) : 12'd0);
                base_y = inst_y_coord + (inst_use_scroll ? ( master_y + (inst_use_extra ? extra_y : 12'd0) ) : 12'd0);
            end

            prev_seq <= inst_next_seq;

            if (inst_latch_extra) begin
                extra_x <= inst_x_coord;
                extra_y <= inst_y_coord;
            end

            if (inst_latch_master) begin
                master_x <= inst_x_coord;
                master_y <= inst_y_coord;
            end

            obj_state <= ST_EVAL2;
        end

        ST_EVAL2: begin
            if (inst_use_latch_y) begin
                latch_y <= latch_y + {7'd0, 1'b1, 4'd0};
            end else begin
                latch_y <= base_y;
            end
            if (inst_use_latch_x | inst_inc_x) begin
                latch_x <= latch_x + {7'd0, inst_inc_x, 4'd0};
            end else begin
                latch_x <= base_x + {7'd0, inst_inc_x, 4'd0};
            end

            if (tile_code == 0) begin
                obj_state <= ST_READ_START;
            end else begin
                obj_state <= ST_CHECK_BOUNDS;
            end

            if (~inst_reuse_color) begin
                latch_color <= inst_color;
            end
        end

        ST_CHECK_BOUNDS: begin
            draw_addr <= OBJ_FB_DDR_BASE + { 13'd0, draw_buffer, latch_y[7:0], latch_x[8:2], 3'b000 };
            if (latch_x > 480) begin
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
                ddr_obj.burstcnt <= read_tile_burstcnt;
                if (bpp6)
                    ddr_obj.addr <= OBJ_DATA_DDR_BASE + {4'd0, tile_code, 8'd0};
                else
                    ddr_obj.addr <= OBJ_DATA_DDR_BASE + {5'd0, tile_code, 7'd0};
                tile_burst <= 0;
                obj_state <= ST_READ_TILE_WAIT;
            end
        end

        ST_READ_TILE_WAIT: begin
            if (read_tile_complete) begin
                obj_state <= ST_DRAW_TILE1;
                draw_row <= 0;
                draw_col <= 0;
            end else begin
                ddr_obj.acquire <= 1;
                if (~ddr_obj.busy) begin
                    ddr_obj.read <= 0;
                    // shifter module handles reads
                end
            end
        end

        // TODO
        // Possible to squeeze this down to less cycles. Currently this work
        // is spread out across three cycles so that we can read from the
        // dirty buffer and write to it. The writes could be deferred which
        // would remove a cycle. The DDR writes could also be deferred and
        // batched, resulting in less time with the DDR bus acquired.
        ST_DRAW_TILE1: begin
            ddr_obj.acquire <= 1;
            if (shifter_ready) begin
                // one cycle delay waiting for fb_dirty_is_set to become valid
                obj_state <= ST_DRAW_TILE2;
            end
        end

        ST_DRAW_TILE2: begin
            ddr_obj.acquire <= 1;
            if (~ddr_obj.busy) begin
                shifter_read <= 1;
                ddr_obj.addr <= OBJ_FB_DDR_BASE + {13'd0, draw_buffer, shifter_addr, 3'd0 };
                ddr_obj.burstcnt <= 1;
                ddr_obj.wdata <= shifter_data;
                ddr_obj.write <= 1;
                ddr_obj.byteenable <= fb_dirty_is_set ? shifter_be : 8'hff;

                fb_dirty_set_addr <= fb_dirty_draw_addr;
                fb_dirty_set <= 1;
                obj_state <= ST_DRAW_TILE3;
            end
        end

        ST_DRAW_TILE3: begin
            ddr_obj.acquire <= 1;
            fb_dirty_set <= 0;
            shifter_read <= 0;
            if (~ddr_obj.busy ) begin
                ddr_obj.write <= 0;
                if (shifter_done) begin
                    obj_state <= ST_READ_START;
                end else begin
                    obj_state <= ST_DRAW_TILE1;
                end
            end
        end

        default: begin
            obj_state <= ST_IDLE;
        end
    endcase
end



// Scan out
//

wire [9:0] H_OFS = 97;
wire [9:0] H_START = 0 + H_OFS;
wire [9:0] H_END = 424 + H_OFS - 1;
wire [9:0] HS_START = 340 + H_OFS;
wire [9:0] HS_END = 404 + H_OFS - 1;
wire [9:0] HB_START = 320 + H_OFS;
wire [9:0] HB_END = H_END;

wire [7:0] VS_START = 240;
wire [7:0] VS_END = 246 - 1;
wire [7:0] VB_START = 224;
wire [7:0] VB_END = 255;
wire [7:0] V_EXVBL_RESET = 250; // from signal trace


reg [9:0] hcnt;
reg [7:0] vcnt;
reg [6:0] burstidx;

reg line_buffer_write;
reg [7:0] line_buffer_write_addr;
reg [63:0] line_buffer_wdata;

dualport_ram_unreg #(.WIDTH(64), .WIDTHAD(8)) line_buffer
(
    // Port A
    .clock_a(clk),
    .wren_a(line_buffer_write),
    .address_a(line_buffer_write_addr),
    .data_a(fb_dirty_scan ? line_buffer_wdata : 64'd0),
    .q_a(),

    // Port B
    .clock_b(clk),
    .wren_b(0),
    .address_b({~vcnt[0], hcnt[8:2]}),
    .data_b(0),
    .q_b(lb_dout)
);


wire [63:0] lb_dout;

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

reg ex_hbl_n_prev;
always_ff @(posedge clk) begin
    if (ce_pixel) begin
        ex_vbl_n_prev <= EXVBLn;
        ex_hbl_n_prev <= EXHBLn;
        vbl_n_prev <= VBLn;

        if (EXVBLn & ~ex_vbl_n_prev) begin
            ex_vbl_end <= 1;
        end
        if (~VBLn & vbl_n_prev) begin
            //vbl_start <= 1;
            scanout_active <= 0;
        end

        if (ex_hbl_n_prev & ~EXHBLn) begin
            hcnt <= HB_START;
        end else begin
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
        end

        HSYNCn <= ~(hcnt >= HS_START && hcnt <= HS_END);
        HBLn <= ~(hcnt >= HB_START && hcnt <= HB_END);
        VSYNCn <= ~(vcnt >= VS_START && vcnt <= VS_END);
        VBLn <= ~(vcnt >= VB_START); // && vcnt <= VB_END);
    end

    fb_dirty_scan_clear <= 0;
    line_buffer_write <= 0;

    unique case(scan_state)
        SCAN_IDLE: begin
            ddr_fb.acquire <= 0;
            ddr_fb.read <= 0;
            fb_dirty_scan_addr <= { fb_dirty_scan_addr[15:7], hcnt[6:0] };
            fb_dirty_scan_clear <= 1;

            if (scanout_newline) begin
                scan_state <= SCAN_START_READ;
                scanout_newline <= 0;
            end
        end

        SCAN_START_READ: begin
            ddr_fb.acquire <= 1;
            if (~ddr_fb.busy) begin
                ddr_fb.read <= 1;
                ddr_fb.burstcnt <= 128;
                ddr_fb.addr <= OBJ_FB_DDR_BASE + { 13'd0, scanout_buffer, vcnt + 8'd17, 10'd0 };
                fb_dirty_scan_addr <= { scanout_buffer, vcnt + 8'd17, 7'd0 };
                burstidx <= 0;
                scan_state <= SCAN_WAIT_READ;
            end
        end

        SCAN_WAIT_READ: begin
            if (~ddr_fb.busy) begin
                ddr_fb.read <= 0;
                if (ddr_fb.rdata_ready) begin
                    line_buffer_write <= 1;
                    line_buffer_wdata <= ddr_fb.rdata;
                    line_buffer_write_addr <= {vcnt[0], burstidx};
                    burstidx <= burstidx + 1;

                    fb_dirty_scan_addr <= fb_dirty_scan_addr + 1;

                    if (burstidx == 127) begin
                        scan_state <= SCAN_IDLE;
                        fb_dirty_scan_addr <= { scanout_buffer, vcnt + 8'd17, 7'd0 }; // reset
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

module tc0200obj_data_shifter(
    input clk,

    input reset,

    input bpp6,
    output [7:0] burstcnt,
    output reg load_complete,

    input [63:0] din,
    input load,

    input [11:0] x,
    input [11:0] y,
    input        flip_x,
    input        flip_y,
    input [7:0] color,

    input             out_read,
    output reg [63:0] out_data,
    output reg  [7:0] out_be,
    output reg        out_ready,
    output reg [14:0] out_addr,
    output reg        out_done
);

function bit [(6 * 4)-1:0] decode_6bpp_rom(input [31:0] d);
    bit [(6 * 4)-1:0] r;
    r[5:0]   = {d[17:16], d[3:0]};
    r[11:6]  = {d[19:18], d[7:4]};
    r[17:12] = {d[21:20], d[11:8]};
    r[23:18] = {d[23:22], d[15:12]};
    return r;
endfunction

function bit [(6 * 4)-1:0] decode_4bpp_rom(input [15:0] d);
    bit [(6 * 4)-1:0] r;
    r[5:0]   = {2'b00, d[3:0]};
    r[11:6]  = {2'b00, d[7:4]};
    r[17:12] = {2'b00, d[11:8]};
    r[23:18] = {2'b00, d[15:12]};
    return r;
endfunction

assign burstcnt = bpp6 ? 8'd32 : 8'd16;
reg [7:0] burstidx;

reg [5:0] pixel[16 * 16];
reg [5:0] row_data[20];

wire [7:0] y_addr = y[7:0];
wire [6:0] x_addr = x[8:2];
wire [1:0] x_shift = x[1:0];

reg [3:0] row;
reg [2:0] col;

task prepare_row(int next_row);
    int i;
    int pa;

    pa = next_row * 16;

    for( i = 0; i < 20; i = i + 1 ) begin
        row_data[i] <= 6'd0;
    end

    for( i = 0; i < 16; i = i + 1 ) begin
        if (flip_x) begin
            row_data[i + int'(x_shift)] <= pixel[pa + (15 - i)];
        end else begin
            row_data[i + int'(x_shift)] <= pixel[pa + i];
        end
    end
endtask

task prepare_draw();
    int i;
    out_addr <= { y_addr, x_addr } + { 4'd0, row, 4'd0, col };
    out_be <= 8'd0;
    out_data <= 64'd0;
    out_ready <= 1;

    if (bpp6) begin
        out_data[15:0] <=  { 4'd0, color[7:2], row_data[0] };
        out_data[31:16] <= { 4'd0, color[7:2], row_data[1] };
        out_data[47:32] <= { 4'd0, color[7:2], row_data[2] };
        out_data[63:48] <= { 4'd0, color[7:2], row_data[3] };
    end else begin
        out_data[15:0] <=  { 4'd0, color[7:0], row_data[0][3:0] };
        out_data[31:16] <= { 4'd0, color[7:0], row_data[1][3:0] };
        out_data[47:32] <= { 4'd0, color[7:0], row_data[2][3:0] };
        out_data[63:48] <= { 4'd0, color[7:0], row_data[3][3:0] };
    end

    out_be[1:0] <= {2{|row_data[0]}};
    out_be[3:2] <= {2{|row_data[1]}};
    out_be[5:4] <= {2{|row_data[2]}};
    out_be[7:6] <= {2{|row_data[3]}};

    for( i = 0; i < 16; i = i + 1 ) begin
        row_data[i] <= row_data[i+4];
    end

    col <= col + 1;
    if (col == 4) begin
        prepare_row(int'(row) + 1);
        col <= 0;
        row <= row + 1;
        if (row == 15) begin
            out_done <= 1;
        end
    end
endtask

always_ff @(posedge clk) begin
    if (reset) begin
        burstidx <= 0;
        load_complete <= 0;
        out_done <= 0;
        out_ready <= 0;
        row <= 0;
        col <= 0;
    end else begin
        if (load) begin
            if (bpp6) begin
                bit [(6 * 4)-1:0] d;
                d = decode_6bpp_rom(din[31:0]);
                pixel[(burstidx * 8) + 0] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 8) + 1] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 8) + 2] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 8) + 3] <= d[(6 * 3) +: 6];
                d = decode_6bpp_rom(din[63:32]);
                pixel[(burstidx * 8) + 4] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 8) + 5] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 8) + 6] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 8) + 7] <= d[(6 * 3) +: 6];
            end else begin
                bit [(6 * 4)-1:0] d;
                d = decode_4bpp_rom(din[15:0]);
                pixel[(burstidx * 16) + 0] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 16) + 1] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 16) + 2] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 16) + 3] <= d[(6 * 3) +: 6];
                d = decode_4bpp_rom(din[31:16]);
                pixel[(burstidx * 16) + 4] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 16) + 5] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 16) + 6] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 16) + 7] <= d[(6 * 3) +: 6];
                d = decode_4bpp_rom(din[47:32]);
                pixel[(burstidx * 16) + 8] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 16) + 9] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 16) + 10] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 16) + 11] <= d[(6 * 3) +: 6];
                d = decode_4bpp_rom(din[63:48]);
                pixel[(burstidx * 16) + 12] <= d[(6 * 0) +: 6];
                pixel[(burstidx * 16) + 13] <= d[(6 * 1) +: 6];
                pixel[(burstidx * 16) + 14] <= d[(6 * 2) +: 6];
                pixel[(burstidx * 16) + 15] <= d[(6 * 3) +: 6];
            end

            burstidx <= burstidx + 1;
            if (burstidx == (burstcnt - 1)) begin
                load_complete <= 1;
                prepare_row(0);
            end
        end

        if (load_complete & ~out_ready) begin
            prepare_draw();
        end else if (out_read & ~out_done) begin
            prepare_draw();
        end
    end
end

endmodule

