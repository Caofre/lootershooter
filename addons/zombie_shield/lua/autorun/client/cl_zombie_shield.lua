surface.CreateFont("ZS_HUD", { font = "Roboto", size = 20, weight = 700 })

local function DrawBar(x, y, w, h, frac, col, label)
    surface.SetDrawColor(0, 0, 0, 170)
    surface.DrawRect(x - 2, y - 2, w + 4, h + 4)
    surface.SetDrawColor(col)
    surface.DrawRect(x, y, w * math.Clamp(frac, 0, 1), h)
    if label then
        draw.SimpleText(label, "ZS_HUD", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

hook.Add("HUDPaint", "ZS_HUD", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end

    local sw, sh = ScrW(), ScrH()

    -- shield durability, or collected-parts tracker
    local shield = lp:GetNWEntity("ZS_Shield")
    if IsValid(shield) then
        local max  = math.max(shield:GetMaxDurability(), 1)
        local frac = shield:GetDurability() / max
        local col  = Color(Lerp(frac, 220, 90), Lerp(frac, 60, 190), 60)
        DrawBar(sw * 0.02, sh - 150, 220, 18, frac, col, "SHIELD  " .. shield:GetDurability())
    elseif lp:GetNWInt("ZS_Parts", 0) > 0 then
        draw.SimpleText("Shield parts", "ZS_HUD", sw * 0.02, sh - 180, color_white)
        for i, part in ipairs(ZS.Parts) do
            local have = ZS.HasPart(lp, i)
            draw.SimpleText((have and "[x] " or "[ ] ") .. part.name, "ZS_HUD",
                sw * 0.02, sh - 180 + i * 22, have and Color(120, 220, 120) or Color(150, 150, 150))
        end
    end

    -- crafting progress
    local craft = lp:GetNWFloat("ZS_Craft", 0)
    if craft > 0 then
        DrawBar(sw / 2 - 120, sh * 0.6, 240, 20, craft, Color(240, 190, 60), "Building...")
    end

    -- look-at hints
    local tr = lp:GetEyeTrace()
    local ent = tr.Entity
    if IsValid(ent) and lp:EyePos():DistToSqr(tr.HitPos) < 110 * 110 then
        local text
        if ent:GetClass() == "zs_part" then
            local part = ZS.Parts[ent:GetPartID()]
            if part then text = "[E] Pick up: " .. part.name end
        elseif ent:GetClass() == "zs_workbench" then
            if IsValid(lp:GetNWEntity("ZS_Shield")) then
                text = "You're already wearing a shield"
            elseif ZS.HasAllParts(lp) then
                text = "Hold [E] to build the Zombie Shield"
            else
                local missing = {}
                for i, part in ipairs(ZS.Parts) do
                    if not ZS.HasPart(lp, i) then missing[#missing + 1] = part.name end
                end
                text = "Missing: " .. table.concat(missing, ", ")
            end
        end
        if text then
            draw.SimpleTextOutlined(text, "ZS_HUD", sw / 2, sh * 0.55, color_white,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        end
    end
end)

-- make loose parts and workbenches easy to spot
hook.Add("PreDrawHalos", "ZS_Halos", function()
    local parts = ents.FindByClass("zs_part")
    if #parts > 0 then halo.Add(parts, Color(255, 200, 60), 2, 2, 2, true, true) end

    local benches = ents.FindByClass("zs_workbench")
    if #benches > 0 then halo.Add(benches, Color(80, 170, 255), 2, 2, 2, true, true) end
end)
