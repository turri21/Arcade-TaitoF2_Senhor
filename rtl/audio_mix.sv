module audio_mix(
    input clk,
    input reset,

    input         [1:0] en,

    input               fm_sample,
    input signed [15:0] fm_left,
    input signed [15:0] fm_right,
    input        [ 9:0] psg,

    output reg signed [15:0] mono_output

);

// 8.746560Mhz and 4.373280Mhz
// 45555hz from PCM * 96. Dunno, maybe it helps
// 8mhz 16mhz
wire ce_2x, ce;
jtframe_frac_cen #(2) mix_cen
(
    .clk(clk),
    .cen_in(1),
    .n(10'd277),
    .m(10'd924),
    .cen({ce, ce_2x}),
    .cenb()
);


wire [15:0] fm_left_flt1, fm_left_flt2;
wire [15:0] fm_right_flt1, fm_right_flt2;

IIR_filter #( .use_params(1), .stereo(1),
    .coeff_x(0.00037375572460605829),
    .coeff_x0(2), .coeff_x1(1), .coeff_x2(0),
    .coeff_y0(-1.97667590380070512524), .coeff_y1(0.97694479281121304748), .coeff_y2(0.00000000000000000000)
    ) pre_filter (
    .clk(clk),
    .reset(reset),

    .ce(ce_2x),
    .sample_ce(ce),

    .cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

    .input_l(fm_left),
    .input_r(fm_right),
    .output_l(fm_left_flt1),
    .output_r(fm_right_flt1)
);

IIR_filter #( .use_params(1), .stereo(1),
    .coeff_x(0.00000004211710923317),
    .coeff_x0(3), .coeff_x1(3), .coeff_x2(1),
    .coeff_y0(-2.99256999191671635430), .coeff_y1(2.98516459847797177574), .coeff_y2(-0.99259457626117686413)
    ) main_filter (
    .clk(clk),
    .reset(reset),

    .ce(ce_2x),
    .sample_ce(ce),

    .cx(), .cx0(), .cx1(), .cx2(), .cy0(), .cy1(), .cy2(),

    .input_l(en[0] ? fm_left_flt1 : fm_left),
    .input_r(en[0] ? fm_right_flt1 : fm_right),
    .output_l(fm_left_flt2),
    .output_r(fm_right_flt2)
);

wire [15:0] fm_left_final = en[1] ? fm_left_flt2 : en[0] ? fm_left_flt1 : fm_left;
wire [15:0] fm_right_final = en[1] ? fm_right_flt2 : en[0] ? fm_right_flt1 : fm_left;

always @(posedge clk) begin
    mono_output <= { fm_left_final[15], fm_left_final[15:1] } + { fm_right_final[15], fm_right_final[15:1] } + { 1'b0, psg[9:0], 5'd0 };
end

endmodule



