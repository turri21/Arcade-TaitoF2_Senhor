#include "F2.h"
#include "F2___024root.h"
#include "imgui.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "imgui_wrap.h"
#include "imgui_memory_editor.h"
#include "sim_sdram.h"
#include "sim_video.h"
#include "sim_memory.h"
#include "save_state.h"

#include "dis68k/dis68k.h"

#include <stdio.h>
#include <SDL.h>

// TODO

VerilatedContext *contextp;
F2 *top;
VerilatedVcdC *tfp;

SimSDRAM cpu_sdram(128 * 1024 * 1024);
SimSDRAM scn_main_sdram(256 * 1024);
SimMemory ddr_memory(256 * 1024);
SimVideo video;

uint64_t total_ticks = 0;

bool trace_active = false;
char trace_filename[64];
int trace_depth = 1;

bool simulation_run = false;
bool simulation_step = false;
int simulation_step_size = 10000;
uint64_t simulation_reset_until = 100;



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
        
        // Process memory stream operations
        ddr_memory.clock(top->mem_addr, top->mem_wdata, top->mem_rdata, top->mem_read, top->mem_write, top->mem_busy, top->mem_read_complete);

        if (top->ss_do_save && top->ss_state_out == 3) // SST_SAVE_PAUSED
        {
            // Save all RAM state to file
            save_ram_state("ram_state.bin", top, cpu_sdram, scn_main_sdram);
            top->ss_do_save = 0;
        }

        // Check for restore request before processing
        if (top->ss_do_restore && top->ss_state_out == 4)
        {
            if (load_ram_state("ram_state.bin", top, cpu_sdram, scn_main_sdram))
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

    top->ss_save_test = 0;
    top->ss_restore_test = 0;
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
    int force_ticks = 0;

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
    top->ss_save_test = 0;
    top->ss_restore_test = 0;

    MemoryEditor scn_main_mem_lo;
    MemoryEditor scn_main_mem_hi;
    MemoryEditor scn_main_mem;
    MemoryEditor scn_main_rom;
    MemoryEditor color_ram;
    MemoryEditor rom_mem;
    MemoryEditor work_mem;
    MemoryEditor ddr_mem_editor;

    scn_main_mem.ReadFn = scn_mem_read;
    color_ram.ReadFn = color_ram_read;
    
    video.init(320, 200, imgui_get_renderer());

    Verilated::traceEverOn(true);

    while( imgui_begin_frame() )
    {
        if (simulation_run || simulation_step || (force_ticks > 0))
        {
            tick(force_ticks > 0 ? force_ticks : simulation_step_size);
            video.update_texture();
            force_ticks = 0;
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
            if (save_ram_state("ram_state.bin", top, cpu_sdram, scn_main_sdram))
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
            if (load_ram_state("ram_state.bin", top, cpu_sdram, scn_main_sdram))
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
        if (ImGui::Button("Save Test"))
        {
            top->ss_save_test = 1;
            force_ticks = 100;
        }
        ImGui::SameLine();
        if (ImGui::Button("Restore Test"))
        {
            top->ss_restore_test = 1;
            force_ticks = 100;
        }
        ImGui::Text("ss_state: %d", top->ss_state_out);
        ImGui::Text("ss_save_ssp: %08x", top->ss_saved_ssp);

        ImGui::End();

        scn_main_mem_lo.DrawWindow("Screen Mem Lo", (uint8_t *)&top->rootp->F2__DOT__scn_ram_0_lo__DOT__ram[0], 32 * 1024);
        scn_main_mem_hi.DrawWindow("Screen Mem Hi", (uint8_t *)&top->rootp->F2__DOT__scn_ram_0_up__DOT__ram[0], 32 * 1024);
        scn_main_mem.DrawWindow("Screen Mem", nullptr, 64 * 1024);
        scn_main_rom.DrawWindow("Screen ROM", scn_main_sdram.data, 256 * 1024);
        color_ram.DrawWindow("Color RAM", nullptr, 8 * 1024);
        rom_mem.DrawWindow("ROM", cpu_sdram.data, 1024 * 1024);
        work_mem.DrawWindow("Work", cpu_sdram.data + (1024 * 1024), 64 * 1024);
        ddr_mem_editor.DrawWindow("DDR", ddr_memory.memory.data(), ddr_memory.size);
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
