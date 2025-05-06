#include "input.h"

#include "system.h"

static uint16_t s_prev = 0;
static uint16_t s_cur = 0;
static uint16_t s_dsw = 0;

void input_update()
{
    s_prev = s_cur;
    s_cur = TC0220IOC->p1;

    s_dsw = ( TC0220IOC->sw_a & 0x00ff ) | ( TC0220IOC->sw_b << 8 );
}

uint16_t input_state()
{
    return s_cur;
}

bool input_down(InputKey key)
{
    return (s_cur & key) != key;
}

bool input_released(InputKey key)
{
    return ((s_cur & key) != 0) && (((s_prev ^ s_cur) & key) != 0);
}

bool input_pressed(InputKey key)
{
    return ((s_cur & key) != key) && (((s_prev ^ s_cur) & key) != 0);
}

uint16_t input_dsw()
{
    return s_dsw;
}
