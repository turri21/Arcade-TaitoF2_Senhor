#ifndef SIM_DDR_H
#define SIM_DDR_H

#include <cstdint>
#include <cstdio>
#include <vector>
#include <string>

// Class to simulate a 64-bit wide memory device
class SimDDR
{
public:
    SimDDR(size_t size_bytes)
    {
        // Initialize memory with size rounded up to multiple of 8 bytes
        size = (size_bytes + 7) & ~7;  // Round up to multiple of 8
        memory.resize(size, 0);
        
        // Reset state
        read_complete = false;
        busy = false;
        busy_counter = 0;
        burst_counter = 0;
        burst_size = 0;
    }
    
    // Load data from a file into memory at specified offset with optional stride
    bool load_data(const std::string& filename, uint32_t offset = 0, uint32_t stride = 1)
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
        
        // Check if the file will fit in memory with the stride
        if (offset + (file_size - 1) * stride + 1 > size)
        {
            printf("File too large to fit in memory at specified offset with stride %u\n", stride);
            fclose(fp);
            return false;
        }
        
        if (stride == 1)
        {
            // Fast path for stride=1 (contiguous data)
            size_t bytes_read = fread(&memory[offset], 1, file_size, fp);
            
            if (bytes_read != file_size)
            {
                printf("Failed to read entire file: %s\n", filename.c_str());
                fclose(fp);
                return false;
            }
        }
        else
        {
            // Read byte by byte with stride
            std::vector<uint8_t> buffer(file_size);
            size_t bytes_read = fread(buffer.data(), 1, file_size, fp);
            
            if (bytes_read != file_size)
            {
                printf("Failed to read entire file: %s\n", filename.c_str());
                fclose(fp);
                return false;
            }
            
            // Copy to memory with stride
            for (size_t i = 0; i < bytes_read; i++)
            {
                memory[offset + i * stride] = buffer[i];
            }
        }
        
        fclose(fp);
        printf("Loaded %zu bytes from %s at offset 0x%08X with stride %u\n", 
               file_size, filename.c_str(), offset, stride);
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
        uint8_t& read_complete_out,
        uint8_t burstcnt = 1,
        uint8_t byteenable = 0xFF
    )
    {
        // Update busy status - simulate memory with occasional busy cycles
        if (busy)
        {
            busy_counter--;
            if (busy_counter == 0)
            {
                // If we're completing a read operation
                if (pending_read)
                {
                    read_complete = true;
                    
                    // Prepare read data from the current burst address
                    uint32_t current_burst_addr = (pending_addr & ~0x7) + (burst_size - burst_counter) * 8;
                    if (current_burst_addr + 8 <= size)
                    {
                        // Assemble 64-bit word from memory
                        pending_rdata = 0;
                        for (int i = 0; i < 8; i++)
                        {
                            pending_rdata |= static_cast<uint64_t>(memory[current_burst_addr + i]) << (i * 8);
                        }
                    }
                    else
                    {
                        pending_rdata = 0;
                    }
                    
                    // Decrement burst counter
                    burst_counter--;
                    
                    // If burst is complete, clear pending read flag
                    if (burst_counter == 0)
                    {
                        pending_read = false;
                        busy = false;
                    }
                    else
                    {
                        // Otherwise, set up for next word in burst
                        busy_counter = read_latency;
                    }
                }
                else if (burst_counter > 0)
                {
                    // Writing in burst mode, move to next word
                    burst_counter--;
                    
                    if (burst_counter == 0)
                    {
                        busy = false;
                    }
                    else
                    {
                        // Ready for next write in the burst
                        busy = false;
                        busy_counter = 0;
                    }
                }
                else
                {
                    // Normal operation completion
                    busy = false;
                }
            }
        }
        else
        {
            if (read && !pending_read)
            {
                // Start new read operation in burst mode
                busy = true;
                busy_counter = read_latency;
                pending_read = true;
                pending_addr = addr;
                read_complete = false;
                burst_counter = burstcnt;
                burst_size = burstcnt;
            }
            else if (write && (burst_counter == 0 || !busy))
            {
                // Handle start of burst write or individual word in burst
                uint32_t current_burst_addr;
                
                if (burst_counter == 0)
                {
                    // Starting a new burst write
                    pending_addr = addr;
                    burst_counter = burstcnt - 1; // First word is written now
                    burst_size = burstcnt;
                    current_burst_addr = addr & ~0x7;
                }
                else
                {
                    // Writing next word in an existing burst
                    current_burst_addr = (pending_addr & ~0x7) + (burst_size - burst_counter) * 8;
                    burst_counter--;
                }
                
                // Perform write operation
                if (current_burst_addr + 8 <= size)
                {
                    // Write 64-bit word to memory, respecting byte enable signal
                    for (int i = 0; i < 8; i++)
                    {
                        // Only write byte if corresponding bit in byteenable is set
                        if (byteenable & (1 << i))
                        {
                            memory[current_burst_addr + i] = (wdata >> (i * 8)) & 0xFF;
                        }
                    }
                }
                
                // If this is the last word in the burst or not a burst operation
                if (burst_counter == 0)
                {
                    // Simulate write latency
                    // TODO - busy usage doesn't match DE-10
                    //busy = true;
                    //busy_counter = write_latency;
                }
            }
        }
        
        // Set outputs
        busy_out = 0; // busy ? 1 : 0; // TODO - busy_out doesn't match DE-10 DDR
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
    
    // Burst operation state
    uint8_t burst_counter;  // Counter for remaining words in burst
    uint8_t burst_size;     // Total size of current burst
};

extern SimDDR ddr_memory;

#endif // SIM_DDR_H
