#include "F2.h"
#include "F2___024root.h"
#include "imgui.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "imgui_wrap.h"
#include "imgui_memory_editor.h"
#include "sim_sdram.h"

#include <stdio.h>
#include <SDL.h>

// TODO
// rom and ram regions - done
// rom loading - done
// vblank - done, rough
// comms
// display vram

VerilatedContext *contextp;
F2 *top;
VerilatedVcdC *tfp;

constexpr size_t MEM_SIZE = 0x100000;

uint8_t memory[MEM_SIZE];
uint32_t rom_mask;

constexpr uint32_t MT_ROM =       0x00000001;
constexpr uint32_t MT_WRITEABLE = 0x00000002;
constexpr uint32_t MT_WORKRAM =   0x00000004;
constexpr uint32_t MT_VRAM =      0x00000008;
constexpr uint32_t MT_PALRAM =    0x00000010;

uint32_t map_addr(uint32_t logical_addr, uint32_t *memtype)
{
    logical_addr = logical_addr & 0xfffff;
    if ((logical_addr & 0xf0000) == 0xa0000)
    {
        *memtype = MT_WRITEABLE | MT_WORKRAM;
        return logical_addr;
    }

    if ((logical_addr & 0xf0000) == 0xd0000)
    {
        *memtype = MT_WRITEABLE | MT_VRAM;
        return logical_addr;
    }

    if ((logical_addr & 0xf0000) == 0xe0000)
    {
        *memtype = MT_WRITEABLE | MT_PALRAM;
        return logical_addr & 0xe03ff;
    }

    *memtype = MT_ROM;
    return logical_addr & rom_mask;
}

uint16_t read_mem(uint32_t addr, bool ube)
{
    uint32_t memtype;
    uint32_t aligned_addr = map_addr(addr & ~1, &memtype);
    return memory[aligned_addr] | (memory[aligned_addr + 1] << 8);
}

void write_mem(uint32_t addr, bool ube, uint16_t dout)
{
    uint32_t memtype;
    addr = map_addr(addr, &memtype);
    if (memtype & MT_WRITEABLE)
    {
        if ((addr & 1) && ube)
        {
            memory[addr] = dout >> 8;
        }
        else if (((addr & 1) == 0) && !ube)
        {
            memory[addr] = dout & 0xff;
        }
        else
        {
            memory[addr] = dout & 0xff;
            memory[addr + 1] = dout >> 8;
        }
    }
}

MemoryEditor scn_main_mem;

SimSDRAM sdram(128 * 1024 * 1024);

uint64_t total_ticks = 0;

bool trace_active = false;
char trace_filename[64];
int trace_depth = 1;

bool simulation_run = false;
bool simulation_step = false;
int simulation_step_size = 1000;
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

        sdram.update_channel(top->sdr_cpu_addr, top->sdr_cpu_req, top->sdr_cpu_rw, top->sdr_cpu_be, top->sdr_cpu_data, &top->sdr_cpu_q, &top->sdr_cpu_ack);

        contextp->timeInc(1);
        top->clk = 0;

        top->eval();
        if (trace_active) tfp->dump(contextp->time());
        //print_trace(top->rootp->V33);

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

int main(int argc, char **argv)
{
    if( !imgui_init() )
    {
        return -1;
    }

    FILE *fp = fopen("cpu.bin", "rb");
    fread(sdram.data, 1, 128 * 1024, fp);
    fclose(fp);

    strcpy(trace_filename, "sim.vcd");

    contextp = new VerilatedContext;
    top = new F2{contextp};
    tfp = new VerilatedVcdC;

    scn_main_mem.ReadFn = scn_mem_read;

    Verilated::traceEverOn(true);

    while( imgui_begin_frame() )
    {
        if (simulation_run || simulation_step)
        {
            tick(simulation_step_size);
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

        imgui_end_frame();
    }
    
    if (trace_active) tfp->close();

    top->final();

    delete top;
    delete contextp;
    return 0;
}
