#if !defined(TC0430GRW_H)
#define TC0430GRW_H 1

#include <stdint.h>

typedef struct TC0430GRW_Control
{
    int32_t origin_x;
    int16_t dxx;
    int16_t dxy;

    int32_t origin_y;
    int16_t dyx;
    int16_t dyy;
} TC0430GRW_Control;

_Static_assert(sizeof(TC0430GRW_Control) == 0x10, "TC0430GRW_Control mismatch");

#endif
