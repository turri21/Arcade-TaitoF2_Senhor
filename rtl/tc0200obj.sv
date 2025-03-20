module TC0200OBJ #(parameter SS_IDX=-1) (
    input clk,

    input ce_13m,
    input ce_pixel,

    output reg [14:0] RA,
    input [15:0] Din,
    output [15:0] Dout,

    input RESET,
    output ERCSn, // TODO - what generates this
    output EBUSY, // TODO - what generates this
    output RDWEn,

    output EDMAn, // TODO - is dma started by vblank?

    output [11:0] DOT,

    input EXHBLn,
    input EXVBLn,

    output HSYNCn,
    output VSYNCn,
    output HBLn,
    output VBLn,

    ssbus_if.slave ssbus
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

reg [15:0] work_buffer[8];
wire [13:0] inst_tile_code       =  work_buffer[0][13:0];
wire [7:0]  inst_x_zoom          =  work_buffer[1][7:0];
wire [7:0]  inst_y_zoom          =  work_buffer[1][15:8];
wire [11:0] inst_x_coord         =  work_buffer[2][11:0];
wire        inst_latch_extra     =  work_buffer[2][12];
wire        inst_latch_master    =  work_buffer[2][13];
wire        inst_use_extra       = ~work_buffer[2][14];
wire        inst_use_scroll      = ~work_buffer[2][15];
wire [11:0] inst_y_coord         =  work_buffer[3][11:0];
wire        inst_is_cmd          =  work_buffer[3][15];
wire [2:0]  inst_unk1            =  work_buffer[3][14:12];
wire [7:0]  inst_color           =  work_buffer[4][7:0];
wire        inst_x_flip          =  work_buffer[4][8];
wire        inst_y_flip          =  work_buffer[4][9];
wire        inst_use_latch_color = ~work_buffer[4][10];
wire        inst_next_seq        =  work_buffer[4][11];
wire        inst_use_latch_y     = ~work_buffer[4][12];
wire        inst_inc_y           =  work_buffer[4][13];
wire        inst_use_latch_x     = ~work_buffer[4][14];
wire        inst_inc_x           =  work_buffer[4][15];
wire [11:0] inst_calc_x_coord    =  work_buffer[6][11:0];
wire [11:0] inst_calc_y_coord    =  work_buffer[7][11:0];



reg [17:0] cycle_count;
reg [17:0] draw_cycle;
wire [17:0] dma_cycle = cycle_count;

always_ff @(posedge clk) begin
    if (ce_13m) begin
        cycle_count <= cycle_count + 18'd1;
        draw_cycle <= cycle_count - 8191;
        if (cycle_count == 222175) cycle_count <= 0;
    end
end

assign EDMAn = cycle_count >= 1024 * 8;

wire [14:0] dma_addr = {2'b00, dma_cycle[12:3], 3'b000};
wire [14:0] draw_addr = {2'b00, draw_cycle[17:8], 3'b000};

always_ff @(posedge clk) begin
    if (ce_13m) begin
        RDWEn <= 1;
        if (~EDMAn) begin
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
                end
                5: RDWEn <= 0;
                6: begin
                    RA <= dma_addr + 15'd7;
                    Dout <= work_buffer[2];
                end
                7: RDWEn <= 0;
            endcase
        end else begin
            if (draw_cycle[7:0] < 16) begin
                if (draw_cycle[0]) begin
                    work_buffer[draw_cycle[3:1]] <= Din;
                end else begin
                    RA <= draw_addr + { 12'd0, draw_cycle[3:1] };
                end
            end
        end
    end
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


