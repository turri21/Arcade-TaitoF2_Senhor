module TC0260DAR(
    input clk,
    input ce_pixel,

    // CPU Interface
    input [15:0] MDin,
    output reg [15:0] MDout,

    input        CS,
    input [13:0] MA,
    input RWn,
    input UDSn,
    input LDSn,

    output DTACKn,

    // Video Input
    input HBLANKn,
    input VBLANKn,

    input [13:0] IM,
    output reg [7:0] VIDEOR,
    output reg [7:0] VIDEOG,
    output reg [7:0] VIDEOB,

    // RAM Interface
    // Real hardware uses and 8-bit interface and is clocked at double the
    // pixel clock. I'm using a 16-bit interface to remain compatible with the
    // TC0100PR usage of block ram
    output [13:0] RA,
    input [15:0] RDin,
    output [15:0] RDout,
    output reg RWELn,
    output reg RWEHn
);

assign MDout = RDin;
assign RDout = MDin;
assign RA = CS ? MA : IM;
assign RWELn = CS ? (RWn | LDSn) : 1;
assign RWEHn = CS ? (RWn | UDSn) : 1;
assign DTACKn = 0;


always_ff @(posedge clk) begin
    if (ce_pixel) begin
        if (HBLANKn & VBLANKn) begin
//            VIDEOR <= { RDin[12], RDin[3:0], RDin[12], RDin[3:2] };
//            VIDEOG <= { RDin[13], RDin[7:4], RDin[13], RDin[7:6] };
//            VIDEOB <= { RDin[14], RDin[11:8], RDin[14], RDin[11:10] };
            VIDEOR <= { RDin[15:12], RDin[3], RDin[15:13] };
            VIDEOG <= { RDin[11:8], RDin[2], RDin[11:9] };
            VIDEOB <= { RDin[7:4], RDin[1], RDin[7:5] };
        end else begin
            VIDEOR <= 8'd0;
            VIDEOG <= 8'd0;
            VIDEOB <= 8'd0;
        end
    end
end

endmodule



