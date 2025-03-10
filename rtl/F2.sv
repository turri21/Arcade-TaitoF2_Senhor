module F2(
    input clk,
    input reset,

    output            ce_pixel,
    output            hsync,
    output            hblank,
    output            vsync,
    output            vblank,
    output      [7:0] red,
    output      [7:0] green,
    output      [7:0] blue,

    output reg [26:1] sdr_cpu_addr,
    input      [15:0] sdr_cpu_q,
    output reg [15:0] sdr_cpu_data,
    output reg [ 1:0] sdr_cpu_be,
    output reg        sdr_cpu_rw,     // 1 - read, 0 - write
    output reg        sdr_cpu_req,
    input             sdr_cpu_ack,

    output reg [26:1] sdr_scn_main_addr,
    input      [31:0] sdr_scn_main_q,
    output reg        sdr_scn_main_req,
    input             sdr_scn_main_ack


);

//////////////////////////////////
//// CHIP SELECTS

logic ROMn; // CPU ROM
logic WORKn; // CPU RAM
logic SCREENn;
logic COLORn;

wire SDTACKn, CDTACKn;

wire sdr_dtack_n = sdr_cpu_req != sdr_cpu_ack;

wire DTACKn = sdr_dtack_n | SDTACKn | CDTACKn;

//////////////////////////////////
//// CLOCK ENABLES
wire ce_6m, ce_13m;
jtframe_frac_cen #(2) video_cen
(
    .clk(clk),
    .cen_in(1),
    .n(10'd1),
    .m(10'd3),
    .cen({ce_6m, ce_13m}),
    .cenb()
);

wire ce_12m, ce_12m_180, ce_dummy_6m, ce_dummy_6m_180;
jtframe_frac_cen #(2) cpu_cen
(
    .clk(clk),
    .cen_in(1),
    .n(10'd3),
    .m(10'd10),
    .cen({ce_dummy_6m, ce_12m}),
    .cenb({ce_dummy_6m_180, ce_12m_180})
);



//////////////////////////////////
//// CPU
wire        cpu_rw, cpu_as_n;
wire [1:0]  cpu_ds_n;
wire [2:0]  cpu_fc;
wire [15:0] cpu_data_in, cpu_data_out;
wire [22:0] cpu_addr;
wire [23:0] cpu_word_addr = { cpu_addr, 1'b0 };

fx68k m68000(
    .clk(clk),
    .HALTn(1),
    .extReset(reset),
    .pwrUp(reset),
    .enPhi1(ce_12m),
    .enPhi2(ce_12m_180),

    .eRWn(cpu_rw), .ASn(cpu_as_n), .LDSn(cpu_ds_n[0]), .UDSn(cpu_ds_n[1]),
    .E(), .VMAn(),

    .FC0(cpu_fc[0]), .FC1(cpu_fc[1]), .FC2(cpu_fc[2]),
    .BGn(),
    .oRESETn(), .oHALTEDn(),
    .DTACKn(DTACKn), .VPAn(1),
    .BERRn(1),
    .BRn(1), .BGACKn(1),
    .IPL0n(1), .IPL1n(1), .IPL2n(1),
    .iEdb(cpu_data_in), .oEdb(cpu_data_out),
    .eab(cpu_addr)
);



//////////////////////////////////
//// SCREEN TC0100SCN
wire [14:0] scn_main_ram_addr;
wire [15:0] scn_main_data_out;
wire [15:0] scn_main_ram_din;
wire [15:0] scn_main_ram_dout;
wire scn_main_ram_we_up_n, scn_main_ram_we_lo_n;
wire scn_main_ram_ce_0_n, scn_main_ram_ce_1_n;

wire [14:0] scn_main_dot_color;

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(15), .NAME("SC0L")) scn_ram_0_lo(
    .clock(clk),
    .address(scn_main_ram_addr),
    .wren(~(scn_main_ram_ce_0_n | scn_main_ram_we_lo_n)),
    .data(scn_main_ram_dout[7:0]),
    .q(scn_main_ram_din[7:0])
);

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(15), .NAME("SC0U")) scn_ram_0_up(
    .clock(clk),
    .address(scn_main_ram_addr),
    .wren(~(scn_main_ram_ce_0_n | scn_main_ram_we_up_n)),
    .data(scn_main_ram_dout[15:8]),
    .q(scn_main_ram_din[15:8])
);

wire HSYNn;
wire HBLOn;
wire VSYNn;
wire VBLOn;

assign hsync = ~HSYNn;
assign vsync = ~VSYNn;
assign hblank = ~HBLOn;
assign vblank = ~VBLOn;

assign blue = {pri_ram_din[14:10], pri_ram_din[14:12]};
assign green = {pri_ram_din[9:5], pri_ram_din[9:7]};
assign red = {pri_ram_din[4:0], pri_ram_din[4:2]};

wire [20:0] scn_main_rom_address;
assign sdr_scn_main_addr = { 5'b0, scn_main_rom_address[20:0] };

TC0100SCN scn_main(
    .clk(clk),
    .ce_13m(ce_13m),
    .ce_pixel,

    .reset,

    // CPU interface
    .VA(cpu_addr[16:0]),
    .Din(cpu_data_out),
    .Dout(scn_main_data_out),
    .LDSn(cpu_ds_n[0]),
    .UDSn(cpu_ds_n[1]),
    .SCCSn(SCREENn),
    .RW(cpu_rw),
    .DACKn(SDTACKn),

    // RAM interface
    .SA(scn_main_ram_addr),
    .SDin(scn_main_ram_din),
    .SDout(scn_main_ram_dout),
    .WEUPn(scn_main_ram_we_up_n),
    .WELOn(scn_main_ram_we_lo_n),
    .SCE0n(scn_main_ram_ce_0_n),
    .SCE1n(scn_main_ram_ce_1_n),

    // ROM interface
    .rom_address(scn_main_rom_address),
    .rom_req(sdr_scn_main_req),
    .rom_ack(sdr_scn_main_ack),
    .rom_data(sdr_scn_main_q),

    // Video interface
    .SC(scn_main_dot_color),
    .HSYNn,
    .HBLOn,
    .VSYNn,
    .VBLOn,
    .OLDH(),
    .OLDV(),
    .IHLD(0), // FIXME - confirm inputs
    .IVLD(0)
);

wire [15:0] pri_data_out;
wire [12:0] pri_ram_addr;
wire [15:0] pri_ram_din, pri_ram_dout;
wire pri_ram_we_l_n, pri_ram_we_h_n;

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(12), .NAME("PRIL")) pri_ram_l(
    .clock(clk),
    .address(pri_ram_addr[12:1]),
    .wren(~pri_ram_we_l_n),
    .data(pri_ram_dout[7:0]),
    .q(pri_ram_din[7:0])
);

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(12), .NAME("PRIH")) pri_ram_h(
    .clock(clk),
    .address(pri_ram_addr[12:1]),
    .wren(~pri_ram_we_h_n),
    .data(pri_ram_dout[15:8]),
    .q(pri_ram_din[15:8])
);


TC0110PR tc0110pr(
    .clk,
    .ce_pixel,

    // CPU Interface
    .Din(cpu_data_out),
    .Dout(pri_data_out),

    .VA(cpu_addr[1:0]),
    .RWn(cpu_rw),
    .UDSn(cpu_ds_n[1]),
    .LDSn(cpu_ds_n[0]),

    .SCEn(COLORn),
    .DACKn(CDTACKn),

    // Video Input
    .HSYn(HSYNn),
    .VSYn(VSYNn),

    .SC(scn_main_dot_color),
    .OB(0),

    // RAM Interface
    .CA(pri_ram_addr),
    .CDin(pri_ram_din),
    .CDout(pri_ram_dout),
    .WELn(pri_ram_we_l_n),
    .WEHn(pri_ram_we_h_n)
);




/* verilator lint_off CASEX */
always_comb begin
    WORKn = 1;
    ROMn = 1;
    SCREENn = 1;
    COLORn = 1;

    if (~&cpu_ds_n) begin
        casex(cpu_word_addr)
            24'h0xxxxx: ROMn = 0;
            24'h1xxxxx: WORKn = 0;
            24'h8xxxxx: SCREENn = 0;
            24'h2xxxxx: COLORn = 0;
        endcase
    end
end
/* verilator lint_on CASEX */

assign cpu_data_in = sdr_cpu_q;

reg prev_ds_n;
always_ff @(posedge clk) begin
    prev_ds_n <= &cpu_ds_n;
    if (~(ROMn & WORKn) & prev_ds_n) begin
        sdr_cpu_addr <= { 2'b0, cpu_word_addr };
        sdr_cpu_data <= cpu_data_out;
        sdr_cpu_be <= ~cpu_ds_n;
        sdr_cpu_rw <= cpu_rw;
        sdr_cpu_req <= ~sdr_cpu_req;
    end
end

endmodule
