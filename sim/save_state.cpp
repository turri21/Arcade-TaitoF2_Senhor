#include "save_state.h"
#include <stdio.h>

// Get sizes of RAM arrays
static size_t get_scn_ram_size(F2* top) 
{
    return sizeof(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram) / sizeof(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram[0]);
}

static size_t get_pri_ram_size(F2* top) 
{
    return sizeof(top->rootp->F2__DOT__pri_ram_h__DOT__ram) / sizeof(top->rootp->F2__DOT__pri_ram_h__DOT__ram[0]);
}

// Save all RAM state to a file
bool save_ram_state(const char* filename, F2* top, SimSDRAM& cpu_sdram, SimSDRAM& scn_main_sdram) 
{
    FILE* fp = fopen(filename, "wb");
    if (fp == nullptr) 
    {
        printf("Failed to open file for saving RAM state: %s\n", filename);
        return false;
    }
   
    uint32_t ssp = top->ss_saved_ssp;
    fwrite(&ssp, sizeof(ssp), 1, fp);

    // Get RAM sizes
    size_t scn_ram_size = get_scn_ram_size(top);
    size_t pri_ram_size = get_pri_ram_size(top);
    
    // Write the sizes first
    fwrite(&scn_ram_size, sizeof(size_t), 1, fp);
    fwrite(&pri_ram_size, sizeof(size_t), 1, fp);
    
    // Write screen RAM
    fwrite(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram.m_storage, sizeof(uint8_t), scn_ram_size, fp);
    fwrite(top->rootp->F2__DOT__scn_ram_0_lo__DOT__ram.m_storage, sizeof(uint8_t), scn_ram_size, fp);
    
    // Write priority RAM
    fwrite(top->rootp->F2__DOT__pri_ram_h__DOT__ram.m_storage, sizeof(uint8_t), pri_ram_size, fp);
    fwrite(top->rootp->F2__DOT__pri_ram_l__DOT__ram.m_storage, sizeof(uint8_t), pri_ram_size, fp);
    
    // Write SDRAM content
    size_t cpu_sdram_size = cpu_sdram.size;
    size_t scn_main_sdram_size = scn_main_sdram.size;
    
    fwrite(&cpu_sdram_size, sizeof(size_t), 1, fp);
    fwrite(&scn_main_sdram_size, sizeof(size_t), 1, fp);
    
    fwrite(cpu_sdram.data, sizeof(uint8_t), cpu_sdram_size, fp);
    fwrite(scn_main_sdram.data, sizeof(uint8_t), scn_main_sdram_size, fp);
    
    fclose(fp);
    printf("RAM state saved to %s\n", filename);
    return true;
}

// Load RAM state from a file
bool load_ram_state(const char* filename, F2* top, SimSDRAM& cpu_sdram, SimSDRAM& scn_main_sdram) 
{
    FILE* fp = fopen(filename, "rb");
    if (fp == nullptr) 
    {
        printf("Failed to open file for loading RAM state: %s\n", filename);
        return false;
    }
    
    uint32_t ssp;
    fread(&ssp, sizeof(ssp), 1, fp);
    top->ss_restore_ssp = ssp;

    // Read sizes
    size_t scn_ram_size, pri_ram_size;
    if (fread(&scn_ram_size, sizeof(size_t), 1, fp) != 1 ||
        fread(&pri_ram_size, sizeof(size_t), 1, fp) != 1) 
    {
        printf("Error reading RAM sizes\n");
        fclose(fp);
        return false;
    }
    
    // Verify sizes match
    if (scn_ram_size != get_scn_ram_size(top) || pri_ram_size != get_pri_ram_size(top)) 
    {
        printf("RAM size mismatch. File sizes: SCN=%zu, PRI=%zu, Expected: SCN=%zu, PRI=%zu\n",
               scn_ram_size, pri_ram_size, get_scn_ram_size(top), get_pri_ram_size(top));
        fclose(fp);
        return false;
    }
    
    // Read screen RAM
    if (fread(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram.m_storage, sizeof(uint8_t), scn_ram_size, fp) != scn_ram_size ||
        fread(top->rootp->F2__DOT__scn_ram_0_lo__DOT__ram.m_storage, sizeof(uint8_t), scn_ram_size, fp) != scn_ram_size) 
    {
        printf("Error reading screen RAM\n");
        fclose(fp);
        return false;
    }
    
    // Read priority RAM
    if (fread(top->rootp->F2__DOT__pri_ram_h__DOT__ram.m_storage, sizeof(uint8_t), pri_ram_size, fp) != pri_ram_size ||
        fread(top->rootp->F2__DOT__pri_ram_l__DOT__ram.m_storage, sizeof(uint8_t), pri_ram_size, fp) != pri_ram_size) 
    {
        printf("Error reading priority RAM\n");
        fclose(fp);
        return false;
    }
    
    // Read SDRAM sizes
    size_t cpu_sdram_size, scn_main_sdram_size;
    if (fread(&cpu_sdram_size, sizeof(size_t), 1, fp) != 1 ||
        fread(&scn_main_sdram_size, sizeof(size_t), 1, fp) != 1) 
    {
        printf("Error reading SDRAM sizes\n");
        fclose(fp);
        return false;
    }
    
    // Verify sizes match
    if (cpu_sdram_size != cpu_sdram.size || scn_main_sdram_size != scn_main_sdram.size) 
    {
        printf("SDRAM size mismatch\n");
        fclose(fp);
        return false;
    }
    
    // Read SDRAM content
    if (fread(cpu_sdram.data, sizeof(uint8_t), cpu_sdram_size, fp) != cpu_sdram_size ||
        fread(scn_main_sdram.data, sizeof(uint8_t), scn_main_sdram_size, fp) != scn_main_sdram_size) 
    {
        printf("Error reading SDRAM data\n");
        fclose(fp);
        return false;
    }
    
    fclose(fp);
    printf("RAM state loaded from %s\n", filename);
    return true;
}