LS_DamageNumbers = LS_DamageNumbers or {Active = {}}

local enabled = CreateClientConVar("ls_damagenumbers", "1", true, false, "Show floating damage numbers")

surface.CreateFont("LS_DmgNum", {font = "Trebuchet24", size = 22, weight = 800})
surface.CreateFont("LS_DmgNumBig", {font = "Trebuchet24", size = 30, weight = 900})
surface.CreateFont("LS_DmgNumHuge", {font = "Trebuchet24", size = 40, weight = 900})

local LIFETIME = 1.1
local MAX_ACTIVE = 40

local colors = {
    [0] = Color(255, 255, 255),
    [1] = Color(255, 150, 50),
    [2] = Color(120, 175, 255),
    [3] = Color(255, 120, 60),
    [4] = Color(225, 70, 70),
    [5] = Color(110, 220, 235)
}

net.Receive("LS_DamageNumber", function()

    local position = net.ReadVector()
    local amount = net.ReadUInt(16)
    local kind = net.ReadUInt(3)
    local headshot = net.ReadBool()
    local kill = net.ReadBool()

    local active = LS_DamageNumbers.Active

    table.insert(active, {
        Position = position,
        Text = kind == 5 and ("(" .. amount .. ")") or tostring(amount),
        Color = headshot and Color(255, 220, 60) or colors[kind] or color_white,
        Font = (headshot and kill) and "LS_DmgNumHuge" or ((headshot or kill) and "LS_DmgNumBig" or "LS_DmgNum"),
        Drift = math.Rand(-18, 18),
        Born = CurTime()
    })

    while #active > MAX_ACTIVE do
        table.remove(active, 1)
    end

end)

hook.Add("HUDPaint", "LS_DamageNumbers", function()

    local active = LS_DamageNumbers.Active

    if #active == 0 then
        return
    end

    if not enabled:GetBool() then
        table.Empty(active)
        return
    end

    local now = CurTime()
    local right = LocalPlayer():EyeAngles():Right()

    for index = #active, 1, -1 do

        local entry = active[index]
        local progress = (now - entry.Born) / LIFETIME

        if progress >= 1 then
            table.remove(active, index)
        else
            local world = entry.Position + Vector(0, 0, progress * 32) + right * entry.Drift * progress
            local screen = world:ToScreen()

            if screen.visible then
                local alpha = 255 * (1 - progress * progress)

                draw.SimpleTextOutlined(
                    entry.Text, entry.Font, screen.x, screen.y,
                    Color(entry.Color.r, entry.Color.g, entry.Color.b, alpha),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha)
                )
            end
        end

    end

end)
