#include <cstdio>
#if !defined (SIM_SDRAM_H)
#define SIM_SDRAM_H 1

#include <stdint.h>
#include <stdio.h>

class SimSDRAM
{
public:
    SimSDRAM(uint32_t sz)
    {
        size = sz;
        mask = sz - 1;
        data = new uint8_t [size];
    }

    ~SimSDRAM()
    {
        delete [] data;
        data = nullptr;
    }

    void update_channel_16(uint32_t addr, uint8_t req, uint8_t rw, uint8_t be, uint16_t din, uint16_t *dout, uint8_t *ack)
    {
        if (req == *ack) return;

        addr &= mask;
        addr &= 0xfffffffe;

        if (rw)
        {
            *dout = (data[addr] << 8) | data[addr + 1];
            *ack = req;
        }
        else
        {
            if (be & 1) data[addr + 1] = din & 0xff;
            if (be & 2) data[addr] = (din >> 8) & 0xff;
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
            *dout = (data[addr] << 24) | (data[addr + 1] << 16) | (data[addr + 2] << 8) | (data[addr + 3]);
            *ack = req;
        }
        else
        {
            if (be & 1) data[addr + 3] = din & 0xff;
            if (be & 2) data[addr + 2] = (din >> 8) & 0xff;
            if (be & 4) data[addr + 1] = (din >> 16) & 0xff;
            if (be & 8) data[addr + 0] = (din >> 24) & 0xff;
            *ack = req;
        }
    }

    bool load_data(const char *name, int offset, int stride)
    {
        FILE *fp = fopen(name, "rb");
        if (fp == nullptr)
        {
            return false;
        }

        uint32_t addr = offset;
        uint8_t byte;

        while( fread(&byte, 1, 1, fp) == 1 )
        {
            data[addr & mask] = byte;
            addr += stride;
        }

        fclose(fp);
        return true;
    }

    uint32_t size;
    uint32_t mask;
    uint8_t *data;
};

#endif
