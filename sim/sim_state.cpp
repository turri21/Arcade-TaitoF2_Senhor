#include "sim_state.h"
#include "F2.h"
#include "sim_memory.h"

#include <dirent.h>
#include <algorithm>
#include <cstring>

extern void sim_tick(int count);

SimState::SimState(F2* top, SimMemory* memory) 
    : m_top(top), m_memory(memory)
{
}

bool SimState::save_state(const char* filename)
{
    m_top->ss_do_save = 1;
    while (m_top->ss_state_out == 0)
    {
        tick(1000);
    }
    m_top->ss_do_save = 0;
    while (m_top->ss_state_out != 0)
    {
        tick(1000);
    }

    m_memory->save_data(filename);

    return true;
}

bool SimState::restore_state(const char* filename)
{
    m_memory->load_data(filename);

    m_top->ss_do_restore = 1;
    while (m_top->ss_state_out == 0)
    {
        tick(1000);
    }
    m_top->ss_do_restore = 0;
    while (m_top->ss_state_out != 0)
    {
        tick(1000);
    }

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

// Note: This implementation is a stub - the actual implementation
// would need to call the simulation's tick function
void SimState::tick(int count)
{
    sim_tick(count);
}
