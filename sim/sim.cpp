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
#include "sim_state.h"
#include "dis68k/dis68k.h"

#include <stdio.h>
#include <SDL.h>
#include <vector>
#include <string>
#include <algorithm>
#include <cstring>

// TODO

VerilatedContext *contextp;
F2 *top;
VerilatedVcdC *tfp;

SimSDRAM cpu_sdram(128 * 1024 * 1024);
SimSDRAM scn_main_sdram(256 * 1024);
SimMemory ddr_memory(256 * 1024);
SimVideo video;
SimState* state_manager = nullptr;

uint64_t total_ticks = 0;

bool trace_active = false;
char trace_filename[64];
int trace_depth = 1;

bool simulation_run = false;
bool simulation_step = false;
int simulation_step_size = 100000;
uint64_t simulation_reset_until = 100;

void sim_tick(int count = 1)
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
        ddr_memory.clock(top->ddr_addr, top->ddr_wdata, top->ddr_rdata, top->ddr_read, top->ddr_write, top->ddr_busy, top->ddr_read_complete, top->ddr_burstcnt, top->ddr_byteenable);

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
        return top->rootp->F2__DOT__scn_ram_0__DOT__ram_l[word_off];
    else
        return top->rootp->F2__DOT__scn_ram_0__DOT__ram_h[word_off];
}

ImU8 color_ram_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__pri_ram__DOT__ram_l[word_off];
    else
        return top->rootp->F2__DOT__pri_ram__DOT__ram_h[word_off];
}

ImU8 obj_ram_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__objram__DOT__ram_l[word_off];
    else
        return top->rootp->F2__DOT__objram__DOT__ram_h[word_off];
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
    
    // Create state manager
    state_manager = new SimState(top, &ddr_memory);

    MemoryEditor obj_ram;
    MemoryEditor scn_main_mem;
    MemoryEditor scn_main_rom;
    MemoryEditor color_ram;
    MemoryEditor rom_mem;
    MemoryEditor work_mem;
    MemoryEditor ddr_mem_editor;

    scn_main_mem.ReadFn = scn_mem_read;
    color_ram.ReadFn = color_ram_read;
    obj_ram.ReadFn = obj_ram_read;
    
    video.init(320, 224, imgui_get_renderer());

    Verilated::traceEverOn(true);

    while( imgui_begin_frame() )
    {
        if (simulation_run || simulation_step || (force_ticks > 0))
        {
            sim_tick(force_ticks > 0 ? force_ticks : simulation_step_size);
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
        
        // Save/Restore State Section
        ImGui::Text("Save/Restore State");
        
        static char state_filename[256] = "state.f2state";
        ImGui::InputText("State Filename", state_filename, sizeof(state_filename));
        
        static std::vector<std::string> state_files = state_manager->get_f2state_files();
        static int selected_state_file = -1;
        
        if (ImGui::Button("Save State"))
        {
            // Ensure filename has .f2state extension
            std::string filename = state_filename;
            if (filename.size() < 8 || filename.substr(filename.size() - 8) != ".f2state")
            {
                filename += ".f2state";
                strncpy(state_filename, filename.c_str(), sizeof(state_filename) - 1);
                state_filename[sizeof(state_filename) - 1] = '\0';
            }
            
            if (state_manager->save_state(state_filename))
            {
                // Update file list after successfully saving
                state_files = state_manager->get_f2state_files();
                // Try to select the newly saved file
                for (size_t i = 0; i < state_files.size(); i++)
                {
                    if (state_files[i] == state_filename)
                    {
                        selected_state_file = i;
                        break;
                    }
                }
            }
        }
        
        // Show list of state files
        if (state_files.size() > 0)
        {
            ImGui::Text("Available State Files:");
            ImGui::BeginChild("StateFiles", ImVec2(0, 100), true);
            for (size_t i = 0; i < state_files.size(); i++)
            {
                if (ImGui::Selectable(state_files[i].c_str(), selected_state_file == (int)i, ImGuiSelectableFlags_AllowDoubleClick))
                {
                    selected_state_file = (int)i;
                    if (ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left))
                    {
                        state_manager->restore_state(state_files[i].c_str());
                    }
                }
            }
            ImGui::EndChild();
        }
        else
        {
            ImGui::Text("No state files found (*.f2state)");
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

        ImGui::End();

        scn_main_mem.DrawWindow("Screen Mem", nullptr, 64 * 1024);
        scn_main_rom.DrawWindow("Screen ROM", scn_main_sdram.data, 256 * 1024);
        color_ram.DrawWindow("Color RAM", nullptr, 8 * 1024);
        obj_ram.DrawWindow("OBJ RAM", nullptr, 64 * 1024);
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

    delete state_manager;
    delete top;
    delete contextp;
    return 0;
}
