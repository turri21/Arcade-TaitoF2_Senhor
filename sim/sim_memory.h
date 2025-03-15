#ifndef SIM_MEMORY_H
#define SIM_MEMORY_H

#include <cstdint>
#include <cstdio>
#include <vector>
#include <string>

// Class to simulate a 64-bit wide memory device
class SimMemory
{
public:
    SimMemory(size_t size_bytes)
    {
        // Initialize memory with size rounded up to multiple of 8 bytes
        size = (size_bytes + 7) & ~7;  // Round up to multiple of 8
        memory.resize(size, 0);
        
        // Reset state
        read_complete = false;
        busy = false;
        busy_counter = 0;
    }
    
    // Load data from a file into memory at specified offset
    bool load_data(const std::string& filename, uint32_t offset = 0)
    {
        FILE* fp = fopen(filename.c_str(), "rb");
        if (!fp)
        {
            printf("Failed to open file for loading memory: %s\n", filename.c_str());
            return false;
        }
        
        // Get file size
        fseek(fp, 0, SEEK_END);
        size_t file_size = ftell(fp);
        fseek(fp, 0, SEEK_SET);
        
        // Check if the file will fit in memory
        if (offset + file_size > size)
        {
            printf("File too large to fit in memory at specified offset\n");
            fclose(fp);
            return false;
        }
        
        // Read file into memory
        size_t bytes_read = fread(&memory[offset], 1, file_size, fp);
        fclose(fp);
        
        if (bytes_read != file_size)
        {
            printf("Failed to read entire file: %s\n", filename.c_str());
            return false;
        }
        
        printf("Loaded %zu bytes from %s at offset 0x%08X\n", bytes_read, filename.c_str(), offset);
        return true;
    }
    
    // Save memory data to a file
    bool save_data(const std::string& filename, uint32_t offset = 0, size_t length = 0)
    {
        if (length == 0)
            length = size - offset;
            
        if (offset + length > size)
        {
            printf("Invalid offset/length for memory save\n");
            return false;
        }
        
        FILE* fp = fopen(filename.c_str(), "wb");
        if (!fp)
        {
            printf("Failed to open file for saving memory: %s\n", filename.c_str());
            return false;
        }
        
        size_t bytes_written = fwrite(&memory[offset], 1, length, fp);
        fclose(fp);
        
        if (bytes_written != length)
        {
            printf("Failed to write entire data to file: %s\n", filename.c_str());
            return false;
        }
        
        printf("Saved %zu bytes to %s from offset 0x%08X\n", bytes_written, filename.c_str(), offset);
        return true;
    }
    
    // Clock the memory, processing read/write operations
    void clock(
        uint32_t addr,
        const uint64_t& wdata,
        uint64_t& rdata,
        bool read,
        bool write,
        uint8_t& busy_out,
        uint8_t& read_complete_out
    )
    {
        // Update busy status - simulate memory with occasional busy cycles
        if (busy)
        {
            busy_counter--;
            if (busy_counter == 0)
            {
                busy = false;
                
                // If we're completing a read operation
                if (pending_read)
                {
                    read_complete = true;
                    pending_read = false;
                    
                    // Prepare read data
                    uint32_t aligned_addr = pending_addr & ~0x7; // Align to 8-byte boundary
                    if (aligned_addr + 8 <= size)
                    {
                        // Assemble 64-bit word from memory
                        pending_rdata = 0;
                        for (int i = 0; i < 8; i++)
                        {
                            pending_rdata |= static_cast<uint64_t>(memory[aligned_addr + i]) << (i * 8);
                        }
                    }
                    else
                    {
                        pending_rdata = 0;
                    }
                }
            }
        }
        
        // Process new memory operations
        if (!busy)
        {
            if (read && !pending_read)
            {
                // Start new read operation
                busy = true;
                busy_counter = read_latency;
                pending_read = true;
                pending_addr = addr;
                read_complete = false;
            }
            else if (write)
            {
                // Perform write operation
                uint32_t aligned_addr = addr & ~0x7; // Align to 8-byte boundary
                
                if (aligned_addr + 8 <= size)
                {
                    // Write 64-bit word to memory
                    for (int i = 0; i < 8; i++)
                    {
                        memory[aligned_addr + i] = (wdata >> (i * 8)) & 0xFF;
                    }
                }
                
                // Simulate write latency
                busy = true;
                busy_counter = write_latency;
            }
        }
        
        // Set outputs
        busy_out = busy ? 1 : 0;
        read_complete_out = read_complete ? 1 : 0;
        
        if (read_complete)
        {
            rdata = pending_rdata;
            read_complete = false; // Clear completion flag after it's been seen
        }
    }
    
    // Direct access to memory for debugging/testing
    uint8_t& operator[](size_t index)
    {
        return memory[index];
    }
    
    // Memory parameters
    void set_read_latency(int cycles) { read_latency = cycles; }
    void set_write_latency(int cycles) { write_latency = cycles; }
    
    std::vector<uint8_t> memory;
    size_t size;

private:
   
    // Memory timing parameters
    int read_latency = 2;  // Default read latency in clock cycles
    int write_latency = 1; // Default write latency in clock cycles
    
    // Internal state
    bool busy;
    int busy_counter;
    bool read_complete;
    bool pending_read;
    uint32_t pending_addr;
    uint64_t pending_rdata;
};

#endif // SIM_MEMORY_H
