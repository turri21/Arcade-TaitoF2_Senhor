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

    MemoryEditor scn_main_mem;
    MemoryEditor scn_main_rom;
    MemoryEditor color_ram;
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
