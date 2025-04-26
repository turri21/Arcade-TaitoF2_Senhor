#include "F2.h"
#include "F2___024root.h"
#include "games.h"
#include "imgui.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include "imgui_wrap.h"
#include "imgui_memory_editor.h"
#include "sim_sdram.h"
#include "sim_video.h"
#include "sim_memory.h"
#include "sim_state.h"
#include "tc0200obj.h"
#include "dis68k/dis68k.h"
#include "games.h"

#include <stdio.h>
#include <SDL.h>
#include <vector>
#include <string>
#include <algorithm>
#include <cstring>

static const uint32_t CPU_ROM_SDR_BASE      = 0x00000000;
static const uint32_t WORK_RAM_SDR_BASE     = 0x00800000;
static const uint32_t SCN0_ROM_SDR_BASE     = 0x00900000;
static const uint32_t ADPCMA_ROM_SDR_BASE   = 0x00b00000;
static const uint32_t ADPCMB_ROM_SDR_BASE   = 0x00d00000;
static const uint32_t OBJ_DATA_DDR_BASE     = 0x00200000;


VerilatedContext *contextp;
F2 *top;
std::unique_ptr<VerilatedFstC> tfp;

SimSDRAM sdram(128 * 1024 * 1024);
SimMemory ddr_memory(8 * 1024 * 1024);
SimVideo video;
SimState* state_manager = nullptr;

#define NUM_SAMPLES (5 * 1024 * 1024)
int16_t audio_samples[NUM_SAMPLES];
int audio_sample_index = 0;

uint64_t total_ticks = 0;

bool trace_active = false;
char trace_filename[64];
int trace_depth = 1;

bool simulation_run = false;
bool simulation_step = false;
int simulation_step_size = 100000;
bool simulation_step_vblank = false;
uint64_t simulation_reset_until = 100;

bool prev_audio_sample = 0;
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
        
        sdram.update_channel_16(top->sdr_cpu_addr, top->sdr_cpu_req, top->sdr_cpu_rw, top->sdr_cpu_be, top->sdr_cpu_data, &top->sdr_cpu_q, &top->sdr_cpu_ack);
        sdram.update_channel_32(top->sdr_scn_main_addr, top->sdr_scn_main_req, 1, 0, 0, &top->sdr_scn_main_q, &top->sdr_scn_main_ack);
        sdram.update_channel_16(top->sdr_audio_addr, top->sdr_audio_req, 1, 0, 0, &top->sdr_audio_q, &top->sdr_audio_ack);
        video.clock(top->ce_pixel != 0, top->hblank != 0, top->vblank != 0, top->red, top->green, top->blue);
        
        // Process memory stream operations
        ddr_memory.clock(top->ddr_addr, top->ddr_wdata, top->ddr_rdata, top->ddr_read, top->ddr_write, top->ddr_busy, top->ddr_read_complete, top->ddr_burstcnt, top->ddr_byteenable);

        /*
        if (top->audio_sample == 1 && prev_audio_sample == false)
        {
            audio_samples[audio_sample_index + 0] = top->audio_left;
            audio_samples[audio_sample_index + 1] = top->audio_right;
            audio_sample_index = (audio_sample_index + 2) % NUM_SAMPLES;
        }

        prev_audio_sample = top->audio_sample == 1;
*/
        contextp->timeInc(1);
        top->clk = 0;

        top->eval();
        if (tfp) tfp->dump(contextp->time());

        contextp->timeInc(1);
        top->clk = 1;

        top->eval();
        if (tfp) tfp->dump(contextp->time());
    }
}

void sim_tick_until(std::function<bool()> until)
{
    while(!until())
    {
        sim_tick(1);
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

void scn_mem_write(ImU8* , size_t off, ImU8 d, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        top->rootp->F2__DOT__scn_ram_0__DOT__ram_l[word_off] = d;
    else
        top->rootp->F2__DOT__scn_ram_0__DOT__ram_h[word_off] = d;
}


ImU8 color_ram_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__color_ram__DOT__ram_l[word_off];
    else
        return top->rootp->F2__DOT__color_ram__DOT__ram_h[word_off];
}

ImU8 obj_ram_read(const ImU8* , size_t off, void*)
{
    size_t word_off = off >> 1;

    if (off & 1)
        return top->rootp->F2__DOT__objram__DOT__ram_l[word_off];
    else
        return top->rootp->F2__DOT__objram__DOT__ram_h[word_off];
}

void load_finalb_test()
{
    FILE *fp = fopen("../testroms/build/finalb_test/finalb/b82_10.ic5", "rb");
    fread((unsigned char *)top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 1, 16 * 1024, fp);
    fclose(fp);

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

void load_finalb()
{
    FILE *fp = fopen("../roms/b82_10.ic5", "rb");
    fread((unsigned char *)top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 1, 64 * 1024, fp);
    fclose(fp);

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

void load_qjinsei()
{
    FILE *fp = fopen("../roms/d48-11", "rb");
    fread((unsigned char *)top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 1, 64 * 1024, fp);
    fclose(fp);

    sdram.load_data("../roms/d48-09", CPU_ROM_SDR_BASE + 1, 2);
    sdram.load_data("../roms/d48-10", CPU_ROM_SDR_BASE + 0, 2);
    sdram.load_data("../roms/d48-03", CPU_ROM_SDR_BASE + 0x100000, 1);

    sdram.load_data("../roms/d48-04", SCN0_ROM_SDR_BASE, 1);
    
    sdram.load_data("../roms/d48-05",  ADPCMA_ROM_SDR_BASE, 1);

    ddr_memory.load_data("../roms/d48-02", OBJ_DATA_DDR_BASE + 0, 4);
    ddr_memory.load_data("../roms/d48-01", OBJ_DATA_DDR_BASE + 1, 4);
    
    top->game = GAME_QJINSEI;
}

void load_dinorex()
{
    FILE *fp = fopen("../roms/d39-12.5", "rb");
    fread((unsigned char *)top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 1, 64 * 1024, fp);
    fclose(fp);

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


int main(int argc, char **argv)
{
    if( !imgui_init() )
    {
        return -1;
    }

    contextp = new VerilatedContext;
    top = new F2{contextp};
    tfp = nullptr;

    load_qjinsei();

    strcpy(trace_filename, "sim.fst");

    top->ss_do_save = 0;
    top->ss_do_restore = 0;
    top->obj_debug_idx = -1;

    top->joystick_p1 = 0;
    top->joystick_p2 = 0;

    // Create state manager
    state_manager = new SimState(top, &ddr_memory, 0, 256 * 1024);

    memset(&ddr_memory.memory[0x100000 + 8192], 0x01, 8192);

    MemoryEditor obj_ram;
    MemoryEditor scn_main_mem;
    MemoryEditor scn_main_rom;
    MemoryEditor color_ram;
    MemoryEditor rom_mem;
    MemoryEditor work_mem;
    MemoryEditor ddr_mem_editor;
    MemoryEditor sound_ram;
    MemoryEditor sound_rom;

    scn_main_mem.ReadFn = scn_mem_read;
    scn_main_mem.WriteFn = scn_mem_write;
    color_ram.ReadFn = color_ram_read;
    obj_ram.ReadFn = obj_ram_read;
    
    video.init(320, 224, imgui_get_renderer());

    Verilated::traceEverOn(true);

    while( imgui_begin_frame() )
    {
        if (simulation_run || simulation_step)
        {
            if (simulation_step_vblank)
            {
                sim_tick_until([&] { return top->vblank == 0; });
                sim_tick_until([&] { return top->vblank != 0; });
            }
            else
            {
                sim_tick(simulation_step_size);
            }
            video.update_texture();
        }
        simulation_step = false;

        if (ImGui::Begin("Simulation Control"))
        {
            ImGui::LabelText("Ticks", "%zu", total_ticks);
            ImGui::Checkbox("Run", &simulation_run);
            if (ImGui::Button("Step"))
            {
                simulation_step = true;
                simulation_run = false;
            }
            ImGui::InputInt("Step Size", &simulation_step_size);
            ImGui::Checkbox("Step Frame", &simulation_step_vblank);
           
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
                             tfp ? ImGuiInputTextFlags_ReadOnly : ImGuiInputTextFlags_None);
            if(ImGui::Button(tfp ? "Stop Tracing###TraceBtn" : "Start Tracing###TraceBtn"))
            {
                if (tfp)
                {
                    tfp->close();
                    tfp.reset();
                }
                else
                {
                    if (strlen(trace_filename) > 0)
                    {
                        tfp = std::make_unique<VerilatedFstC>();
                        top->trace(tfp.get(), trace_depth);
                        tfp->open(trace_filename);
                    }
                }
            }
        }

        ImGui::End();

        if (ImGui::Begin("Audio"))
        {
            if (ImGui::Button("Save Audio"))
            {
                FILE *fout = fopen("audio.raw", "wb");
                fwrite(audio_samples, sizeof(int16_t) * NUM_SAMPLES, 1, fout);
                fclose(fout);
            }

            ImGui::Text("Idx: %u", audio_sample_index);
        }
        ImGui::End();

        if (ImGui::Begin("Memory"))
        {
            if (ImGui::BeginTabBar("memory_tabs"))
            {
                if (ImGui::BeginTabItem("Screen RAM"))
                {
                    scn_main_mem.DrawContents(nullptr, 64 * 1024);
                    ImGui::EndTabItem();
                }

                if (ImGui::BeginTabItem("Color RAM"))
                {
                    color_ram.DrawContents(nullptr, 8 * 1024);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("OBJ RAM"))
                {
                    obj_ram.DrawContents(nullptr, 64 * 1024);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("CPU ROM"))
                {
                    rom_mem.DrawContents(sdram.data + CPU_ROM_SDR_BASE, 1024 * 1024);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("Work RAM"))
                {
                    work_mem.DrawContents(sdram.data + WORK_RAM_SDR_BASE, 64 * 1024);
                    ImGui::EndTabItem();
                }
                
                if (ImGui::BeginTabItem("DDR"))
                {
                    ddr_mem_editor.DrawContents(ddr_memory.memory.data(), ddr_memory.size);
                    ImGui::EndTabItem();
                }

                if (ImGui::BeginTabItem("Sound RAM"))
                {
                    sound_ram.DrawContents(top->rootp->F2__DOT__sound_ram__DOT__ram.m_storage, 16 * 1024);
                    ImGui::EndTabItem();
                }

                if (ImGui::BeginTabItem("Sound ROM"))
                {
                    sound_rom.DrawContents(top->rootp->F2__DOT__sound_rom0__DOT__ram.m_storage, 64 * 1024);
                    ImGui::EndTabItem();
                }

                ImGui::EndTabBar();
            }
        }
        ImGui::End();

        draw_obj_window();
        video.draw();

        ImGui::Begin("68000");
        uint32_t pc = top->rootp->F2__DOT__m68000__DOT__excUnit__DOT__PcL |
            (top->rootp->F2__DOT__m68000__DOT__excUnit__DOT__PcH << 16);
        ImGui::LabelText("PC", "%08X", pc);
        Dis68k dis(sdram.data + pc, sdram.data + pc + 64, pc);
        char optxt[128];
        uint32_t addr;
        dis.disasm(&addr, optxt, sizeof(optxt));
        ImGui::TextUnformatted(optxt);
        ImGui::End();

        imgui_end_frame();
    }
    
    if (tfp)
    {
        tfp->close();
        tfp.reset();
    }

    top->final();

    video.deinit();

    delete state_manager;
    delete top;
    delete contextp;
    return 0;
}
