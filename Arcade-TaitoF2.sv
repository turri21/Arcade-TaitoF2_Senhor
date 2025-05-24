//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [48:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler
    output        VGA_DISABLE, // analog out is off

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,
    output        HDMI_BLACKOUT,

`ifdef MISTER_FB
    // Use framebuffer in DDRAM
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif
`endif

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
    //Secondary SDRAM
    //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
    input         SDRAM2_EN,
    output        SDRAM2_CLK,
    output [12:0] SDRAM2_A,
    output  [1:0] SDRAM2_BA,
    inout  [15:0] SDRAM2_DQ,
    output        SDRAM2_nCS,
    output        SDRAM2_nCAS,
    output        SDRAM2_nRAS,
    output        SDRAM2_nWE,
`endif

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    input   [6:0] USER_IN,
    output  [6:0] USER_OUT,

    input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;
assign AUDIO_MIX = 3;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

`include "build_id.v"
localparam CONF_STR = {
    "TaitoF2;SS3E000000:200000;",
    "-;",
    "P1,Video Settings;",
    "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "P1O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "P1O[7:6],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
    "P1-;",
    "P1O[8],Orientation,Horz,Vert;",
    "P1-;",
    "P1O[19],Consumer CRT Sync,On,Off;",
    "P1O[13:9],Analog Video H-Pos,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "P1O[18:14],Analog Video V-Pos,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
    "-;",
    "O[33:32],Analog Input,Joystick,Paddle,Spinner,D-Pad;",
    "O[35:34],Analog Sensitivity,High,Medium,Low,Very Low;",
    "O[36],Analog Invert,No,Yes;",
    "-;",
    "R[64],Save State 1;",
    "R[65],Save State 2;",
    "R[66],Save State 3;",
    "R[67],Save State 4;",
    "R[68],Load State 1;",
    "R[69],Load State 2;",
    "R[70],Load State 3;",
    "R[71],Load State 4;",
    "-;",
    "DIP;",
    "-;",
    "T[0],Reset;",
    "R[0],Reset and close OSD;",
    "DEFMRA,/_Development/F2.mra;",
    "v,0;", // [optional] config version 0-99.
            // If CONF_STR options are changed in incompatible way, then change version number too,
              // so all options will get default values on first start.
    "V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

wire ioctl_rom_wait;
/*wire ioctl_hs_upload_req;
wire ioctl_m107_upload_req;
wire [7:0] ioctl_hs_din;
wire [7:0] ioctl_m107_din;*/

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req = 0; //ioctl_hs_upload_req | ioctl_m107_upload_req;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_upload_index;
wire        ioctl_wr;
wire        ioctl_rd;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din = 0; // = ioctl_m107_din | ioctl_hs_din;
wire        ioctl_wait = ioctl_rom_wait;

wire [15:0] joystick_p1, joystick_p2, joystick_p3, joystick_p4;
wire [7:0] analog_x_p1, analog_y_p1, analog_x_p2, analog_y_p2;
wire [7:0] paddle_p1, paddle_p2;
wire [8:0] spinner_p1, spinner_p2;

wire [21:0] gamma_bus;
wire        direct_video;
wire        video_rotated;

wire        autosave = 0; //status[8];

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .EXT_BUS(),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),

    .forced_scandoubler(forced_scandoubler),
    .new_vmode(0),
    .video_rotated(video_rotated),

    .buttons(buttons),
    .status(status),
    .status_menumask({direct_video}),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_index(ioctl_upload_index),
    .ioctl_upload_req(ioctl_upload_req & autosave),
    .ioctl_wr(ioctl_wr),
    .ioctl_rd(ioctl_rd),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joystick_p1),
    .joystick_1(joystick_p2),
    .joystick_2(joystick_p3),
    .joystick_3(joystick_p4),

    .joystick_l_analog_0({analog_y_p1, analog_x_p1}),
    .joystick_l_analog_1({analog_y_p2, analog_x_p2}),

    .paddle_0(paddle_p1),
    .paddle_1(paddle_p2),

    .spinner_0(spinner_p1),
    .spinner_1(spinner_p2),


    .ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, clk_sdr, pll_locked;
pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .locked(pll_locked),
    .outclk_0(clk_sdr),
    .outclk_1(clk_sys)
);

wire reset = RESET | status[0] | buttons[1] | rom_load_busy;

wire [26:0] sdr_ch1_addr, sdr_ch2_addr, sdr_ch4_addr;
wire sdr_ch1_req, sdr_ch2_req, sdr_ch4_req;
wire sdr_ch1_ack, sdr_ch2_ack, sdr_ch4_ack;
wire [31:0] sdr_ch1_dout;

wire [15:0] sdr_ch2_dout;

wire [63:0] sdr_ch3_dout;
wire sdr_ch3_ack;

wire [15:0] sdr_ch4_dout;

wire [26:0] sdr_cpu_addr, sdr_rom_addr;
wire [15:0] sdr_cpu_din, sdr_rom_din;
wire [1:0] sdr_cpu_be, sdr_rom_be;
wire sdr_cpu_req, sdr_rom_req;
wire sdr_cpu_rw, sdr_rom_rw;

wire [26:0] sdr_ch3_addr = rom_load_busy ? sdr_rom_addr : sdr_cpu_addr;
wire [15:0] sdr_ch3_din = sdr_rom_din;
wire [63:0] sdr_cpu_dout = sdr_ch3_dout;
wire [1:0] sdr_ch3_be = rom_load_busy ? sdr_rom_be : 2'b00;
wire sdr_ch3_req = rom_load_busy ? sdr_rom_req : sdr_cpu_req;
wire sdr_cpu_ack = rom_load_busy ? sdr_cpu_req : sdr_ch3_ack; // FIXME, wtf to do with this in unknown state?
wire sdr_rom_ack = rom_load_busy ? sdr_ch3_ack : sdr_rom_req;
wire sdr_ch3_rnw = rom_load_busy ? sdr_rom_rw  : 1;

sdram sdram
(
    .init(~pll_locked),        // reset to initialize RAM
    .clk(clk_sdr),         // clock 64MHz

    .doRefresh(0),

    .SDRAM_DQ,    // 16 bit bidirectional data bus
    .SDRAM_A,     // 13 bit multiplexed address bus
    .SDRAM_DQML,  // two byte masks
    .SDRAM_DQMH,  //
    .SDRAM_BA,    // two banks
    .SDRAM_nCS,   // a single chip select
    .SDRAM_nWE,   // write enable
    .SDRAM_nRAS,  // row address select
    .SDRAM_nCAS,  // columns address select
    .SDRAM_CKE,   // clock enable
    .SDRAM_CLK,   // clock for chip

    .ch1_addr(sdr_ch1_addr),    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    .ch1_dout(sdr_ch1_dout),    // data output to cpu
    .ch1_req(sdr_ch1_req),     // request
    .ch1_ack(sdr_ch1_ack),

    .ch2_addr(sdr_ch2_addr),
    .ch2_dout(sdr_ch2_dout),
    .ch2_req(sdr_ch2_req),
    .ch2_ack(sdr_ch2_ack),

    .ch3_addr(sdr_ch3_addr),
    .ch3_dout(sdr_ch3_dout),
    .ch3_din(sdr_ch3_din),
    .ch3_be(sdr_ch3_be),
    .ch3_req(sdr_ch3_req),
    .ch3_rnw(sdr_ch3_rnw),     // 1 - read, 0 - write
    .ch3_ack(sdr_ch3_ack),

    .ch4_addr(sdr_ch4_addr),
    .ch4_dout(sdr_ch4_dout),
    .ch4_req(sdr_ch4_req),
    .ch4_ack(sdr_ch4_ack)
);

ddr_if ddr_host(), ddr_romload(), ddr_x(), ddr_romload_adaptor(), ddr_romload_loader(), ddr_f2(), ddr_rotate();

ddr_mux ddr_mux(
    .clk(clk_sys),
    .x(ddr_host),
    .a(ddr_f2),
    .b(ddr_x)
);

ddr_mux ddr_mux2(
    .clk(clk_sys),
    .x(ddr_romload),
    .a(ddr_romload_adaptor),
    .b(ddr_romload_loader)
);

ddr_mux ddr_mux3(
    .clk(clk_sys),
    .x(ddr_x),
    .a(ddr_rotate),
    .b(ddr_romload)
);

wire rom_load_busy;
wire rom_data_wait;
wire rom_data_strobe;
wire [7:0] rom_data;

wire [23:0] bram_addr;
wire  [7:0] bram_data;
wire        bram_wr;

board_cfg_t board_cfg;


ddr_rom_loader_adaptor ddr_rom_loader(
    .clk(clk_sys),

    .ioctl_download,
    .ioctl_addr,
    .ioctl_index,
    .ioctl_wr,
    .ioctl_data(ioctl_dout),
    .ioctl_wait(ioctl_rom_wait),

    .busy(rom_load_busy),

    .data_wait(rom_data_wait),
    .data_strobe(rom_data_strobe),
    .data(rom_data),

    .ddr(ddr_romload_adaptor)
);

rom_loader rom_loader(
    .sys_clk(clk_sys),
    .ram_clk(clk_sdr),

    .ioctl_wr(rom_data_strobe),
    .ioctl_data(rom_data),
    .ioctl_wait(rom_data_wait),

    .sdr_addr(sdr_rom_addr),
    .sdr_data(sdr_rom_din),
    .sdr_be(sdr_rom_be),
    .sdr_req(sdr_rom_req),
    .sdr_ack(sdr_rom_ack),
    .sdr_rw(sdr_rom_rw),

    .ddr(ddr_romload_loader),

    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_wr(bram_wr),

    .board_cfg(board_cfg)
);

// DIP SWITCHES
reg [7:0] dip_sw[8];    // Active-LOW
always @(posedge clk_sys) begin
    if(ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3])
        dip_sw[ioctl_addr[2:0]] <= ioctl_dout;
end


wire [3:0] save_state_status = status[67:64];
wire [3:0] load_state_status = status[71:68];
reg save_state_req = 0;
reg load_state_req = 0;
reg [1:0] save_state_index;

always_ff @(posedge clk_sys) begin
    if (save_state_status | load_state_status) begin
        case (save_state_status|load_state_status)
            4'b0001: save_state_index <= 0;
            4'b0010: save_state_index <= 1;
            4'b0100: save_state_index <= 2;
            4'b1000: save_state_index <= 3;
            default: save_state_index <= 0;
        endcase

        save_state_req <= |save_state_status;
        load_state_req <= |load_state_status;
    end else begin
        save_state_req <= 0;
        load_state_req <= 0;
    end
end


wire [7:0] core_r, core_g, core_b;
wire core_hb, core_vb, core_hs, core_vs;
wire core_ce_pix;

wire [31:0] DDRAM_ADDR_32 = ddr_host.addr;

assign DDRAM_ADDR = ddr_host.addr[31:3];
assign DDRAM_BE = ddr_host.byteenable;
assign DDRAM_WE = ddr_host.write;
assign DDRAM_RD = ddr_host.read;
assign DDRAM_DIN = ddr_host.wdata;
assign DDRAM_BURSTCNT = ddr_host.burstcnt;
assign ddr_host.rdata = DDRAM_DOUT;
assign ddr_host.rdata_ready = DDRAM_DOUT_READY;
assign ddr_host.busy = DDRAM_BUSY;

wire sync_fix = ~status[19];


reg [7:0] analog_p1, analog_p2;
reg [1:0] prev_spinner;
reg analog_inc, analog_abs;
wire [1:0] analog_mode = status[33:32];
wire [1:0] analog_sens = status[35:34];
wire analog_invert = status[36];

function bit [7:0] sens(input [7:0] d);
    bit [7:0] r;
    unique case (analog_sens)
        2'b00: r = d;
        2'b01: r = {d[7], d[7:1]};
        2'b10: r = {d[7], d[7], d[7:2]};
        2'b11: r = {d[7], d[7], d[7], d[7:3]};
    endcase
    return analog_invert ? (r ? ~r : r) : r;
endfunction

always_ff @(posedge clk_sys) begin
    prev_spinner <= { spinner_p2[8], spinner_p1[8] };
    analog_p1 <= 0;
    analog_p2 <= 0;
    analog_inc <= 0;
    analog_abs <= 0;
    unique case(analog_mode)
        2'b00: begin
            analog_p1 <= sens(analog_x_p1);
            analog_p2 <= sens(analog_x_p2);
            analog_abs <= 1;
        end
        2'b01: begin
            analog_p1 <= sens(paddle_p1 - 8'h7f);
            analog_p2 <= sens(paddle_p2 - 8'h7f);
            analog_abs <= 1;
        end
        2'b10: begin
            if (prev_spinner[0] ^ spinner_p1[8]) begin
                analog_p1 <= sens(spinner_p1[7:0]);
                analog_inc <= 1;
            end
            if (prev_spinner[1] ^ spinner_p2[8]) begin
                analog_p2 <= sens(spinner_p2[7:0]);
                analog_inc <= 1;
            end
        end
        2'b11: begin
            analog_p1 <= sens(joystick_p1[0] ? 8'h40 : joystick_p1[1] ? 8'hc0 : 8'h00);
            analog_p2 <= sens(joystick_p2[0] ? 8'h40 : joystick_p2[1] ? 8'hc0 : 8'h00);
            analog_abs <= 1;
        end
    endcase
end

F2 F2(
    .clk(clk_sys),
    .reset(reset),

    .game(board_cfg.game),

    .ce_pixel(core_ce_pix),
    .hsync(core_hs),
    .hblank(core_hb),
    .vsync(core_vs),
    .vblank(core_vb),
    .red(core_r),
    .green(core_g),
    .blue(core_b),

    .dswa(~dip_sw[0]),
    .dswb(~dip_sw[1]),

    .joystick_p1(joystick_p1[7:0]),
    .joystick_p2(joystick_p2[7:0]),
    .joystick_p3(joystick_p3[7:0]),
    .joystick_p4(joystick_p4[7:0]),

    .analog_abs(analog_abs),
    .analog_inc(analog_inc),
    .analog_p1(analog_p1),
    .analog_p2(analog_p2),

    .start({joystick_p4[8], joystick_p3[8], joystick_p2[8], joystick_p1[8]}),
    .coin({joystick_p4[9], joystick_p3[9], joystick_p2[9], joystick_p1[9]}),

    .audio_out(AUDIO_L),

    .sdr_cpu_addr(sdr_cpu_addr),
    .sdr_cpu_q(sdr_cpu_dout),
    .sdr_cpu_req(sdr_cpu_req),
    .sdr_cpu_ack(sdr_cpu_ack),

    .sdr_scn_main_addr(sdr_ch1_addr),
    .sdr_scn_main_q(sdr_ch1_dout),
    .sdr_scn_main_req(sdr_ch1_req),
    .sdr_scn_main_ack(sdr_ch1_ack),

    .sdr_audio_addr(sdr_ch2_addr),
    .sdr_audio_q(sdr_ch2_dout),
    .sdr_audio_req(sdr_ch2_req),
    .sdr_audio_ack(sdr_ch2_ack),

    .sdr_pivot_addr(sdr_ch4_addr),
    .sdr_pivot_q(sdr_ch4_dout),
    .sdr_pivot_req(sdr_ch4_req),
    .sdr_pivot_ack(sdr_ch4_ack),


    // Memory stream interface
    .ddr_acquire(ddr_f2.acquire),
    .ddr_addr(ddr_f2.addr),
    .ddr_wdata(ddr_f2.wdata),
    .ddr_rdata(ddr_f2.rdata),
    .ddr_read(ddr_f2.read),
    .ddr_write(ddr_f2.write),
    .ddr_burstcnt(ddr_f2.burstcnt),
    .ddr_byteenable(ddr_f2.byteenable),
    .ddr_busy(ddr_f2.busy),
    .ddr_read_complete(ddr_f2.rdata_ready),

    .obj_debug_idx(13'h1fff),

    .ss_index(save_state_index),
    .ss_do_save(save_state_req),
    .ss_do_restore(load_state_req),
    .ss_state_out(),

    .bram_addr,
    .bram_data,
    .bram_wr,

    .sync_fix
);


assign CLK_VIDEO = clk_sys;
assign DDRAM_CLK = clk_sys;

wire [1:0] ar             = status[2:1];
wire [2:0] scandoubler_fx = status[5:3];
wire [1:0] scale          = status[7:6];
wire       rotate         = status[8];
wire [4:0] hoffset        = status[13:9];
wire [4:0] voffset        = status[18:14];

video_path video_path(
    .CLK_VIDEO,

    .hoffset, .voffset,

    .forced_scandoubler, .scandoubler_fx,
    .ar, .scale,

    .rotate, .rotate_ccw(1), .flip(0),
    .video_rotated,

    .core_ce_pix,
    .core_hs, .core_vs, .core_hb, .core_vb,
    .core_r, .core_g, .core_b,

    .HDMI_WIDTH, .HDMI_HEIGHT,
    .VIDEO_ARX, .VIDEO_ARY,

    .gamma_bus,

    .FB_EN, .FB_FORMAT,
    .FB_WIDTH, .FB_HEIGHT,
    .FB_BASE, .FB_STRIDE,
    .FB_VBL, .FB_LL,

    .ddr(ddr_rotate),

    .CE_PIXEL,
    .VGA_R, .VGA_G, .VGA_B,
    .VGA_HS, .VGA_VS, .VGA_DE,
    .VGA_SL
);


endmodule
