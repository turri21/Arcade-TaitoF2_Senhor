#if !defined(SIM_VIDEO_H)
#define SIM_VIDEO_H 1

#include <stdint.h>
#include <SDL.h>

#include "imgui.h"

class SimVideo
{
public:
    ~SimVideo()
    {
        deinit();
    }

    void init(int w, int h, SDL_Renderer *renderer)
    {
        width = w;
        height = h;
        pixels = new uint32_t[width * height];
        texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBX8888, SDL_TEXTUREACCESS_STREAMING, width, height);
        x = 0;
        y = 0;
        in_vsync = false;
        in_hsync = false;
        in_ce = false;
    }

    void deinit()
    {
        if (pixels) delete [] pixels;
        if (texture) SDL_DestroyTexture(texture);

        pixels = nullptr;
        texture = nullptr;
    }

    void clock(bool ce, bool hsync, bool vsync, uint8_t r, uint8_t g, uint8_t b)
    {
        if (!ce)
        {
            in_ce = false;
            return;
        }

        if (in_ce) return;

        if (hsync)
        {
            x = 0;
            if (!in_hsync) y++;
        }

        if (vsync)
        {
            if (!in_vsync) x = 0;
            y = 0;
        }

        in_hsync = hsync;
        in_vsync = vsync;
        in_ce = ce;

        if (!hsync && !vsync)
        {
            uint32_t c = r << 24 | g << 16 | b << 8;
            if (x < width && y < height)
                pixels[(y * width) + x] = c;
            x++;
        }
    }

    void update_texture()
    {
        SDL_Rect region;

        int line_count = height;
        int line_start = 0;
        region.x = 0;
        region.y = line_start;
        region.w = width;
        region.h = line_count;

        void *work;
        int pitch;

        SDL_LockTexture(texture, &region, &work, &pitch);

        for( int line = 0; line < line_count; line++ )
        {
            uint8_t *dest = ((uint8_t *)work) + (pitch * line);
            uint32_t *src = pixels + ((line + line_start) * width);
            if (!in_vsync && ((line + line_start) == y))
            {
                memset(dest, 0x2f, pitch);
            }
            else
            {
                memcpy(dest, src, pitch);
            }
        }

        SDL_UnlockTexture(texture);
    }

    void draw()
    {
        ImGui::Begin("Video");
        ImVec2 avail_size = ImGui::GetContentRegionAvail();
        int w = avail_size.x;
        int h = (w * 3) / 4;
        ImGui::Image((ImTextureID)texture, ImVec2(w, h));
        ImGui::Text("X: %03d Y: %03d", x, y);
        ImGui::Text("HS: %d VS: %d", in_hsync, in_vsync);

        ImGui::End();
    }

    int width, height;
    uint32_t *pixels = nullptr;

    int x, y;
    bool in_hsync, in_vsync, in_ce;
    SDL_Texture *texture = nullptr;
};

#endif
