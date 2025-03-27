package system_consts;
    parameter int SSIDX_GLOBAL = 0;
    parameter int SSIDX_SCN_RAM_0 = 1;
    parameter int SSIDX_PRI_RAM = 2;
    parameter int SSIDX_CPU_RAM = 3;
    parameter int SSIDX_SCN_0 = 4;
    parameter int SSIDX_OBJ_RAM = 5;

    
    parameter bit [31:0] SS_DDR_BASE = 32'h00000000;
    parameter bit [31:0] OBJ_FB_DDR_BASE = 32'h00100000;
    parameter bit [31:0] OBJ_DATA_DDR_BASE = 32'h00200000;

endpackage


