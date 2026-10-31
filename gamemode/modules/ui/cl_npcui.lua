LS_NPCUI = LS_NPCUI or {}

-- Several per-frame hooks need "all NPCs". Walking every entity on the map each
-- frame in each of them was a major frame-time cost, so the list is cached.
LS_NPCUI.TrackedList = LS_NPCUI.TrackedList or {}
LS_NPCUI.NextScan = 0

function LS_NPCUI.GetTracked()

    if CurTime() >= LS_NPCUI.NextScan then

        LS_NPCUI.NextScan = CurTime() + 0.25

        local list = {}

        for _, entity in ipairs(ents.GetAll()) do
            if entity:IsNPC() then
                list[#list + 1] = entity
            end
        end

        LS_NPCUI.TrackedList = list

    end

    -- NPCs can be removed between scans; drop them so callers never touch a NULL entity.
    local list = LS_NPCUI.TrackedList

    for index = #list, 1, -1 do
        if not IsValid(list[index]) then
            table.remove(list, index)
        end
    end

    return list

end
LS_NPCUI.LastHealth = LS_NPCUI.LastHealth or {}
LS_NPCUI.LastDamagedAt = LS_NPCUI.LastDamagedAt or {}
LS_NPCUI.DamageDisplayDuration = 3
LS_NPCUI.FullOpacityDistance = 600
LS_NPCUI.MaxDisplayDistance = 1200

function LS_NPCUI.GetVariantColor(npc, alpha)

    local colorVector = npc:GetNW2Vector(
        "LS_VariantColor",
        Vector(255, 255, 255)
    )

    return Color(
        math.Clamp(colorVector.x, 0, 255),
        math.Clamp(colorVector.y, 0, 255),
        math.Clamp(colorVector.z, 0, 255),
        alpha or 255
    )

end

hook.Add("HUDPaint", "LS_NPCUI", function()

    local player = LocalPlayer()
    local lookedAt = player:GetEyeTrace().Entity

    for _, npc in ipairs(LS_NPCUI.GetTracked()) do

        if not npc:IsNPC() then
            continue
        end

        if not npc:GetNW2Bool("LS_IsFrameworkNPC", false) then
            continue
        end

        local maxHealth = npc:GetNW2Int(
            "LS_MaxHealth",
            npc:GetMaxHealth()
        )

        if maxHealth <= 0 then
            continue
        end

        local npcIndex = npc:EntIndex()
        local health = npc:Health()
        local lastHealth = LS_NPCUI.LastHealth[npcIndex]

        if lastHealth and health < lastHealth then
            LS_NPCUI.LastDamagedAt[npcIndex] = CurTime()
        end

        LS_NPCUI.LastHealth[npcIndex] = health

        local lastDamagedAt = LS_NPCUI.LastDamagedAt[npcIndex]
        local recentlyDamaged = lastDamagedAt and
            CurTime() < lastDamagedAt +
            LS_NPCUI.DamageDisplayDuration

        if npc ~= lookedAt and not recentlyDamaged then
            continue
        end

        local distance = player:GetPos():Distance(npc:GetPos())

        if distance >= LS_NPCUI.MaxDisplayDistance then
            continue
        end

        local fadePercent = math.Clamp(
            (distance - LS_NPCUI.FullOpacityDistance) /
            (LS_NPCUI.MaxDisplayDistance -
                LS_NPCUI.FullOpacityDistance),
            0,
            1
        )

        local alpha = math.floor(255 * (1 - fadePercent))
        local barAlpha = math.floor(220 * (1 - fadePercent))
        local fillAlpha = math.floor(230 * (1 - fadePercent))

        local healthPercent = math.Clamp(
            health / maxHealth,
            0,
            1
        )

        local pos = (
            npc:WorldSpaceCenter() +
            Vector(0, 0, 16)
        ):ToScreen()

        local level = npc:GetNW2Int("LS_Level", 1)
        local name = npc:GetNW2String("LS_Name", "Unknown")
        local variantBadge = npc:GetNW2String("LS_VariantBadge", "")
        local variantColor = LS_NPCUI.GetVariantColor(npc, alpha)

        local barWidth = 150
        local barHeight = 12
        local barX = pos.x - (barWidth / 2)
        local barY = pos.y

        if variantBadge ~= "" then
            draw.SimpleText(
                variantBadge,
                "DermaDefaultBold",
                pos.x,
                barY - 48,
                variantColor,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end

        draw.SimpleText(
            name,
            "DermaDefaultBold",
            pos.x,
            barY - 34,
            Color(255, 255, 255, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            "Lv. " .. level,
            "DermaDefaultBold",
            pos.x,
            barY - 20,
            Color(220, 220, 220, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        draw.RoundedBox(
            2,
            barX,
            barY,
            barWidth,
            barHeight,
            Color(30, 30, 30, barAlpha)
        )

        if variantBadge ~= "" then
            draw.RoundedBox(
                2,
                barX,
                barY,
                barWidth,
                2,
                LS_NPCUI.GetVariantColor(npc, barAlpha)
            )
        end

        draw.RoundedBox(
            2,
            barX,
            barY,
            barWidth * healthPercent,
            barHeight,
            Color(70, 210, 80, fillAlpha)
        )

        local shieldMax = npc:GetNW2Int("LS_ShieldMax", 0)
        local shield = npc:GetNW2Int("LS_Shield", 0)

        if shieldMax > 0 and shield > 0 then
            draw.RoundedBox(
                2,
                barX,
                barY + barHeight + 2,
                barWidth * math.Clamp(shield / shieldMax, 0, 1),
                5,
                Color(109, 220, 235, fillAlpha)
            )
        end

    end

end)

-- A soft colored light on variant NPCs near the player, flickering for Volatile.
hook.Add("Think", "LS_NPCVariantLights", function()

    local player = LocalPlayer()

    if not IsValid(player) then
        return
    end

    local used = 0

    local origin = player:GetPos()

    for _, npc in ipairs(LS_NPCUI.GetTracked()) do

        if used >= 8 then
            break
        end

        if not IsValid(npc) or npc:GetPos():DistToSqr(origin) > 900 * 900 then
            continue
        end

        local variant = npc:IsNPC() and npc:GetNW2String("LS_Variant", "") or ""

        if variant ~= "" and variant ~= "normal" and npc:GetNW2Bool("LS_IsFrameworkNPC", false) and npc:Health() > 0 then

            local color = LS_NPCUI.GetVariantColor(npc)
            local light = DynamicLight(npc:EntIndex())

            if light then
                used = used + 1
                local flicker = variant == "volatile" and (0.6 + 0.4 * math.abs(math.sin(CurTime() * 8))) or 1
                light.Pos = npc:WorldSpaceCenter()
                light.r, light.g, light.b = color.r, color.g, color.b
                light.Brightness = 1.2 * flicker
                light.Size = 110
                light.Decay = 600
                light.DieTime = CurTime() + 0.1
            end

        end

    end

end)

net.Receive("LS_ToxicCloud", function()

    local position = net.ReadVector()
    local radius = net.ReadFloat()
    local duration = net.ReadFloat()
    local emitter = ParticleEmitter(position)
    local endsAt = CurTime() + duration
    local timerName = "LS_ToxicCloudFX_" .. tostring(SysTime()) .. math.random(1000)

    timer.Create(timerName, 0.12, 0, function()

        if CurTime() >= endsAt or not emitter then
            timer.Remove(timerName)

            if emitter then
                emitter:Finish()
            end

            return
        end

        for _ = 1, 4 do
            local offset = VectorRand() * radius * 0.7
            offset.z = math.Rand(0, 50)

            local particle = emitter:Add("particle/particle_smokegrenade", position + offset)

            if particle then
                particle:SetDieTime(math.Rand(1.2, 2))
                particle:SetStartAlpha(110)
                particle:SetEndAlpha(0)
                particle:SetStartSize(math.Rand(35, 55))
                particle:SetEndSize(math.Rand(70, 95))
                particle:SetColor(80, 210, 70)
                particle:SetVelocity(Vector(math.Rand(-8, 8), math.Rand(-8, 8), math.Rand(6, 18)))
                particle:SetRoll(math.Rand(0, 360))
            end
        end

    end)

end)

hook.Add("PreDrawHalos", "LS_NPCVariantHalos", function()

    local localPlayer = LocalPlayer()

    for _, npc in ipairs(LS_NPCUI.GetTracked()) do

        if not npc:IsNPC() or
            not npc:GetNW2Bool("LS_IsFrameworkNPC", false) or
            npc:GetNW2String("LS_Variant", "") == "normal" or
            npc:GetNW2String("LS_Variant", "") == "" or
            localPlayer:GetPos():Distance(npc:GetPos()) > LS_NPCUI.MaxDisplayDistance then
            continue
        end

        halo.Add(
            {npc},
            LS_NPCUI.GetVariantColor(npc),
            2,
            2,
            1,
            true,
            false
        )

    end

end)


-- Marked targets show through walls, and a banner explains the penalty.
hook.Add("PreDrawHalos", "LS_NPCMarkedHalos", function()

    local marked = {}

    for _, npc in ipairs(LS_NPCUI.GetTracked()) do
        if npc:IsNPC() and npc:GetNW2Bool("LS_MarkedTarget", false) and npc:Health() > 0 then
            table.insert(marked, npc)
        end
    end

    if #marked > 0 then
        halo.Add(marked, Color(255, 60, 160), 3, 3, 2, true, true)
    end

end)

hook.Add("HUDPaint", "LS_MarkedBanner", function()

    if not GetGlobalBool("LS_Marked", false) then
        return
    end

    local pulse = 0.65 + 0.35 * math.abs(math.sin(CurTime() * 3))
    local x, y = ScrW() / 2, 110

    draw.SimpleText("MARKED", "Trebuchet24", x, y, Color(255, 60, 160, 255 * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Enemies deal +25% damage - kill the marked target", "DermaDefaultBold", x, y + 22, Color(255, 215, 235, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

end)


-- Beams (Healer, Commander) ---------------------------------------------
LS_NPCUI.Beams = LS_NPCUI.Beams or {}

net.Receive("LS_Beam", function()

    table.insert(LS_NPCUI.Beams, {
        From = net.ReadVector(),
        To = net.ReadVector(),
        Color = net.ReadColor(),
        Duration = net.ReadFloat(),
        At = CurTime()
    })

end)

local beamMaterial = Material("sprites/physbeam")

hook.Add("PostDrawTranslucentRenderables", "LS_NPCBeams", function()

    local now = CurTime()

    for index = #LS_NPCUI.Beams, 1, -1 do

        local beam = LS_NPCUI.Beams[index]
        local age = now - beam.At

        if age >= beam.Duration then
            table.remove(LS_NPCUI.Beams, index)
        else
            local fade = 1 - age / beam.Duration

            render.SetMaterial(beamMaterial)
            render.DrawBeam(beam.From, beam.To, 6 * fade + 1, now * 2, now * 2 + 1,
                Color(beam.Color.r, beam.Color.g, beam.Color.b, 255 * fade))
        end

    end

end)

-- Ground fields (Cryo) ---------------------------------------------------
net.Receive("LS_FieldFX", function()

    local position = net.ReadVector()
    local radius = net.ReadFloat()
    local duration = net.ReadFloat()
    local color = net.ReadColor()
    local emitter = ParticleEmitter(position)
    local endsAt = CurTime() + duration
    local timerName = "LS_FieldFX_" .. tostring(SysTime()) .. math.random(1000)

    timer.Create(timerName, 0.12, 0, function()

        if CurTime() >= endsAt or not emitter then
            timer.Remove(timerName)

            if emitter then
                emitter:Finish()
            end

            return
        end

        for _ = 1, 4 do
            local offset = VectorRand() * radius * 0.7
            offset.z = math.Rand(0, 40)

            local particle = emitter:Add("particle/particle_smokegrenade", position + offset)

            if particle then
                particle:SetDieTime(math.Rand(1.2, 2))
                particle:SetStartAlpha(100)
                particle:SetEndAlpha(0)
                particle:SetStartSize(math.Rand(30, 50))
                particle:SetEndSize(math.Rand(65, 90))
                particle:SetColor(color.r, color.g, color.b)
                particle:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(4, 14)))
                particle:SetRoll(math.Rand(0, 360))
            end
        end

    end)

end)

-- Chilled overlay ----------------------------------------------------------
hook.Add("HUDPaint", "LS_ChilledOverlay", function()

    if not LocalPlayer():GetNW2Bool("LS_Chilled", false) then
        return
    end

    surface.SetDrawColor(120, 190, 255, 35)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    draw.SimpleText("CHILLED", "Trebuchet24", ScrW() / 2, 150, Color(170, 225, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

end)


-- Frosted enemies get an icy outline.
hook.Add("PreDrawHalos", "LS_NPCFrostHalos", function()

    local frosted = {}

    for _, npc in ipairs(LS_NPCUI.GetTracked()) do
        if npc:IsNPC() and npc:GetNW2Bool("LS_Frosted", false) and npc:Health() > 0 then
            table.insert(frosted, npc)
        end
    end

    if #frosted > 0 then
        halo.Add(frosted, Color(150, 215, 255), 2, 2, 2, true, false)
    end

end)
