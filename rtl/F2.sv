module F2(
    input clk,
    input reset
);

reg cpu_ce_count;
wire cpu_ce_1 = cpu_ce_count;
reg cpu_ce_2 = ~cpu_ce_count;

wire        cpu_rw, cpu_as_n;
wire [1:0]  cpu_ds_n;
wire [2:0]  cpu_fc;
wire [15:0] cpu_data_in, cpu_data_out;
wire [22:0] cpu_addr;
wire [23:0] cpu_word_addr = { cpu_addr, 1'b0 };

always_ff @(posedge clk) cpu_ce_count <= ~cpu_ce_count;

fx68k m68000(
    .clk(clk),
    .HALTn(1),
    .extReset(reset),
    .pwrUp(reset),
    .enPhi1(cpu_ce_1),
    .enPhi2(cpu_ce_2),

    .eRWn(cpu_rw), .ASn(cpu_as_n), .LDSn(cpu_ds_n[0]), .UDSn(cpu_ds_n[1]),
    .E(), .VMAn(),

    .FC0(cpu_fc[0]), .FC1(cpu_fc[1]), .FC2(cpu_fc[2]),
    .BGn(),
    .oRESETn(), .oHALTEDn(),
    .DTACKn(0), .VPAn(0),
    .BERRn(1),
    .BRn(1), .BGACKn(1),
    .IPL0n(1), .IPL1n(1), .IPL2n(1),
    .iEdb(cpu_data_in), .oEdb(cpu_data_out),
    .eab(cpu_addr)
);

endmodule
