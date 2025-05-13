import system_consts::*;

module address_translator(
    input game_t game,

    input [1:0]  cpu_ds_n,
    input [23:0] cpu_word_addr,
    input        ss_override,

    input [15:0] cfg_addr_rom,
    input [15:0] cfg_addr_rom1,
    input [15:0] cfg_addr_work_ram,
    input [15:0] cfg_addr_screen,
    input [15:0] cfg_addr_obj,
    input [15:0] cfg_addr_color,
    input [15:0] cfg_addr_io0,
    input [15:0] cfg_addr_io1,
    input [15:0] cfg_addr_sound,
    input [15:0] cfg_addr_extension,
    input [15:0] cfg_addr_priority,
    input [15:0] cfg_addr_roz,

    output logic WORKn,
    output logic ROMn,
    output logic SCREENn,
    output logic COLORn,
    output logic IO0n,
    output logic IO1n,
    output logic OBJECTn,
    output logic SOUNDn,
    output logic PRIORITYn,
    output logic EXTENSIONn,
    output logic SS_SAVEn,
    output logic SS_RESETn,
    output logic SS_VECn
);

function bit match_addr_n(input [23:0] addr, input [15:0] sel);
    bit r;
    r = (addr[23:16] & sel[7:0]) == sel[15:8];
    return ~r;
endfunction


/* verilator lint_off CASEX */

always_comb begin
    WORKn = 1;
    ROMn = 1;
    SCREENn = 1;
    COLORn = 1;
    PRIORITYn = 1;
    IO0n = 1;
    IO1n = 1;
    OBJECTn = 1;
    SOUNDn = 1;
    SS_SAVEn = 1;
    SS_RESETn = 1;
    SS_VECn = 1;
    EXTENSIONn = 1;

    if (ss_override) begin
        if (~&cpu_ds_n) begin
            casex(cpu_word_addr)
                24'h00000x: begin
                    SS_RESETn = 0;
                end
                24'h00007c: begin
                    SS_VECn = 0;
                end
                24'h00007e: begin
                    SS_VECn = 0;
                end
                24'hff00xx: begin
                    SS_SAVEn = 0;
                end
            endcase
        end
    end

    if (~&cpu_ds_n) begin
        ROMn = match_addr_n(cpu_word_addr, cfg_addr_rom)
                & match_addr_n(cpu_word_addr, cfg_addr_rom1);
        WORKn = match_addr_n(cpu_word_addr, cfg_addr_work_ram);
        SCREENn = match_addr_n(cpu_word_addr, cfg_addr_screen);
        OBJECTn = match_addr_n(cpu_word_addr, cfg_addr_obj);
        COLORn = match_addr_n(cpu_word_addr, cfg_addr_color);
        IO0n = match_addr_n(cpu_word_addr, cfg_addr_io0);
        IO1n = match_addr_n(cpu_word_addr, cfg_addr_io1);
        SOUNDn = match_addr_n(cpu_word_addr, cfg_addr_sound);
        EXTENSIONn = match_addr_n(cpu_word_addr, cfg_addr_extension);
        PRIORITYn = match_addr_n(cpu_word_addr, cfg_addr_priority);
    end
end
/* verilator lint_on CASEX */


endmodule


