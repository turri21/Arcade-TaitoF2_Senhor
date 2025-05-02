#if !defined(TC0200OBJ_H)
#define TC0200OBJ_H 1

#include <stdint.h>

#define OBJCMD_UNK0 0x0001
#define OBJCMD_A14 0x0001
#define OBJCMD_UNK1 0x0002
#define OBJCMD_UNK2 0x0004
#define OBJCMD_UNK3 0x0008
#define OBJCMD_UNK4 0x0010
#define OBJCMD_UNK5 0x0020
#define OBJCMD_UNK6 0x0040
#define OBJCMD_REFRESH_CHANGE 0x0080
#define OBJCMD_UNK7 0x0080
#define OBJCMD_6BPP 0x0300
#define OBJCMD_UNKA 0x0400
#define OBJCMD_A13 0x0400
#define OBJCMD_UNKB 0x0800
#define OBJCMD_DISABLE 0x1000
#define OBJCMD_FLIPSCREEN 0x2000
#define OBJCMD_UNKE 0x4000
#define OBJCMD_DMA_LOOP 0x4000
#define OBJCMD_UNKF 0x8000
#define OBJCMD_STUCK_DRAWNING 0x8000

typedef struct
{
    uint16_t code;
    
    union
    {
        uint16_t zoom;
        struct
        {
            uint8_t zoom_y;
            uint8_t zoom_x;
        };
    };

    union
    {
        uint16_t pos0;
        struct
        {
            uint16_t ignore_all : 1;
            uint16_t ignore_extra : 1;
            uint16_t latch_master : 1;
            uint16_t latch_extra : 1;
            uint16_t x : 12;
        };
    };

    union
    {
        uint16_t pos1;
        struct
        {
            uint16_t has_cmd : 1;
            uint16_t unk1 : 1;
            uint16_t unk2 : 1;
            uint16_t unk3 : 1;
            uint16_t y : 12;
        };
    };

    union
    {
        uint16_t style;
        struct
        {
            uint16_t inc_x : 1;
            uint16_t latch_x : 1;
            uint16_t inc_y : 1;
            uint16_t latch_y : 1;
            uint16_t is_seq : 1;
            uint16_t latch_color : 1;
            uint16_t flipy : 1;
            uint16_t flipx : 1;
            uint16_t color : 8;
        };
    };

    union
    {
        uint16_t cmd;
        struct
        {
            uint16_t cmd_bits : 16;
        };
    };

    uint16_t c;
    uint16_t e;
} TC0200OBJ_Inst;

_Static_assert(sizeof(TC0200OBJ_Inst) == 16, "TC0200OBJ mismatch");

static inline void obj_reset(TC0200OBJ_Inst *o)
{
    o->zoom = 0;
    o->pos0 = 0;
    o->pos1 = 0;
    o->style = 0;
    o->cmd = 0;
    o->code = 0;
}

static inline void obj_xy(TC0200OBJ_Inst *o, int x, int y)
{
    o->x = x;
    o->y = y;
}

static inline void obj_master_xy(TC0200OBJ_Inst *o, int x, int y)
{
    obj_xy(o, x, y);
    o->latch_master = 1;
    o->ignore_all = 1;
}

static inline void obj_extra_xy(TC0200OBJ_Inst *o, int x, int y)
{
    obj_xy(o, x, y);
    o->latch_extra = 1;
    o->ignore_extra = 1;
}

static inline void obj_cmd(TC0200OBJ_Inst *o, uint16_t cmd)
{
    o->has_cmd = 1;
    o->cmd_bits = cmd;
}

static inline void obj_seq_start(TC0200OBJ_Inst *o)
{
    o->is_seq = 1;
}

static inline void obj_seq_end(TC0200OBJ_Inst *o)
{
    o->is_seq = 0;
}

static inline void obj_inc_y(TC0200OBJ_Inst *o)
{
    o->inc_y = 1;
}

static inline void obj_commit(TC0200OBJ_Inst *o, TC0200OBJ_Inst **ptr)
{
    (*ptr)->cmd = o->cmd;
    (*ptr)->code = o->code;
    (*ptr)->zoom = o->zoom;
    (*ptr)->pos0 = o->pos0;
    (*ptr)->pos1 = o->pos1;
    (*ptr)->style = o->style;
    (*ptr)++;
}

static inline void obj_commit_reset(TC0200OBJ_Inst *o, TC0200OBJ_Inst **ptr)
{
    obj_commit(o, ptr);
    obj_reset(o);
}


#endif

