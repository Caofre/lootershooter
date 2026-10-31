-- Gadget HUD: a square ability icon next to the vitals, filling as the cooldown
-- charges (shield: shows durability), plus the use key.

local keyVar = CreateClientConVar("ls_gadget_key", "g", true, false, "Key that uses your equipped gadget")

local function useKey()
    return input.GetKeyCode(keyVar:GetString())
end

hook.Add("PlayerButtonDown", "LS_GadgetKey", function(player, button)

    if player ~= LocalPlayer() or button ~= useKey() then
        return
    end

    -- Ignore the key while typing or in a menu.
    if gui.IsGameUIVisible() or vgui.GetKeyboardFocus() or vgui.CursorVisible() then
        return
    end

    net.Start("LS_UseGadget")
    net.SendToServer()

end)

concommand.Add("ls_usegadget", function()
    net.Start("LS_UseGadget")
    net.SendToServer()
end)

surface.CreateFont("LS_GadgetKey", {font = "Trebuchet18", size = 15, weight = 800})
surface.CreateFont("LS_GadgetTime", {font = "Trebuchet24", size = 24, weight = 800})

local rarityColors = {
    Common = Color(200, 200, 200),
    Uncommon = Color(60, 225, 95),
    Rare = Color(65, 145, 255),
    Epic = Color(190, 80, 255),
    Legendary = Color(255, 155, 45)
}

-- Simple vector icons, one per gadget.
local function circle(cx, cy, radius, color)

    local points = {}

    for step = 0, 15 do
        local angle = math.rad(step * 360 / 16)
        points[#points + 1] = {x = cx + math.cos(angle) * radius, y = cy + math.sin(angle) * radius}
    end

    surface.SetDrawColor(color)
    draw.NoTexture()
    surface.DrawPoly(points)

end

local icons = {

    grenade = function(cx, cy, color)
        circle(cx, cy + 3, 11, color)
        surface.SetDrawColor(color)
        surface.DrawRect(cx - 4, cy - 14, 8, 6)
        surface.DrawRect(cx + 2, cy - 17, 7, 3)
    end,

    stim = function(cx, cy, color)
        surface.SetDrawColor(color)
        surface.DrawRect(cx - 4, cy - 14, 8, 28)
        surface.DrawRect(cx - 14, cy - 4, 28, 8)
    end,

    shield = function(cx, cy, color)
        draw.RoundedBox(4, cx - 11, cy - 15, 22, 30, color)
        draw.RoundedBox(2, cx - 7, cy - 11, 14, 22, Color(16, 19, 25, 200))
    end,

    sentry = function(cx, cy, color)
        surface.SetDrawColor(color)
        draw.NoTexture()
        surface.DrawPoly({
            {x = cx, y = cy - 15},
            {x = cx + 14, y = cy + 12},
            {x = cx - 14, y = cy + 12}
        })
        surface.DrawRect(cx - 3, cy - 3, 6, 6)
    end

}

hook.Add("HUDPaint", "LS_GadgetHUD", function()

    local player = LocalPlayer()

    if not IsValid(player) or not player:Alive() then
        return
    end

    local id = player:GetNW2String("LS_GadgetID", "")

    if id == "" then
        return
    end

    local now = CurTime()
    local size = 62
    local x = math.floor((ScrW() - 300) / 2) - size - 10
    local y = ScrH() - size - 22

    local rarity = rarityColors[player:GetNW2String("LS_GadgetRarity", "Common")] or color_white
    local startAt = player:GetNW2Float("LS_GadgetStart", 0)
    local endAt = player:GetNW2Float("LS_GadgetEnd", 0)
    local activeEnd = player:GetNW2Float("LS_GadgetActiveEnd", 0)
    local passive = player:GetNW2Bool("LS_GadgetPassive", false)
    local shieldWorn = player:GetNW2Bool("LS_GadgetShield", false)

    local cooling = now < endAt
    local fill, label

    if passive and shieldWorn then
        fill = player:GetNW2Float("LS_GadgetFill", 1)
    elseif cooling then
        fill = math.Clamp((now - startAt) / math.max(0.01, endAt - startAt), 0, 1)
        label = tostring(math.ceil(endAt - now))
    else
        fill = 1
    end

    local ready = not cooling and (not passive or shieldWorn)
    local active = now < activeEnd

    draw.RoundedBox(4, x, y, size, size, Color(16, 19, 25, 225))

    -- Charging background.
    local fillHeight = math.floor((size - 6) * fill)
    local fillColor = Color(rarity.r, rarity.g, rarity.b, ready and 120 or 85)

    if passive and shieldWorn then
        fillColor = Color(Lerp(fill, 220, 90), Lerp(fill, 70, 190), 70, 130)
    end

    draw.RoundedBox(3, x + 3, y + size - 3 - fillHeight, size - 6, fillHeight, fillColor)

    local border = ready and rarity or Color(rarity.r * 0.45, rarity.g * 0.45, rarity.b * 0.45)

    if active then
        local pulse = 0.5 + 0.5 * math.abs(math.sin(now * 6))
        border = Color(255, 255, 255, 120 + 135 * pulse)
    end

    surface.SetDrawColor(border)
    surface.DrawOutlinedRect(x, y, size, size, 2)

    local icon = icons[id]

    if icon then
        icon(x + size / 2, y + size / 2, Color(235, 240, 248, ready and 255 or 150))
    end

    if label then
        draw.SimpleTextOutlined(label, "LS_GadgetTime", x + size / 2, y + size / 2, color_white,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    end

    if not passive then
        draw.SimpleText(string.upper(keyVar:GetString()), "LS_GadgetKey", x + size / 2, y - 9, ready and color_white or Color(150, 160, 175),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

end)
