module TC0220IOC(
    input clk,

    input             RES_CLK_IN,
    input             RES_INn,
    output            RES_OUTn,

    input       [3:0] A,
    input             WEn,
    input             CSn,
    input             OEn,

    input       [7:0] Din,
    output reg  [7:0] Dout,

    output reg        COIN_LOCK_A,
    output reg        COIN_LOCK_B,
    output reg        COINMETER_A,
    output reg        COINMETER_B,

    input       [7:0] INB,
    input      [31:0] IN
);

// TODO reset, watchdog

always_ff @(posedge clk) begin
    if (~CSn) begin
        if (WEn) begin
            case(A)
                0: Dout <= IN[7:0];
                1: Dout <= IN[15:8];
                2: Dout <= IN[23:16];
                3: Dout <= IN[31:24];
                4: Dout <= { 4'b0, COINMETER_B, COINMETER_A, COIN_LOCK_B, COIN_LOCK_A };
                7: Dout <= INB;
                default: Dout <= 8'b0;
            endcase
        end else begin
            case(A)
                4: { COINMETER_B, COINMETER_A, COIN_LOCK_B, COIN_LOCK_A } <= Din[3:0];
                default: begin end
            endcase
        end
    end
end

endmodule


