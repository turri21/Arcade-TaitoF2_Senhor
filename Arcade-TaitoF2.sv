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

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
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
    "TaitoF2;;",
    "-;",
    "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "O[2],TV Mode,NTSC,PAL;",
    "O[4:3],Noise,White,Red,Green,Blue;",
    "-;",
    "P1,Test Page 1;",
    "P1-;",
    "P1-, -= Options in page 1 =-;",
    "P1-;",
    "P1O[5],Option 1-1,Off,On;",
    "d0P1F1,BIN;",
    "H0P1O[10],Option 1-2,Off,On;",
    "-;",
    "P2,Test Page 2;",
    "P2-;",
    "P2-, -= Options in page 2 =-;",
    "P2-;",
    "P2S0,DSK;",
    "P2O[7:6],Option 2,1,2,3,4;",
    "-;",
    "-;",
    "T[0],Reset;",
    "R[0],Reset and close OSD;",
    "v,0;", // [optional] config version 0-99.
            // If CONF_STR options are changed in incompatible way, then change version number too,
              // so all options will get default values on first start.
    "V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),
    .EXT_BUS(),
    .gamma_bus(),

    .forced_scandoubler(forced_scandoubler),

    .buttons(buttons),
    .status(status),
    .status_menumask({status[5]}),

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

wire reset = RESET | status[0] | buttons[1];

wire [26:0] sdr_ch1_addr, sdr_ch2_addr, sdr_ch3_addr, sdr_ch4_addr;
wire sdr_ch1_req, sdr_ch2_req, sdr_ch3_req, sdr_ch4_req;
wire sdr_ch1_ack, sdr_ch2_ack, sdr_ch3_ack, sdr_ch4_ack;
wire [31:0] sdr_ch1_dout;
wire [63:0] sdr_ch3_dout;
wire [15:0] sdr_ch3_din;
wire [1:0] sdr_ch3_be;
wire sdr_ch3_rnw;

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

    .ch2_addr(0),
    .ch2_dout(),
    .ch2_req(0),
    .ch2_ack(),

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


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

wire [31:0] DDRAM_ADDR_32;
assign DDRAM_ADDR = DDRAM_ADDR_32[31:3];

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

    .sdr_cpu_addr(sdr_ch3_addr),
    .sdr_cpu_q(sdr_ch3_dout[15:0]),
    .sdr_cpu_data(sdr_ch3_din),
    .sdr_cpu_be(sdr_ch3_be),
    .sdr_cpu_rw(sdr_ch3_rnw),     // 1 - read, 0 - write
    .sdr_cpu_req(sdr_ch3_req),
    .sdr_cpu_ack(sdr_ch3_ack),

    .sdr_scn_main_addr(sdr_ch1_addr),
    .sdr_scn_main_q(sdr_ch1_dout),
    .sdr_scn_main_req(sdr_ch1_req),
    .sdr_scn_main_ack(sdr_ch1_ack),

    // Memory stream interface
    .ddr_addr(DDRAM_ADDR_32),
    .ddr_wdata(DDRAM_DIN),
    .ddr_rdata(DDRAM_DOUT),
    .ddr_read(DDRAM_RD),
    .ddr_write(DDRAM_WE),
    .ddr_burstcnt(DDRAM_BURSTCNT),
    .ddr_byteenable(DDRAM_BE),
    .ddr_busy(DDRAM_BUSY),
    .ddr_read_complete(DDRAM_DOUT_READY),

    .obj_debug_idx(13'h1fff),

    .ss_do_save(0),
    .ss_do_restore(0),
    .ss_state_out()
);


assign CLK_VIDEO = clk_sys;
assign DDRAM_CLK = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;

endmodule
