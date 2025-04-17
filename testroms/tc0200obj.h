#if !defined(TC0200OBJ_H)
#define TC0200OBJ_H 1

#include <stdint.h>

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

static inline void obj_cmd_6bpp(TC0200OBJ_Inst *o)
{
    o->has_cmd = 1;
    o->cmd_bits |= 0x0300;
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

