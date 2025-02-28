#if !defined (SIM_SDRAM_H)
#define SIM_SDRAM_H 1

#include <stdint.h>

class SimSDRAM
{
public:
    SimSDRAM(uint32_t size)
    {
        data = new uint8_t [size];
    }

    ~SimSDRAM()
    {
        delete [] data;
        data = nullptr;
    }

    void update_channel(uint32_t addr, uint8_t req, uint8_t rw, uint8_t be, uint16_t din, uint16_t *dout, uint8_t *ack)
    {
        if (req == *ack) return;

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

    uint8_t *data;
};

#endif
