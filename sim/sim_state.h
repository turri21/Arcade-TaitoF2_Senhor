#pragma once

#include <vector>
#include <string>

// Forward declarations
class F2;
class SimDDR;

class SimState {
public:
    SimState(F2* top, SimDDR* memory, int offset, int size);
    
    // Save state to the specified file
    bool save_state(const char* filename);
    
    // Restore state from the specified file
    bool restore_state(const char* filename);
    
    // Get list of all available state files in current directory
    std::vector<std::string> get_f2state_files();
    
    // Tick the simulation for the given number of cycles
    void tick(int count);

private:
    F2* m_top;
    SimDDR* m_memory;
    int m_offset;
    int m_size;
};
