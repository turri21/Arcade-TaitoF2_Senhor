import system_consts::*;

module address_translator(
    input game_t game,

    input [1:0]  cpu_ds_n,
    input [23:0] cpu_word_addr,
    input        ss_restart,

    output logic WORKn,
    output logic ROMn,
    output logic SCREENn,
    output logic COLORn,
    output logic IOn,
    output logic OBJECTn,
    output logic SOUNDn,
    output logic PRIORITYn,
    output logic extension_n,
    output logic SS_SAVEn,
    output logic SS_RESETn,
    output logic SS_VECn
);

/* verilator lint_off CASEX */

always_comb begin
    WORKn = 1;
    ROMn = 1;
    SCREENn = 1;
    COLORn = 1;
    PRIORITYn = 1;
    IOn = 1;
    OBJECTn = 1;
    SOUNDn = 1;
    SS_SAVEn = 1;
    SS_RESETn = 1;
    SS_VECn = 1;
    extension_n = 1;

    if (~&cpu_ds_n) begin
        case(game)
            GAME_FINALB: begin
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
                    24'h32xxxx: SOUNDn = 0;
                    24'hff00xx: SS_SAVEn = 0;
                endcase
            end

            GAME_DINOREX: begin
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
                    24'h1xxxxx: ROMn = 0;
                    24'h2xxxxx: ROMn = 0;
                    24'h30xxxx: IOn = 0;
                    24'h4xxxxx: extension_n = 0;
                    24'h5xxxxx: COLORn = 0;
                    24'h6xxxxx: WORKn = 0;
                    24'h7xxxxx: PRIORITYn = 0;
                    24'h8xxxxx: OBJECTn = 0;
                    24'h9xxxxx: SCREENn = 0;
                    24'ha0xxxx: SOUNDn = 0;
                    24'hff00xx: SS_SAVEn = 0;
                endcase
            end

            GAME_QJINSEI: begin
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
                    24'h1xxxxx: ROMn = 0;
                    24'h20xxxx: SOUNDn = 0;
                    24'h3xxxxx: WORKn = 0;
                    24'h6xxxxx: extension_n = 0;
                    24'h7xxxxx: COLORn = 0;
                    24'h8xxxxx: SCREENn = 0;
                    24'h9xxxxx: OBJECTn = 0;
                    24'hb0xxxx: IOn = 0;
                    24'hff00xx: SS_SAVEn = 0;
                endcase
            end

            GAME_LIQUIDK: begin
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
                    24'h2xxxxx: COLORn = 0;
                    24'h30xxxx: IOn = 0;
                    24'h32xxxx: SOUNDn = 0;
                    24'h8xxxxx: SCREENn = 0;
                    24'h9xxxxx: OBJECTn = 0;
                    24'hff00xx: SS_SAVEn = 0;
                endcase
            end


            default: begin
            end
        endcase
    end
end
/* verilator lint_on CASEX */


endmodule


