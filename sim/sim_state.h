#pragma once

#include <vector>
#include <string>

// Forward declarations
class F2;
class SimMemory;

class SimState {
public:
    SimState(F2* top, SimMemory* memory);
    
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
    SimMemory* m_memory;
};