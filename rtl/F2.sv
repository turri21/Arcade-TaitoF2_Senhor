import system_consts::*;

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

    output reg [31:0] sdr_cpu_addr,
    input      [15:0] sdr_cpu_q,
    output reg [15:0] sdr_cpu_data,
    output reg [ 1:0] sdr_cpu_be,
    output reg        sdr_cpu_rw,     // 1 - read, 0 - write
    output reg        sdr_cpu_req,
    input             sdr_cpu_ack,

    output reg [31:0] sdr_scn_main_addr,
    input      [31:0] sdr_scn_main_q,
    output reg        sdr_scn_main_req,
    input             sdr_scn_main_ack,

    // Memory stream interface
    output     [31:0] ddr_addr,
    output     [63:0] ddr_wdata,
    input      [63:0] ddr_rdata,
    output            ddr_read,
    output            ddr_write,
    output      [7:0] ddr_burstcnt,
    output      [7:0] ddr_byteenable,
    input             ddr_busy,
    input             ddr_read_complete,

    input ss_do_save,
    input ss_do_restore,
    output [3:0] ss_state_out
);


ddr_if ddr();
assign ddr_addr = ddr.addr;
assign ddr_wdata = ddr.wdata;
assign ddr_read = ddr.read;
assign ddr_write = ddr.write;
assign ddr_burstcnt = ddr.burstcnt;
assign ddr_byteenable = ddr.byteenable;
assign ddr.rdata = ddr_rdata;
assign ddr.busy = ddr_busy;
assign ddr.rdata_ready = ddr_read_complete;

ddr_if ddr_ss(), ddr_obj();

ddr_mux ddr_mux(
    .clk,
    .x(ddr),
    .a(ddr_ss),
    .b(ddr_obj)
);

reg [31:0] ss_saved_ssp;
reg [31:0] ss_restore_ssp;
reg ss_write = 0;
reg ss_read = 0;
wire ss_busy;

ssbus_if ssbus();

always_ff @(posedge clk) begin
    ssbus.setup(SSIDX_GLOBAL, 1, 2); // 1, 32-bit value
    if (ssbus.access(0)) begin
        if (ssbus.read) begin
            ssbus.read_response(0, { 32'd0, ss_saved_ssp });
        end else if (ssbus.write) begin
            ss_restore_ssp <= ssbus.data[31:0];
            ssbus.write_ack(0);
        end
    end
end

logic [15:0] save_handler[13] = '{
    16'h48e7,
    16'hfffe,
    16'h4e6e,
    16'h2f0e,

    // 0x8 - stop/restart pos
    16'h4df9,
    16'h00ff,
    16'h0000,
    16'h2c8f,

    16'h2c5f,
    16'h4e66,
    16'h4cdf,
    16'h7fff,
    16'h4e73
};


typedef enum bit [3:0] {
    SST_IDLE = 0,
    SST_START_SAVE,
    SST_WAIT_SAVE,
    SST_SAVE_PAUSED_SETTLE,
    SST_SAVE_PAUSED,
    SST_RESTORE_SETTLE,
    SST_WAIT_RESTORE,
    SST_HOLD_RESET,
    SST_WAIT_RESET
} ss_state_t;

ss_state_t ss_state = SST_IDLE;
reg [15:0] ss_counter;
reg [15:0] reset_vector[4];

wire ss_pause = (ss_state == SST_SAVE_PAUSED) || (ss_state == SST_WAIT_RESTORE) || (ss_state == SST_SAVE_PAUSED_SETTLE);
wire ss_reset = (ss_state == SST_HOLD_RESET) || (ss_state == SST_RESTORE_SETTLE);
wire ss_restart = (ss_state == SST_WAIT_RESET);

assign ss_state_out = ss_state;

always_ff @(posedge clk) begin
    ss_counter <= ss_counter + 1;
    case(ss_state)
        SST_IDLE: begin
            if (ss_do_save) begin
                ss_state <= SST_START_SAVE;
            end

            if (ss_do_restore) begin
                ss_state <= SST_RESTORE_SETTLE;
            end
        end

        SST_START_SAVE: begin
            if (cpu_ds_n == 2'b00 && !cpu_rw & cpu_word_addr == 24'hff0000) begin
                ss_saved_ssp[31:16] <= cpu_data_out;
                ss_state <= SST_WAIT_SAVE;
            end
        end

        SST_WAIT_SAVE: begin
            if (cpu_ds_n == 2'b00 && !cpu_rw && cpu_word_addr == 24'hff0002) begin
                ss_saved_ssp[15:0] <= cpu_data_out;
                ss_state <= SST_SAVE_PAUSED_SETTLE;
                ss_counter <= 0;
            end
        end


        SST_SAVE_PAUSED_SETTLE: begin
            if (ss_counter == 64) begin
                ss_write <= 1;
                ss_state <= SST_SAVE_PAUSED;
            end
        end

        SST_SAVE_PAUSED: begin
            if (ss_busy & ss_write) begin
                ss_write <= 0;
            end else if (~ss_busy & ~ss_write) begin
                ss_state <= SST_IDLE;
            end
        end

        SST_RESTORE_SETTLE: begin
            if (ss_counter == 64) begin
                ss_read <= 1;
                ss_state <= SST_WAIT_RESTORE;
            end
        end

        SST_WAIT_RESTORE: begin
            if (ss_busy & ss_read) begin
                ss_read <= 0;
            end else if (~ss_busy & ~ss_read) begin
                reset_vector[0] <= ss_restore_ssp[31:16];
                reset_vector[1] <= ss_restore_ssp[15:0];
                reset_vector[2] <= 16'h00ff;
                reset_vector[3] <= 16'h0008;

                ss_state <= SST_HOLD_RESET;
                ss_counter <= 0;
            end
        end


        SST_HOLD_RESET: begin
            if (ss_counter == 1000) begin
                ss_state <= SST_WAIT_RESET;
            end
        end

        SST_WAIT_RESET: begin
            if (cpu_ds_n == 2'b00 && !cpu_rw && cpu_word_addr == 24'hff0002) begin
                ss_state <= SST_IDLE;
            end
        end

        default: begin
            ss_state <= SST_IDLE;
        end
    endcase
end

//////////////////////////////////
//// CHIP SELECTS

logic ROMn; // CPU ROM
logic WORKn; // CPU RAM
logic SCREENn;
logic COLORn;
logic IOn;
logic OBJECTn;

wire SDTACKn, CDTACKn;

wire sdr_dtack_n = sdr_cpu_req != sdr_cpu_ack;

wire DTACKn = sdr_dtack_n | SDTACKn | CDTACKn;
wire [2:0] IPLn;

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
    .cen_in(~ss_pause),
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
wire IACKn = ~&cpu_fc;

fx68k m68000(
    .clk(clk),
    .HALTn(1),
    .extReset(reset | ss_reset),
    .pwrUp(reset | ss_reset),
    .enPhi1(ce_12m),
    .enPhi2(ce_12m_180),

    .eRWn(cpu_rw), .ASn(cpu_as_n), .LDSn(cpu_ds_n[0]), .UDSn(cpu_ds_n[1]),
    .E(), .VMAn(),

    .FC0(cpu_fc[0]), .FC1(cpu_fc[1]), .FC2(cpu_fc[2]),
    .BGn(),
    .oRESETn(), .oHALTEDn(),
    .DTACKn(DTACKn), .VPAn(IACKn),
    .BERRn(1),
    .BRn(1), .BGACKn(1),
    .IPL0n(IPLn[0]), .IPL1n(IPLn[1]), .IPL2n(IPLn[2]),
    .iEdb(cpu_data_in), .oEdb(cpu_data_out),
    .eab(cpu_addr)
);

wire [7:0] io_data_out;

TC0220IOC tc0220ioc(
    .clk,

    .RES_CLK_IN(0),
    .RES_INn(1),
    .RES_OUTn(),

    .A(cpu_addr[3:0]),
    .WEn(cpu_rw),
    .CSn(IOn),
    .OEn(0),

    .Din(cpu_data_out[7:0]),
    .Dout(io_data_out),

    .COIN_LOCK_A(),
    .COIN_LOCK_B(),
    .COINMETER_A(),
    .COINMETER_B(),

    .INB(8'hff),
    .IN(32'hffffffff)
);

wire [14:0] obj_ram_addr;
wire [15:0] obj_din, obj_dout;
wire [15:0] objram_data_out;
wire [11:0] obj_dot;

m68k_ram_unreg #(.WIDTHAD(15), .SS_IDX(SSIDX_OBJ_RAM)) objram(
    .clock(clk),
    .address(cpu_addr[14:0]),
    .we_lds_n(OBJECTn | cpu_ds_n[0]),
    .we_uds_n(OBJECTn | cpu_ds_n[1]),
    .data(cpu_data_out),
    .q(objram_data_out),
    .ssbus(ssbus)
);

TC0200OBJ tc0200obj(
    .clk,

    .ce_13m,
    .ce_pixel,

    .RA(obj_ram_addr),
    .Din(obj_din),
    .Dout(obj_dout),

    .RESET(0),
    .ERCSn(), // TODO - what generates this
    .EBUSY(), // TODO - what generates this
    .RDWEn(),

    .EDMAn(), // TODO - is dma started by vblank?

    .DOT(obj_dot),

    .EXHBLn(HBLOn),
    .EXVBLn(VBLOn),

    .HSYNCn(),
    .VSYNCn(),
    .HBLn(),
    .VBLn(),

    .ddr(ddr_obj),

    .ssbus
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

m68k_ram_unreg #(.WIDTHAD(15), .SS_IDX(SSIDX_SCN_RAM_0)) scn_ram_0(
    .clock(clk),
    .address(scn_main_ram_addr),
    .we_lds_n(scn_main_ram_ce_0_n | scn_main_ram_we_lo_n),
    .we_uds_n(scn_main_ram_ce_0_n | scn_main_ram_we_up_n),
    .data(scn_main_ram_dout),
    .q(scn_main_ram_din),
    .ssbus(ssbus)
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
assign sdr_scn_main_addr = { 11'b0, scn_main_rom_address[20:0] };

TC0100SCN #(.SS_IDX(SSIDX_SCN_0)) scn_main(
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
    .IVLD(0),

    .ssbus
);


wire [15:0] pri_data_out;
wire [12:0] pri_ram_addr;
wire [15:0] pri_ram_din, pri_ram_dout;
wire pri_ram_we_l_n, pri_ram_we_h_n;

m68k_ram_unreg #(.WIDTHAD(12), .SS_IDX(SSIDX_PRI_RAM)) pri_ram(
    .clock(clk),
    .address(pri_ram_addr[12:1]),
    .we_lds_n(pri_ram_we_l_n),
    .we_uds_n(pri_ram_we_h_n),
    .data(pri_ram_dout),
    .q(pri_ram_din),
    .ssbus(ssbus)
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
    .OB({3'b0, obj_dot}),

    // RAM Interface
    .CA(pri_ram_addr),
    .CDin(pri_ram_din),
    .CDout(pri_ram_dout),
    .WELn(pri_ram_we_l_n),
    .WEHn(pri_ram_we_h_n)
);


//////////////////////////////////
//// Interrupt Processing
wire ICLR1n = ~(~IACKn & (cpu_addr[2:0] == 3'b101) & ~cpu_ds_n[0]);
wire ICLR2n = ~(~IACKn & (cpu_addr[2:0] == 3'b110) & ~cpu_ds_n[0]);
wire clear_save_n = ~(~IACKn & (cpu_addr[2:0] == 3'b111) & ~cpu_ds_n[0]);

reg int_req1, int_req2;
reg vbl_prev, dma_prev;

reg save_req, save_prev;
assign IPLn = save_req ? ~3'b111 :
              int_req2 ? ~3'b110 :
              int_req1 ? ~3'b101 :
              ~3'b000;

always_ff @(posedge clk) begin
    vbl_prev <= VBLOn;
    dma_prev <= VBLOn;
    save_prev <= ss_do_save;

    if (reset) begin
        int_req2 <= 0;
        int_req1 <= 0;
    end else begin
        if (vbl_prev & ~VBLOn) begin
            int_req1 <= 1;
        end
        if (~dma_prev & VBLOn) begin
            int_req2 <= 1;
        end

        if (~save_prev & ss_do_save) begin
            save_req <= 1;
        end

        if (~ICLR1n) begin
            int_req1 <= 0;
        end

        if (~ICLR2n) begin
            int_req2 <= 0;
        end

        if (~clear_save_n) begin
            save_req <= 0;
        end
    end
end

logic SS_SAVEn, SS_RESETn, SS_VECn;

/* verilator lint_off CASEX */
always_comb begin
    WORKn = 1;
    ROMn = 1;
    SCREENn = 1;
    COLORn = 1;
    IOn = 1;
    OBJECTn = 1;
    SS_SAVEn = 1;
    SS_RESETn = 1;
    SS_VECn = 1;

    if (~&cpu_ds_n) begin
        casex(cpu_word_addr)
            24'h00000x: begin
                if (ss_restart) begin
                    SS_RESETn = 0;
                end else begin
                    ROMn = 0;
                end
            end
            24'h00007c: SS_VECn = 0;
            24'h00007e: SS_VECn = 0;
            24'h0xxxxx: ROMn = 0;
            24'h1xxxxx: WORKn = 0;
            24'h8xxxxx: SCREENn = 0;
            24'h9xxxxx: OBJECTn = 0;
            24'h2xxxxx: COLORn = 0;
            24'h30xxxx: IOn = 0;
            24'hff00xx: SS_SAVEn = 0;
        endcase
    end
end
/* verilator lint_on CASEX */

assign cpu_data_in = ~ROMn ? sdr_cpu_q :
                     ~WORKn ? sdr_cpu_q :
                     ~SCREENn ? scn_main_data_out :
                     ~OBJECTn ? objram_data_out :
                     ~COLORn ? pri_data_out :
                     ~IOn ? { 8'b0, io_data_out } :
                     ~SS_SAVEn ? save_handler[cpu_addr[3:0]] :
                     ~SS_RESETn ? reset_vector[cpu_addr[1:0]] :
                     ~SS_VECn ? ( cpu_addr[0] ? 16'h0000 : 16'h00ff ) :
                     16'd0;

reg prev_ds_n;
reg ss_sdr_active;

always_ff @(posedge clk) begin
    prev_ds_n <= &cpu_ds_n;

    ssbus.setup(SSIDX_CPU_RAM, 32'h8000, 1);

    if (ssbus.access(SSIDX_CPU_RAM)) begin
        if (ssbus.read) begin
            if (~ss_sdr_active) begin
                sdr_cpu_addr <= 32'h100000 + { 9'b0, ssbus.addr[21:0], 1'b0 };
                sdr_cpu_be <= 2'b11;
                sdr_cpu_rw <= 1;
                sdr_cpu_req <= ~sdr_cpu_req;
                ss_sdr_active <= 1;
            end else if (sdr_cpu_req == sdr_cpu_ack) begin
                ssbus.read_response(SSIDX_CPU_RAM, {48'b0, sdr_cpu_q});
            end
        end else if (ssbus.write) begin
            if (~ss_sdr_active) begin
                sdr_cpu_addr <= 32'h100000 + { 9'b0, ssbus.addr[21:0], 1'b0 };
                sdr_cpu_be <= 2'b11;
                sdr_cpu_rw <= 0;
                sdr_cpu_req <= ~sdr_cpu_req;
                sdr_cpu_data <= ssbus.data[15:0];
                ss_sdr_active <= 1;
            end else if (sdr_cpu_req == sdr_cpu_ack) begin
                ssbus.write_ack(SSIDX_CPU_RAM);
            end
        end
    end else if (~(ROMn & WORKn) & prev_ds_n) begin
        sdr_cpu_addr <= { 8'b0, cpu_word_addr };
        sdr_cpu_data <= cpu_data_out;
        sdr_cpu_be <= ~cpu_ds_n;
        sdr_cpu_rw <= cpu_rw;
        sdr_cpu_req <= ~sdr_cpu_req;
        ss_sdr_active <= 0;
    end else begin
        ss_sdr_active <= 0;
    end
end

save_state_data save_state_data(
    .clk,
    .reset(0),

    .ddr(ddr_ss),

    .read_start(ss_read),
    .write_start(ss_write),
    .busy(ss_busy),

    .ssbus(ssbus)
);


endmodule
