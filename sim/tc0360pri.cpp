#include <SDL.h>

#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_wrap.h"

#include "F2.h"
#include "F2___024root.h"

extern F2* top;

void draw_pri_window()
{
    if (!ImGui::Begin("TC0360PRI"))
    {
        ImGui::End();
        return;
    }

    uint16_t color_in0 = top->rootp->F2__DOT__tc0360pri__DOT__color_in0;
    uint16_t color_in1 = top->rootp->F2__DOT__tc0360pri__DOT__color_in1;
    uint16_t color_in2 = top->rootp->F2__DOT__tc0360pri__DOT__color_in2;
    uint8_t ctrl[16];
    for( int i = 0; i < 16; i++ )
    {
        ctrl[i] = top->rootp->F2__DOT__tc0360pri__DOT__ctrl[i];
    }

    ImGui::Text("Color0: %03X  Sel0: %d", color_in0 & 0xfff, (color_in0 >> 12) & 0x3);
    ImGui::Text("Color1: %03X  Sel1: %d", color_in1 & 0xfff, (color_in1 >> 12) & 0x3);
    ImGui::Text("Color2: %03X  Sel2: %d", color_in2 & 0xfff, (color_in2 >> 12) & 0x3);

    ImGui::Text("Prio0: %X %X %X %X",
                (ctrl[4] >> 0) & 0xf,
                (ctrl[4] >> 4) & 0xf,
                (ctrl[5] >> 0) & 0xf,
                (ctrl[5] >> 4) & 0xf);

    ImGui::Text("Prio1: %X %X %X %X",
                (ctrl[6] >> 0) & 0xf,
                (ctrl[6] >> 4) & 0xf,
                (ctrl[7] >> 0) & 0xf,
                (ctrl[7] >> 4) & 0xf);

    ImGui::Text("Prio2: %X %X %X %X",
                (ctrl[8] >> 0) & 0xf,
                (ctrl[8] >> 4) & 0xf,
                (ctrl[9] >> 0) & 0xf,
                (ctrl[9] >> 4) & 0xf);

    ImGui::End();
}
