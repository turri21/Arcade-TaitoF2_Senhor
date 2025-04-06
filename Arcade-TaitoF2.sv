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

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
    "TaitoF2;SS3E000000:200000;",
    "-;",
    "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "R[64],Save State 1;",
    "R[65],Save State 2;",
    "R[66],Save State 3;",
    "R[67],Save State 4;",
    "R[68],Load State 1;",
    "R[69],Load State 2;",
    "R[70],Load State 3;",
    "R[71],Load State 4;",
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

wire [3:0] save_state_req = status[67:64];
wire [3:0] load_state_req = status[71:68];

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

wire [63:0] sdr_ch2_dout;

wire [63:0] sdr_ch3_dout;
wire sdr_ch3_ack;

wire [26:0] sdr_cpu_addr, sdr_rom_addr;
wire [15:0] sdr_cpu_din, sdr_rom_din;
wire [1:0] sdr_cpu_be, sdr_rom_be;
wire sdr_cpu_req, sdr_rom_req;
wire sdr_cpu_rw, sdr_rom_rw;

wire [26:0] sdr_ch3_addr = rom_load_busy ? sdr_rom_addr : sdr_cpu_addr;
wire [15:0] sdr_ch3_din = rom_load_busy ? sdr_rom_din : sdr_cpu_din;
wire [63:0] sdr_cpu_dout = sdr_ch3_dout;
wire [1:0] sdr_ch3_be = rom_load_busy ? sdr_rom_be : sdr_cpu_be;
wire sdr_ch3_req = rom_load_busy ? sdr_rom_req : sdr_cpu_req;
wire sdr_cpu_ack = rom_load_busy ? sdr_cpu_req : sdr_ch3_ack; // FIXME, wtf to do with this in unknown state?
wire sdr_rom_ack = rom_load_busy ? sdr_ch3_ack : sdr_rom_req;
wire sdr_ch3_rnw = rom_load_busy ? sdr_rom_rw  : sdr_cpu_rw;

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

    .ch4_addr(0),
    .ch4_dout(),
    .ch4_req(0),
    .ch4_ack()
);

ddr_if ddr_host(), ddr_romload(), ddr_romload_adaptor(), ddr_romload_loader(), ddr_f2();

ddr_mux ddr_mux(
    .clk(clk_sys),
    .x(ddr_host),
    .a(ddr_f2),
    .b(ddr_romload)
);

ddr_mux ddr_mux2(
    .clk(clk_sys),
    .x(ddr_romload),
    .a(ddr_romload_adaptor),
    .b(ddr_romload_loader)
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


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

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

F2 F2(
    .clk(clk_sys),
    .reset(reset),

    .ce_pixel(ce_pix),
    .hsync(HSync),
    .hblank(HBlank),
    .vsync(VSync),
    .vblank(VBlank),
    .red(VGA_R),
    .green(VGA_G),
    .blue(VGA_B),

    .joystick_p1(joystick_p1[7:0]),
    .joystick_p2(joystick_p2[7:0]),
    .start({joystick_p2[8], joystick_p1[8]}),
    .coin({joystick_p2[9], joystick_p1[9]}),

    .audio_left(AUDIO_L),
    .audio_right(AUDIO_R),
    .audio_sample(),

    .sdr_cpu_addr(sdr_cpu_addr),
    .sdr_cpu_q(sdr_cpu_dout[15:0]),
    .sdr_cpu_data(sdr_cpu_din),
    .sdr_cpu_be(sdr_cpu_be),
    .sdr_cpu_rw(sdr_cpu_rw),     // 1 - read, 0 - write
    .sdr_cpu_req(sdr_cpu_req),
    .sdr_cpu_ack(sdr_cpu_ack),

    .sdr_scn_main_addr(sdr_ch1_addr),
    .sdr_scn_main_q(sdr_ch1_dout),
    .sdr_scn_main_req(sdr_ch1_req),
    .sdr_scn_main_ack(sdr_ch1_ack),

    .sdr_audio_addr(sdr_ch2_addr),
    .sdr_audio_q(sdr_ch2_dout[15:0]),
    .sdr_audio_req(sdr_ch2_req),
    .sdr_audio_ack(sdr_ch2_ack),

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

    .ss_do_save(save_state_req[0]),
    .ss_do_restore(load_state_req[0]),
    .ss_state_out(),

    .bram_addr,
    .bram_data,
    .bram_wr
);


assign CLK_VIDEO = clk_sys;
assign DDRAM_CLK = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;

endmodule
