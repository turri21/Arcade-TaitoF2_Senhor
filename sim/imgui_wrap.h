#if !defined(IMGUI_WRAP_H)
#define IMGUI_WRAP_H 1

#include "imgui.h"

bool imgui_init(const char *title);
bool imgui_begin_frame();
void imgui_end_frame();

struct SDL_Renderer;
SDL_Renderer *imgui_get_renderer();

#endif // IMGUI_WRAP_H
