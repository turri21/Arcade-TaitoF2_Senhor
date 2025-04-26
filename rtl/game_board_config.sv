import system_consts::*;

module game_board_config(
    input clk,
    input game_t game,

    output reg       cfg_360pri,
    output reg       cfg_110pcr,
    output reg       cfg_260dar,
    output reg [1:0] cfg_obj_extender
);

// register these values to help with timing
//
always_ff @(posedge clk) begin
    case(game)
        GAME_FINALB:  begin cfg_360pri <= 0; cfg_260dar <= 0; cfg_110pcr <= 1; cfg_obj_extender <= 2'b00; end
        GAME_QJINSEI: begin cfg_360pri <= 1; cfg_260dar <= 1; cfg_110pcr <= 0; cfg_obj_extender <= 2'b01; end
        GAME_DINOREX: begin cfg_360pri <= 1; cfg_260dar <= 1; cfg_110pcr <= 0; cfg_obj_extender <= 2'b01; end
        default:      begin cfg_360pri <= 0; cfg_260dar <= 0; cfg_110pcr <= 0; cfg_obj_extender <= 2'b00; end
    endcase
end

endmodule

