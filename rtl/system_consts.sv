package system_consts;
    parameter int SSIDX_GLOBAL = 0;
    parameter int SSIDX_SCN_RAM_0 = 1;
    parameter int SSIDX_PRI_RAM = 2;
    parameter int SSIDX_CPU_RAM = 3;
    parameter int SSIDX_SCN_0 = 4;
    parameter int SSIDX_OBJ_RAM = 5;


`ifdef VERILATOR
    parameter bit [31:0] SS_DDR_BASE       = 32'h0000_0000;
    parameter bit [31:0] OBJ_FB_DDR_BASE   = 32'h0010_0000;
    parameter bit [31:0] OBJ_DATA_DDR_BASE = 32'h0020_0000;
`else
    parameter bit [31:0] SS_DDR_BASE       = 32'h3E00_0000;
    parameter bit [31:0] OBJ_FB_DDR_BASE   = 32'h3800_0000;
    parameter bit [31:0] OBJ_DATA_DDR_BASE = 32'h3810_0000;
`endif


    parameter bit [31:0] CPU_ROM_SDR_BASE  = 32'h0000_0000;
    parameter bit [31:0] WORK_RAM_SDR_BASE = 32'h0010_0000;
    parameter bit [31:0] SCN0_ROM_SDR_BASE = 32'h0020_0000;

    typedef enum bit [3:0] {
        STORAGE_SDR,
        STORAGE_DDR
    } region_storage_t;

    typedef enum bit [3:0] {
        ENCODING_NORMAL
    } region_encoding_t;

    typedef struct packed {
        bit [31:0] base_addr;
        region_storage_t storage;
        region_encoding_t encoding;
    } region_t;

    parameter region_t REGION_CPU_ROM  = '{ base_addr:CPU_ROM_SDR_BASE,  storage:STORAGE_SDR, encoding:ENCODING_NORMAL };
    parameter region_t REGION_SCN0     = '{ base_addr:SCN0_ROM_SDR_BASE, storage:STORAGE_SDR, encoding:ENCODING_NORMAL };
    parameter region_t REGION_OBJ0     = '{ base_addr:OBJ_DATA_DDR_BASE, storage:STORAGE_DDR, encoding:ENCODING_NORMAL };

    parameter region_t LOAD_REGIONS[3] = '{
        REGION_CPU_ROM,
        REGION_SCN0,
        REGION_OBJ0
    };

    typedef struct packed {
        bit [15:0] unused;
    } board_cfg_t;

endpackage


