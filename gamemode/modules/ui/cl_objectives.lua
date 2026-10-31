-- Mission objective markers: outlines, floating labels, and the progress bar
-- (generator or nest health) shown above the objective box.

LS_Objectives = LS_Objectives or {List = {}, NextScan = 0}

local kindColors = {
    generator = Color(90, 190, 255),
    crate = Color(255, 215, 90),
    nest = Color(150, 230, 110),
    terminal = Color(120, 170, 255)
}

local function tracked()

    if CurTime() >= LS_Objectives.NextScan then
        LS_Objectives.NextScan = CurTime() + 0.5
        LS_Objectives.List = ents.FindByClass("ls_objective")
    end

    return LS_Objectives.List

end

hook.Add("PreDrawHalos", "LS_ObjectiveHalos", function()

    for _, objective in ipairs(tracked()) do

        if IsValid(objective) and not objective:GetDone() then
            halo.Add({objective}, kindColors[objective:GetKind()] or color_white, 2, 2, 2, true, true)
        end

    end

end)

hook.Add("HUDPaint", "LS_ObjectiveLabels", function()

    local origin = LocalPlayer():GetPos()

    for _, objective in ipairs(tracked()) do

        if IsValid(objective) and not objective:GetDone() and objective:GetPos():DistToSqr(origin) < 2200 * 2200 then

            local screen = (objective:WorldSpaceCenter() + Vector(0, 0, 70)):ToScreen()

            if screen.visible then

                local kind = objective:GetKind()
                local color = kindColors[kind] or color_white
                local text

                if kind == "generator" then
                    text = "GENERATOR  " .. objective:GetObjHealth() .. " / " .. objective:GetObjMaxHealth()
                elseif kind == "nest" then
                    text = "NEST  " .. objective:GetObjHealth() .. " / " .. objective:GetObjMaxHealth()
                elseif kind == "terminal" then
                    text = objective:GetProgress() > 0 and ("HACKING  " .. objective:GetProgress() .. "%") or "TERMINAL  [hold E]"
                else
                    text = "SUPPLIES  [E]"
                end

                draw.SimpleTextOutlined(text, "Trebuchet18", screen.x, screen.y, color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)

            end

        end

    end

end)

hook.Add("HUDPaint", "LS_ObjectiveBar", function()

    local maximum = GetGlobalInt("LS_BarMax", 0)

    if maximum <= 0 then
        return
    end

    local value = GetGlobalInt("LS_BarValue", 0)
    local fraction = math.Clamp(value / maximum, 0, 1)
    local x, y, width, height = 24, ScrH() - 105 - 30, 360, 22

    draw.RoundedBox(4, x, y, width, height, Color(16, 19, 25, 225))
    draw.RoundedBox(3, x + 3, y + 3, (width - 6) * fraction, height - 6,
        fraction > 0.35 and Color(90, 190, 255) or Color(230, 80, 70))
    draw.SimpleText(GetGlobalString("LS_BarLabel", "") .. "  " .. value .. " / " .. maximum, "DermaDefaultBold",
        x + width / 2, y + height / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

end)
