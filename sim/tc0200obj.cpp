#include "imgui.h"
#include "imgui_wrap.h"
#include "tc0200obj.h"

#include "F2.h"
#include "F2___024root.h"

extern F2* top;

void get_obj_inst(uint16_t index, TC0200OBJ_Inst *inst)
{
    uint8_t *inst_data = (uint8_t *)inst;

    uint16_t offset = index * 8;

    for( int i = 0; i < 8; i++ )
    {
        inst_data[(i * 2) + 0] = top->rootp->F2__DOT__objram__DOT__ram_l.m_storage[offset + i];
        inst_data[(i * 2) + 1] = top->rootp->F2__DOT__objram__DOT__ram_h.m_storage[offset + i];
    }
}

static void bullet(int x)
{
    if (x != 0) ImGui::Bullet();
}

void draw_obj_window()
{
    if( !ImGui::Begin("TC0200OBJ") )
    {
        ImGui::End();
        return;
    }

    if( ImGui::BeginTable("obj", 21, ImGuiTableFlags_HighlightHoveredColumn |
                      ImGuiTableFlags_BordersInnerV |
                      ImGuiTableFlags_ScrollY |
                      ImGuiTableFlags_SizingFixedFit |
                      ImGuiTableFlags_RowBg) )
    {
        uint32_t colflags = ImGuiTableColumnFlags_AngledHeader;
        ImGui::TableSetupColumn("", colflags & ~ImGuiTableColumnFlags_AngledHeader);
        ImGui::TableSetupColumn("Code", colflags);
        ImGui::TableSetupColumn("X", colflags);
        ImGui::TableSetupColumn("Y", colflags);
        ImGui::TableSetupColumn("Cmd", colflags);
        ImGui::TableSetupColumn("Latch Extra", colflags);
        ImGui::TableSetupColumn("Latch Master", colflags);
        ImGui::TableSetupColumn("Ignore Extra", colflags);
        ImGui::TableSetupColumn("Ignore All", colflags);
        ImGui::TableSetupColumn("Flip X", colflags);
        ImGui::TableSetupColumn("Flip Y", colflags);
        ImGui::TableSetupColumn("Is Seq", colflags);
        ImGui::TableSetupColumn("Latch Y", colflags);
        ImGui::TableSetupColumn("Inc Y", colflags);
        ImGui::TableSetupColumn("Latch X", colflags);
        ImGui::TableSetupColumn("Inc X", colflags);
        ImGui::TableSetupColumn("Latch Color", colflags);
        ImGui::TableSetupColumn("Color", colflags);
        ImGui::TableSetupColumn("Cmd", colflags);
        ImGui::TableSetupColumn("Zoom X", colflags);
        ImGui::TableSetupColumn("Zoom Y", colflags);
        ImGui::TableSetupScrollFreeze(0, 1);
        ImGui::TableAngledHeadersRow();

        ImGuiListClipper clipper;
        clipper.Begin(1024);
        while( clipper.Step() )
        {
            for( uint16_t index = clipper.DisplayStart; index < clipper.DisplayEnd; index++ )
            {
                TC0200OBJ_Inst inst;
                get_obj_inst(index, &inst);
                ImGui::TableNextRow();
                ImGui::TableNextColumn(); ImGui::Text("%4u", index);
                ImGui::TableNextColumn(); ImGui::Text("%04X", inst.code);
                ImGui::TableNextColumn(); ImGui::Text("%4d", inst.x);
                ImGui::TableNextColumn(); ImGui::Text("%4d", inst.y);
                ImGui::TableNextColumn(); bullet(inst.has_cmd);
                ImGui::TableNextColumn(); bullet(inst.latch_extra);
                ImGui::TableNextColumn(); bullet(inst.latch_master);
                ImGui::TableNextColumn(); bullet(inst.ignore_extra);
                ImGui::TableNextColumn(); bullet(inst.ignore_all);
                ImGui::TableNextColumn(); bullet(inst.flipx);
                ImGui::TableNextColumn(); bullet(inst.flipy);
                ImGui::TableNextColumn(); bullet(inst.is_seq);
                ImGui::TableNextColumn(); bullet(inst.latch_y);
                ImGui::TableNextColumn(); bullet(inst.inc_y);
                ImGui::TableNextColumn(); bullet(inst.latch_x);
                ImGui::TableNextColumn(); bullet(inst.inc_x);
                ImGui::TableNextColumn(); bullet(inst.latch_color);
                ImGui::TableNextColumn(); ImGui::Text("%02X", inst.color);
                ImGui::TableNextColumn(); ImGui::Text("%04X", inst.cmd_bits);
                ImGui::TableNextColumn(); ImGui::Text("%02X", inst.zoom_x);
                ImGui::TableNextColumn(); ImGui::Text("%02X", inst.zoom_y);
            }
        }
        ImGui::EndTable();
    }

    ImGui::End();
}
