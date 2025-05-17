#include <cstdio>
#if !defined (SIM_SDRAM_H)
#define SIM_SDRAM_H 1

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

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

    bool load_data16be(const char *name, int offset)
    {
        FILE *fp = fopen(name, "rb");
        if (fp == nullptr)
        {
            return false;
        }

        uint32_t addr = offset;
        uint8_t bytes[2];

        while( fread(bytes, 1, 2, fp) == 1 )
        {
            data[addr & mask] = bytes[1];
            data[(addr + 1) & mask] = bytes[0];
            addr += 2;
        }

        fclose(fp);
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
