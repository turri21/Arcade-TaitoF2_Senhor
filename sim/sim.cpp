#include "F2.h"
#include "F2___024root.h"
#include "imgui.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "imgui_wrap.h"
#include "imgui_memory_editor.h"
#include "sim_sdram.h"
#include "sim_video.h"

#include "dis68k/dis68k.h"

#include <stdio.h>
#include <SDL.h>

// TODO

VerilatedContext *contextp;
F2 *top;
VerilatedVcdC *tfp;

SimSDRAM cpu_sdram(128 * 1024 * 1024);
SimSDRAM scn_main_sdram(256 * 1024);
SimVideo video;

uint64_t total_ticks = 0;

bool trace_active = false;
char trace_filename[64];
int trace_depth = 1;

bool simulation_run = false;
bool simulation_step = false;
int simulation_step_size = 10000;
uint64_t simulation_reset_until = 100;

// Get sizes of RAM arrays
size_t get_scn_ram_size() 
{
    return sizeof(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram) / sizeof(top->rootp->F2__DOT__scn_ram_0_up__DOT__ram[0]);
}

size_t get_pri_ram_size() 
{
    return sizeof(top->rootp->F2__DOT__pri_ram_h__DOT__ram) / sizeof(top->rootp->F2__DOT__pri_ram_h__DOT__ram[0]);
}

// Save all RAM state to a file
bool save_ram_state(const char* filename) 
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
    size_t scn_ram_size = get_scn_ram_size();
    size_t pri_ram_size = get_pri_ram_size();
    
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
bool load_ram_state(const char* filename) 
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
    if (scn_ram_size != get_scn_ram_size() || pri_ram_size != get_pri_ram_size()) 
    {
        printf("RAM size mismatch. File sizes: SCN=%zu, PRI=%zu, Expected: SCN=%zu, PRI=%zu\n",
               scn_ram_size, pri_ram_size, get_scn_ram_size(), get_pri_ram_size());
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


void tick(int count = 1)
{
    for( int i = 0; i < count; i++ )
    {
        total_ticks++;

        if (total_ticks < simulation_reset_until)
        {
            top->reset = 1;
        }
        else
        {
            top->reset = 0;
        }
        
        cpu_sdram.update_channel_16(top->sdr_cpu_addr, top->sdr_cpu_req, top->sdr_cpu_rw, top->sdr_cpu_be, top->sdr_cpu_data, &top->sdr_cpu_q, &top->sdr_cpu_ack);
        scn_main_sdram.update_channel_32(top->sdr_scn_main_addr, top->sdr_scn_main_req, 1, 15, 0, &top->sdr_scn_main_q, &top->sdr_scn_main_ack);
        video.clock(top->ce_pixel != 0, top->hsync != 0, top->vsync != 0, top->red, top->green, top->blue);

        if (top->ss_do_save && top->ss_state_out == 3) // SST_SAVE_PAUSED
        {
            // Save all RAM state to file
            save_ram_state("ram_state.bin");
            top->ss_do_save = 0;
        }

        // Check for restore request before processing
        if (top->ss_do_restore && top->ss_state_out == 4)
        {
            if (load_ram_state("ram_state.bin"))
            {
                printf("RAM state restored\n");
            }
            else
            {
                printf("Failed to restore RAM state\n");
            }
            top->ss_do_restore = 0;
        }


        contextp->timeInc(1);
        top->clk = 0;

        top->eval();
        if (trace_active) tfp->dump(contextp->time());

        contextp->timeInc(1);
        top->clk = 1;

        top->eval();
        if (trace_active) tfp->dump(contextp->time());
    }
}

ImU8 scn_mem_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__scn_ram_0_lo__DOT__ram[word_off];
    else
        return top->rootp->F2__DOT__scn_ram_0_up__DOT__ram[word_off];
}

ImU8 color_ram_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__pri_ram_l__DOT__ram[word_off];
    else
        return top->rootp->F2__DOT__pri_ram_h__DOT__ram[word_off];
}


int main(int argc, char **argv)
{
    if( !imgui_init() )
    {
        return -1;
    }

    FILE *fp = fopen("cpu.bin", "rb");
    fread(cpu_sdram.data, 1, 128 * 1024, fp);
    fclose(fp);

    cpu_sdram.load_data("b82-09.10", 0, 2);
    cpu_sdram.load_data("b82-17.11", 1, 2);

    scn_main_sdram.load_data("b82-07.18", 0, 2);
    scn_main_sdram.load_data("b82-06.19", 1, 2);

    strcpy(trace_filename, "sim.vcd");

    contextp = new VerilatedContext;
    top = new F2{contextp};
    tfp = new VerilatedVcdC;

    top->ss_do_save = 0;
    top->ss_do_restore = 0;

    MemoryEditor scn_main_mem;
    MemoryEditor scn_main_rom;
    MemoryEditor color_ram;
    MemoryEditor rom_mem;
    MemoryEditor work_mem;

    scn_main_mem.ReadFn = scn_mem_read;
    color_ram.ReadFn = color_ram_read;

    video.init(320, 200, imgui_get_renderer());

    Verilated::traceEverOn(true);

    while( imgui_begin_frame() )
    {
        if (simulation_run || simulation_step)
        {
            tick(simulation_step_size);
            video.update_texture();
        }
        simulation_step = false;

        ImGui::Begin("Simulation Control");

        ImGui::LabelText("Ticks", "%llu", total_ticks);
        ImGui::Checkbox("Run", &simulation_run);
        if (ImGui::Button("Step"))
        {
            simulation_step = true;
            simulation_run = false;
        }
        ImGui::InputInt("Step Size", &simulation_step_size);
       
        if (ImGui::Button("Reset"))
        {
            simulation_reset_until = total_ticks + 100;
        }

        ImGui::Separator();
        
        // RAM state save/load controls
        if (ImGui::Button("Save RAM State"))
        {
            if (save_ram_state("ram_state.bin"))
            {
                printf("RAM state saved manually\n");
            }
            else
            {
                printf("Failed to save RAM state\n");
            }
        }
        
        ImGui::SameLine();
        
        if (ImGui::Button("Load RAM State"))
        {
            if (load_ram_state("ram_state.bin"))
            {
                printf("RAM state loaded manually\n");
            }
            else
            {
                printf("Failed to load RAM state\n");
            }
        }

        ImGui::Separator();

        ImGui::PushItemWidth(100);
        if(ImGui::InputInt("Trace Depth", &trace_depth, 1, 10,
                           trace_active ? ImGuiInputTextFlags_ReadOnly : ImGuiInputTextFlags_None))
        {
            trace_depth = std::min(std::max(trace_depth, 1), 99);
        }
        ImGui::PopItemWidth();
        ImGui::InputText("Filename", trace_filename, sizeof(trace_filename),
                         trace_active ? ImGuiInputTextFlags_ReadOnly : ImGuiInputTextFlags_None);
        if(ImGui::Button(trace_active ? "Stop Tracing###TraceBtn" : "Start Tracing###TraceBtn"))
        {
            if (trace_active)
            {
                tfp->close();
                trace_active = false;
            }
            else
            {
                if (strlen(trace_filename) > 0)
                {
                    top->trace(tfp, trace_depth);
                    tfp->open(trace_filename);
                    trace_active = tfp->isOpen();
                }
            }
        }


        ImGui::Separator();
        if (ImGui::Button("Save"))
        {
            top->ss_do_save = 1;
        }
        ImGui::SameLine();
        if (ImGui::Button("Restore"))
        {
            top->ss_do_restore = 1;
        }
        ImGui::Text("ss_state: %d", top->ss_state_out);
        ImGui::Text("ss_save_ssp: %08x", top->ss_saved_ssp);

        ImGui::End();

        scn_main_mem.DrawWindow("Screen Mem", nullptr, 64 * 1024);
        scn_main_rom.DrawWindow("Screen ROM", scn_main_sdram.data, 256 * 1024);
        color_ram.DrawWindow("Color RAM", nullptr, 8 * 1024);
        rom_mem.DrawWindow("ROM", cpu_sdram.data, 1024 * 1024);
        work_mem.DrawWindow("Work", cpu_sdram.data + (1024 * 1024), 64 * 1024);
        video.draw();

        ImGui::Begin("68000");
        uint32_t pc = top->rootp->F2__DOT__m68000__DOT__PC;
        ImGui::LabelText("PC", "%08X", pc);
        Dis68k dis(cpu_sdram.data + pc, cpu_sdram.data + pc + 64, pc);
        char optxt[128];
        uint32_t addr;
        dis.disasm(&addr, optxt, sizeof(optxt));
        ImGui::TextUnformatted(optxt);
        ImGui::End();

        imgui_end_frame();
    }
    
    if (trace_active) tfp->close();

    top->final();

    video.deinit();

    delete top;
    delete contextp;
    return 0;
}
