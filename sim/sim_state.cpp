#include "sim_state.h"
#include "F2.h"
#include "sim_ddr.h"
#include "sim.h"

#include <dirent.h>
#include <algorithm>
#include <cstring>

extern void sim_tick(int count);

SimState::SimState(F2* top, SimDDR* memory, int offset, int size) 
    : m_top(top), m_memory(memory), m_offset(offset), m_size(size)
{
}

bool SimState::save_state(const char* filename)
{
    m_top->ss_index = 0;
    m_top->ss_do_save = 1;
    sim_tick_until([&]{ return m_top->ss_state_out != 0; });

    m_top->ss_do_save = 0;
    sim_tick_until([&]{ return m_top->ss_state_out == 0; });

    m_memory->save_data(filename, m_offset, m_size);

    return true;
}

bool SimState::restore_state(const char* filename)
{
    m_memory->load_data(filename, m_offset, 1); // Pass stride=1 explicitly

    m_top->ss_index = 0;
    m_top->ss_do_restore = 1;
    sim_tick_until([&]{ return m_top->ss_state_out != 0; });
    
    m_top->ss_do_restore = 0;
    sim_tick_until([&]{ return m_top->ss_state_out == 0; });

    return true;
}

std::vector<std::string> SimState::get_f2state_files()
{
    std::vector<std::string> files;
    DIR* dir;
    struct dirent* ent;
    
    if ((dir = opendir(".")) != NULL)
    {
        while ((ent = readdir(dir)) != NULL)
        {
            std::string filename = ent->d_name;
            // Check if filename ends with .f2state
            if (filename.size() > 8 && 
                filename.substr(filename.size() - 8) == ".f2state")
            {
                files.push_back(filename);
            }
        }
        closedir(dir);
    }
    
    // Sort file names
    std::sort(files.begin(), files.end());
    
    return files;
}
