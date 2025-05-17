#include "games.h"
#include "sim_sdram.h"
#include "sim_ddr.h"

#include "F2.h"
#include "F2___024root.h"

#include <string.h>

extern F2 *top;

static const char *game_names[N_GAMES] =
{
    "finalb",
    "dondokod",
    "megab",
    "thundfox",
    "cameltry",
    "qtorimon",
    "liquidk",
    "quizhq",
    "ssi",
    "gunfront",
    "growl",
    "mjnquest",
    "footchmp",
    "koshien",
    "yuyugogo",
    "ninjak",
    "solfigtr",
    "qzquest",
    "pulirula",
    "metalb",
    "qzchikyu",
    "yesnoj",
    "deadconx",
    "dinorex",
    "qjinsei",
    "qcrayon",
    "qcrayon2",
    "driftout",
    "finalb_test",
    "qjinsei_test"
};


game_t game_find(const char *name)
{
    for( int i = 0; i < N_GAMES; i++ )
    {
        if (!strcasecmp(name, game_names[i]))
        {
            return (game_t)i;
        }
    }

    return GAME_INVALID;
}

const char *game_name(game_t game)
{
    if (game == GAME_INVALID) return "INVALID";
    return game_names[game];
}

static bool load_audio(const char *name)
{
    FILE *fp = fopen("name", "rb");
    if (fp == NULL)
    {
        printf("Could not open audio rom %s\n", name);
        return false;
    }

    fread((unsigned char *)top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 1, 64 * 1024, fp);
    fclose(fp);

    return true;
}

static void load_finalb_test()
{
    load_audio("../testroms/build/finalb_test/finalb/b82_10.ic5");

    sdram.load_data("../testroms/build/finalb_test/finalb/b82-09.ic23", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../testroms/build/finalb_test/finalb/b82-17.ic11", CPU_ROM_SDR_BASE + 0, 2);

    sdram.load_data("../roms/b82-07.ic34", SCN0_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/b82-06.ic33", SCN0_ROM_SDR_BASE + 0, 2);
    
    sdram.load_data("../roms/b82-02.ic1",  ADPCMA_ROM_SDR_BASE, 1);
    sdram.load_data("../roms/b82-01.ic2",  ADPCMB_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/b82-03.ic9", OBJ_DATA_DDR_BASE + 0, 4);
    ddr_memory.load_data("../roms/b82-04.ic8", OBJ_DATA_DDR_BASE + 1, 4);
    ddr_memory.load_data("../roms/b82-05.ic7", OBJ_DATA_DDR_BASE + 2, 4);

    top->game = GAME_FINALB;
}

static void load_finalb()
{
    load_audio("../roms/b82_10.ic5");

    sdram.load_data("../roms/b82-09.ic23", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/b82-17.ic11", CPU_ROM_SDR_BASE + 0, 2);

    sdram.load_data("../roms/b82-07.ic34", SCN0_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/b82-06.ic33", SCN0_ROM_SDR_BASE + 0, 2);
    
    sdram.load_data("../roms/b82-02.ic1",  ADPCMA_ROM_SDR_BASE, 1);
    sdram.load_data("../roms/b82-01.ic2",  ADPCMB_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/b82-03.ic9", OBJ_DATA_DDR_BASE + 0, 4);
    ddr_memory.load_data("../roms/b82-04.ic8", OBJ_DATA_DDR_BASE + 1, 4);
    ddr_memory.load_data("../roms/b82-05.ic7", OBJ_DATA_DDR_BASE + 2, 4);
    
    top->game = GAME_FINALB;
}

static void load_qjinsei()
{
    load_audio("../roms/d48-11");

    sdram.load_data("../roms/d48-09", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/d48-10", CPU_ROM_SDR_BASE + 0, 2);
    sdram.load_data("../roms/d48-03", CPU_ROM_SDR_BASE + 0x100000, 1);

    sdram.load_data("../roms/d48-04", SCN0_ROM_SDR_BASE, 1);
    
    sdram.load_data("../roms/d48-05",  ADPCMA_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/d48-02", OBJ_DATA_DDR_BASE + 0, 2);
    ddr_memory.load_data("../roms/d48-01", OBJ_DATA_DDR_BASE + 1, 2);
    
    top->game = GAME_QJINSEI;
}

static void load_qjinsei_test()
{
    load_qjinsei();
    
    load_audio("../testroms/build/qjinsei_test/qjinsei/d48-11");
    sdram.load_data("../testroms/build/qjinsei_test/qjinsei/d48-09", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../testroms/build/qjinsei_test/qjinsei/d48-10", CPU_ROM_SDR_BASE + 0, 2);
}


static void load_dinorex()
{
    load_audio("../roms/d39-12.5");

    sdram.load_data("../roms/d39-14.9", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/d39-16.8", CPU_ROM_SDR_BASE + 0, 2);
    sdram.load_data("../roms/d39-04.6", CPU_ROM_SDR_BASE + 0x100000, 1);
    sdram.load_data("../roms/d39-05.7", CPU_ROM_SDR_BASE + 0x200000, 1);

    sdram.load_data("../roms/d39-06.2", SCN0_ROM_SDR_BASE, 1);

    sdram.load_data("../roms/d39-07.10",  ADPCMA_ROM_SDR_BASE, 1);
    sdram.load_data("../roms/d39-08.4",  ADPCMB_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/d39-01.29", OBJ_DATA_DDR_BASE, 1);
    ddr_memory.load_data("../roms/d39-02.28", OBJ_DATA_DDR_BASE + 0x200000, 1);
    ddr_memory.load_data("../roms/d39-03.27", OBJ_DATA_DDR_BASE + 0x400000, 1);

    top->game = GAME_DINOREX;
}

static void load_liquidk()
{
    load_audio("../roms/c49-08.ic32");

    sdram.load_data("../roms/c49-09.ic47", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/c49-11.ic48", CPU_ROM_SDR_BASE + 0, 2);
    sdram.load_data("../roms/c49-10.ic45", CPU_ROM_SDR_BASE + 0x40001, 2);
    sdram.load_data("../roms/c49-12.ic46", CPU_ROM_SDR_BASE + 0x40000, 2);
	
    sdram.load_data("../roms/c49-03.ic76", SCN0_ROM_SDR_BASE, 1);
    
    sdram.load_data("../roms/c49-04.ic33",  ADPCMA_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/c49-01.ic54", OBJ_DATA_DDR_BASE, 1);
    ddr_memory.load_data("../roms/c49-02.ic53", OBJ_DATA_DDR_BASE + 0x80000, 1);

    top->game = GAME_LIQUIDK;
}

static void load_growl()
{
    load_audio("../roms/c74-12.ic62");

    sdram.load_data("../roms/c74-10-1.ic59", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/c74-08-1.ic61", CPU_ROM_SDR_BASE + 0, 2);
    sdram.load_data("../roms/c74-11.ic58", CPU_ROM_SDR_BASE + 0x80001, 2);
    sdram.load_data("../roms/c74-14.ic60", CPU_ROM_SDR_BASE + 0x80000, 2);
	
    sdram.load_data("../roms/c74-01.ic34", SCN0_ROM_SDR_BASE, 1);
    
    sdram.load_data("../roms/c74-04.ic28",  ADPCMA_ROM_SDR_BASE, 1);
    sdram.load_data("../roms/c74-05.ic29",  ADPCMB_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/c74-03.ic12", OBJ_DATA_DDR_BASE, 1);
    ddr_memory.load_data("../roms/c74-02.ic11", OBJ_DATA_DDR_BASE + 0x100000, 1);

    top->game = GAME_GROWL;
}


bool game_init(game_t game)
{
    switch(game)
    {
        case GAME_FINALB: load_finalb(); break;
        case GAME_QJINSEI: load_qjinsei(); break;
        case GAME_LIQUIDK: load_liquidk(); break;
        case GAME_DINOREX: load_dinorex(); break;
        case GAME_FINALB_TEST: load_finalb_test(); break;
        case GAME_QJINSEI_TEST: load_qjinsei_test(); break;
        case GAME_GROWL: load_growl(); break;
        default: return false;
    }

    return true;
}


