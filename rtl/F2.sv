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
    output     [31:0] mem_addr,
    output     [63:0] mem_wdata,
    input      [63:0] mem_rdata,
    output            mem_read,
    output            mem_write,
    input             mem_busy,
    input             mem_read_complete,

    input ss_save_test,
    input ss_restore_test,
    input ss_do_save,
    input ss_do_restore,
    output [3:0] ss_state_out,
    output reg [31:0] ss_saved_ssp,
    input [31:0] ss_restore_ssp
);

// Stream interface control signals - these would typically be connected to CPU or other control logic
reg [31:0] stream_start_addr;
reg [31:0] stream_length = 32'h00100000;
reg        stream_read_start = ss_restore_test;
wire       stream_write_start = ss_save_test;
wire       stream_busy;
wire       stream_read_req;
wire [63:0] stream_read_data;
wire        stream_data_ack;
wire       stream_write_req;
wire [63:0]  stream_write_data;

wire [31:0] stream_chunk_address;
wire [7:0] stream_chunk_index;
wire       stream_query_req;

ss2device_if ssd(
    .data(stream_write_data),
    .addr(stream_chunk_address[23:0]),
    .idx(stream_chunk_index),
    .write(stream_write_req),
    .query(stream_query_req),
    .read(stream_read_req)
);

ss2master_if ssm1(), ssm2(), ssm3(), ssm4(), ssm_sdr();

assign stream_data_ack = ssm1.ack | ssm2.ack | ssm3.ack | ssm4.ack | ssm_sdr.ack;
assign stream_read_data = ssm1.data | ssm2.data | ssm3.data | ssm4.data | ssm_sdr.data;

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
    SST_START_SAVE = 1,
    SST_WAIT_SAVE = 2,
    SST_SAVE_PAUSED = 3,
    SST_START_RESTORE = 4,
    SST_HOLD_RESET = 5,
    SST_WAIT_RESET = 6
} ss_state_t;

ss_state_t ss_state = SST_IDLE;
reg [15:0] ss_counter;
reg [15:0] reset_vector[4];

wire ss_pause = (ss_state == SST_SAVE_PAUSED) || (ss_state == SST_START_RESTORE);
wire ss_reset = (ss_state == SST_HOLD_RESET);
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
                ss_state <= SST_START_RESTORE;
                reset_vector[0] <= ss_restore_ssp[31:16];
                reset_vector[1] <= ss_restore_ssp[15:0];
                reset_vector[2] <= 16'h00ff;
                reset_vector[3] <= 16'h0008;
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
                ss_state <= SST_SAVE_PAUSED;
            end
        end


        SST_SAVE_PAUSED: begin
            if (~ss_do_save) begin
                ss_state <= SST_IDLE;
            end
        end

        SST_START_RESTORE: begin
            if (~ss_do_restore) begin
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


//////////////////////////////////
//// SCREEN TC0100SCN
wire [14:0] scn_main_ram_addr;
wire [15:0] scn_main_data_out;
wire [15:0] scn_main_ram_din;
wire [15:0] scn_main_ram_dout;
wire scn_main_ram_we_up_n, scn_main_ram_we_lo_n;
wire scn_main_ram_ce_0_n, scn_main_ram_ce_1_n;

wire [14:0] scn_main_dot_color;

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(15), .NAME("SC0L"), .SS_IDX(1)) scn_ram_0_lo(
    .clock(clk),
    .address(scn_main_ram_addr),
    .wren(~(scn_main_ram_ce_0_n | scn_main_ram_we_lo_n)),
    .data(scn_main_ram_dout[7:0]),
    .q(scn_main_ram_din[7:0]),
    .ssd(ssd),
    .ssm(ssm1)
);

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(15), .NAME("SC0U"), .SS_IDX(2)) scn_ram_0_up(
    .clock(clk),
    .address(scn_main_ram_addr),
    .wren(~(scn_main_ram_ce_0_n | scn_main_ram_we_up_n)),
    .data(scn_main_ram_dout[15:8]),
    .q(scn_main_ram_din[15:8]),
    .ssd(ssd),
    .ssm(ssm2)
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

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(12), .NAME("PRIL"), .SS_IDX(3)) pri_ram_l(
    .clock(clk),
    .address(pri_ram_addr[12:1]),
    .wren(~pri_ram_we_l_n),
    .data(pri_ram_dout[7:0]),
    .q(pri_ram_din[7:0]),
    .ssd(ssd),
    .ssm(ssm3)
);

singleport_ram_unreg #(.WIDTH(8), .WIDTHAD(12), .NAME("PRIH"), .SS_IDX(4)) pri_ram_h(
    .clock(clk),
    .address(pri_ram_addr[12:1]),
    .wren(~pri_ram_we_h_n),
    .data(pri_ram_dout[15:8]),
    .q(pri_ram_din[15:8]),
    .ssd(ssd),
    .ssm(ssm4)
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
    ssm_sdr.ack <= 0;

    if (ssd.sel(5)) begin
        if (ssd.qry(5)) begin
            ssm_sdr.query_response(5, 32'h8000, 1);
        end else if (ssd.rd(5)) begin
            if (~ss_sdr_active) begin
                sdr_cpu_addr <= 32'h100000 + { 9'b0, ssd.addr[21:0], 1'b0 };
                sdr_cpu_be <= 2'b11;
                sdr_cpu_rw <= 1;
                sdr_cpu_req <= ~sdr_cpu_req;
                ss_sdr_active <= 1;
            end else if (sdr_cpu_req == sdr_cpu_ack) begin
                ssm_sdr.ack <= 1;
                ssm_sdr.data <= { 48'b0, sdr_cpu_q };
            end
        end else if (ssd.wr(5)) begin
            if (~ss_sdr_active) begin
                sdr_cpu_addr <= 32'h100000 + { 9'b0, ssd.addr[21:0], 1'b0 };
                sdr_cpu_be <= 2'b11;
                sdr_cpu_rw <= 0;
                sdr_cpu_req <= ~sdr_cpu_req;
                sdr_cpu_data <= ssd.data[15:0];
                ss_sdr_active <= 1;
            end else if (sdr_cpu_req == sdr_cpu_ack) begin
                ssm_sdr.ack <= 1;
            end
        end else begin
            ss_sdr_active <= 0;
        end
    end else if (~(ROMn & WORKn) & prev_ds_n) begin
        ss_sdr_active <= 0;
        sdr_cpu_addr <= { 8'b0, cpu_word_addr };
        sdr_cpu_data <= cpu_data_out;
        sdr_cpu_be <= ~cpu_ds_n;
        sdr_cpu_rw <= cpu_rw;
        sdr_cpu_req <= ~sdr_cpu_req;
        ss_sdr_active <= 0;
    end
end

// Instantiate the memory_stream module
memory_stream memory_stream_inst (
    .clk(clk),
    .reset(reset),

    // Memory interface
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_busy(mem_busy),
    .mem_read_complete(mem_read_complete),

    // Stream interface for reading
    .read_req(stream_read_req),
    .read_data(stream_read_data),
    .data_ack(stream_data_ack),

    // Stream interface for writing
    .write_req(stream_write_req),
    .write_data(stream_write_data),

    // Control signals
    .start_addr(stream_start_addr),
    .length(stream_length),
    .read_start(stream_read_start),
    .write_start(stream_write_start),
    .busy(stream_busy),

    .chunk_index(stream_chunk_index),
    .chunk_address(stream_chunk_address),
    .query_req(stream_query_req)
);

endmodule
