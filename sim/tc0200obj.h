#if !defined(TC0200OBJ_H)
#define TC0200OBJ_H 1

#include <stdint.h>

#include <SDL.h>

typedef struct
{
    uint16_t code;
    
    union
    {
        uint16_t zoom;
        struct
        {
            uint8_t zoom_x;
            uint8_t zoom_y;
        };
    };

    union
    {
        uint16_t pos0;
        struct
        {
            int16_t x : 12;
            uint16_t latch_extra : 1;
            uint16_t latch_master : 1;
            uint16_t ignore_extra : 1;
            uint16_t ignore_all : 1;
        };
    };

    union
    {
        uint16_t pos1;
        struct
        {
            int16_t y : 12;
            uint16_t unk1 : 1;
            uint16_t unk2 : 1;
            uint16_t unk3 : 1;
            uint16_t has_cmd : 1;
        };
    };

    union
    {
        uint16_t style;
        struct
        {
            uint16_t color : 8;
            uint16_t flipx : 1;
            uint16_t flipy : 1;
            uint16_t latch_color : 1;
            uint16_t is_seq : 1;
            uint16_t latch_y : 1;
            uint16_t inc_y : 1;
            uint16_t latch_x : 1;
            uint16_t inc_x : 1;
        };
    };

    union
    {
        uint16_t cmd;
        struct
        {
            // 0x0300 = 6bpp mode
            uint16_t cmd_bits : 16;
        };
    };

    uint16_t c;
    uint16_t e;
} TC0200OBJ_Inst;

static_assert(sizeof(TC0200OBJ_Inst) == 16, "TC0200OBJ mismatch");

void draw_obj_window();
void draw_obj_preview_window();

void init_obj_cache(SDL_Renderer *renderer, const void *objmem, const void *palmem_low, const void *palmem_high);
void prune_obj_cache();
SDL_Texture *get_obj_texture(uint16_t code, uint8_t palette);

#endif

