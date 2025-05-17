#include <cstdio>
#if !defined (SIM_SDRAM_H)
#define SIM_SDRAM_H 1

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "file_search.h"

class SimSDRAM
{
public:
    SimSDRAM(uint32_t sz)
    {
        size = sz;
        mask = sz - 1;
        data = new uint8_t [size];
        delay = 0;
    }

    ~SimSDRAM()
    {
        delete [] data;
        data = nullptr;
    }

    void update_channel_16(uint32_t addr, uint8_t req, uint8_t rw, uint8_t be, uint16_t din, uint16_t *dout, uint8_t *ack)
    {
        if (req == *ack) return;

        delay--;
        if (delay > 0) return;
        delay = rand() % 9;

        addr &= mask;
        addr &= 0xfffffffe;

        if (rw)
        {
            *dout = (data[addr + 1] << 8) | data[addr];
            *ack = req;
        }
        else
        {
            if (be & 1) data[addr + 0] = din & 0xff;
            if (be & 2) data[addr + 1] = (din >> 8) & 0xff;
            *ack = req;
        }
    }

    void update_channel_32(uint32_t addr, uint8_t req, uint8_t rw, uint8_t be, uint32_t din, uint32_t *dout, uint8_t *ack)
    {
        if (req == *ack) return;

        addr &= mask;
        addr &= 0xfffffffe;

        if (rw)
        {
            *dout = (data[addr + 3] << 24) | (data[addr + 2] << 16) | (data[addr + 1] << 8) | (data[addr + 0]);
            *ack = req;
        }
        else
        {
            if (be & 1) data[addr + 0] = din & 0xff;
            if (be & 2) data[addr + 1] = (din >> 8) & 0xff;
            if (be & 4) data[addr + 2] = (din >> 16) & 0xff;
            if (be & 8) data[addr + 3] = (din >> 24) & 0xff;
            *ack = req;
        }
    }

    void update_channel_64(uint32_t addr, uint8_t req, uint8_t rw, uint8_t be, uint64_t din, uint64_t *dout, uint8_t *ack)
    {
        if (req == *ack) return;

        delay--;
        if (delay > 0) return;
        delay = rand() % 9;


        addr &= mask;
        addr &= 0xfffffffe;

        if (rw)
        {
            *dout = ((uint64_t)data[addr + 7] << 56) |
                    ((uint64_t)data[addr + 6] << 48) |
                    ((uint64_t)data[addr + 5] << 40) |
                    ((uint64_t)data[addr + 4] << 32) |
                    ((uint64_t)data[addr + 3] << 24) |
                    ((uint64_t)data[addr + 2] << 16) |
                    ((uint64_t)data[addr + 1] << 8) |
                    ((uint64_t)data[addr + 0]);
            *ack = req;
        }
        else
        {
            if (be & 0x01) data[addr + 0] = din & 0xff;
            if (be & 0x02) data[addr + 1] = (din >> 8) & 0xff;
            if (be & 0x04) data[addr + 2] = (din >> 16) & 0xff;
            if (be & 0x08) data[addr + 3] = (din >> 24) & 0xff;
            if (be & 0x10) data[addr + 4] = (din >> 32) & 0xff;
            if (be & 0x20) data[addr + 5] = (din >> 40) & 0xff;
            if (be & 0x40) data[addr + 6] = (din >> 48) & 0xff;
            if (be & 0x80) data[addr + 7] = (din >> 56) & 0xff;
            *ack = req;
        }
    }


    bool load_data(const char *name, int offset, int stride)
    {
        std::vector<uint8_t> buffer;
        if (!g_fs.loadFile(name, buffer))
        {
            printf("Failed to find file: %s\n", name);
            return false;
        }

        uint32_t addr = offset;
        for (uint8_t byte : buffer)
        {
            data[addr & mask] = byte;
            addr += stride;
        }
        
        printf("Loaded %zu bytes from %s at offset 0x%08X with stride %d\n", 
               buffer.size(), name, offset, stride);
        return true;
    }

    bool load_data16be(const char *name, int offset)
    {
        std::vector<uint8_t> buffer;
        if (!g_fs.loadFile(name, buffer))
        {
            printf("Failed to find file: %s\n", name);
            return false;
        }

        // Ensure the buffer size is even
        if (buffer.size() % 2 != 0)
        {
            buffer.push_back(0); // Pad with zero if odd
        }

        uint32_t addr = offset;
        for (size_t i = 0; i < buffer.size(); i += 2)
        {
            // Store in big-endian format (swapping bytes)
            data[addr & mask] = buffer[i + 1];
            data[(addr + 1) & mask] = buffer[i];
            addr += 2;
        }
        
        printf("Loaded %zu bytes (16-bit BE) from %s at offset 0x%08X\n", 
               buffer.size(), name, offset);
        return true;
    }


    bool save_data(const char *filename)
    {
        FILE *fp = fopen(filename, "wb");
        if (fp == nullptr)
        {
            return false;
        }

        if (fwrite(data, 1, size, fp) != size)
        {
            fclose(fp);
            return false;
        }

        fclose(fp);
        return true;
    }

    uint32_t size;
    uint32_t mask;
    uint8_t *data;
    int delay;
};

extern SimSDRAM sdram;

#endif
