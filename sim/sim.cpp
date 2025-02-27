#include "F2.h"
#include "F2___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "imgui_wrap.h"

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

uint32_t total_ticks = 0;

void tick(int count = 1)
{
    for( int i = 0; i < count; i++ )
    {
        total_ticks++;

        contextp->timeInc(1);
        top->clk = 0;

        top->eval();
        tfp->dump(contextp->time());
        //print_trace(top->rootp->V33);

        contextp->timeInc(1);
        top->clk = 1;

        top->eval();
        tfp->dump(contextp->time());
    }
}

int main(int argc, char **argv)
{
    if( !imgui_init() )
    {
        return -1;
    }

    contextp = new VerilatedContext;
    top = new F2{contextp};
    tfp = new VerilatedVcdC;

    Verilated::traceEverOn(true);
    top->trace(tfp, 1);

    tfp->open("sim.vcd");

    top->reset = 1;
    tick(10);
    top->reset = 0;
    tick(100);

    if (tfp->isOpen()) tfp->close();
    top->final();

    while( imgui_begin_frame() )
    {
        ImGui::Begin("Hello there");
        ImGui::End();
        imgui_end_frame();
    }

    delete top;
    delete contextp;
    return 0;
}
