module TC0260DAR(
    input clk,
    input ce_pixel,
    input ce_double,

    // CPU Interface
    input [15:0] MDin,
    output reg [15:0] MDout,

    input        CS,
    input [13:0] MA,
    input RWn,
    input UDSn,
    input LDSn,

    output DTACKn,

    input ACCMODE,

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

wire busy = ~ACCMODE ? (HBLANKn & VBLANKn) : 0;
reg cpu_access;

assign MDout = RDin;
assign RDout = MDin;
assign RA = cpu_access ? MA : IM;
assign RWELn = cpu_access ? (RWn | LDSn) : 1;
assign RWEHn = cpu_access ? (RWn | UDSn) : 1;
assign DTACKn = CS ? ~cpu_access : 0;


always_ff @(posedge clk) begin
    if (ce_double) begin
        cpu_access <= CS & (~busy | cpu_access);
    end

    if (ce_pixel) begin
        if (HBLANKn & VBLANKn & ~cpu_access) begin
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



