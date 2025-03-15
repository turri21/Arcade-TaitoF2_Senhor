#ifndef SAVE_STATE_H
#define SAVE_STATE_H

#include "F2.h"
#include "F2___024root.h"
#include "sim_sdram.h"

// Save all RAM state to a file
bool save_ram_state(const char* filename, F2* top, SimSDRAM& cpu_sdram, SimSDRAM& scn_main_sdram);

// Load RAM state from a file
bool load_ram_state(const char* filename, F2* top, SimSDRAM& cpu_sdram, SimSDRAM& scn_main_sdram);

#endif // SAVE_STATE_H