LS_HUD = LS_HUD or {}
LS_HUD.Health = LS_HUD.Health or 100
LS_HUD.Armor = LS_HUD.Armor or 0
LS_HUD.LastHealth = LS_HUD.LastHealth or 100
LS_HUD.HitFlash = LS_HUD.HitFlash or 0

surface.CreateFont("LS_HUDNumber", {font = "Trebuchet24", size = 30, weight = 800})
surface.CreateFont("LS_HUDAmmo", {font = "Trebuchet24", size = 44, weight = 800})
surface.CreateFont("LS_HUDLabel", {font = "Trebuchet18", size = 14, weight = 700})

local accent = Color(150, 160, 175)
local panelColor = Color(16, 19, 25, 215)

local hidden = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true
}

function LS_IsEquippedClient(itemID)
    for _, equippedID in pairs(LS_ClientEquipment or {}) do
        if equippedID == itemID then return true end
    end
    return false
end

hook.Add("HUDShouldDraw", "LS_HideDefaultHUD", function(name)
    if hidden[name] then return false end
end)

local function drawBar(x, y, width, height, fraction, color, label, value)
    draw.RoundedBox(3, x, y, width, height, Color(0, 0, 0, 170))
    draw.RoundedBox(3, x + 2, y + 2, math.max(0, (width - 4) * math.Clamp(fraction, 0, 1)), height - 4, color)
    draw.SimpleText(label, "LS_HUDLabel", x + 8, y + height / 2, Color(255, 255, 255, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(value), "LS_HUDLabel", x + width - 8, y + height / 2, Color(255, 255, 255, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "LS_CustomHUD", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:Alive() then return end

    local frameTime = FrameTime()
    local health, maxHealth = player:Health(), math.max(1, player:GetMaxHealth())
    local armor = player:GetNW2Int("LS_ArmorPool", 0)
    local armorMax = player:GetNW2Int("LS_ArmorMax", 0)

    if health < LS_HUD.LastHealth then LS_HUD.HitFlash = 1 end
    LS_HUD.LastHealth = health
    LS_HUD.HitFlash = math.max(0, LS_HUD.HitFlash - frameTime * 2.5)
    LS_HUD.Health = Lerp(math.min(1, frameTime * 8), LS_HUD.Health, health)
    LS_HUD.Armor = Lerp(math.min(1, frameTime * 8), LS_HUD.Armor, armor)

    -- Vitals: bottom center.
    local width, height = 300, 62
    local x, y = math.floor((ScrW() - width) / 2), ScrH() - height - 22
    draw.RoundedBox(4, x, y, width, height, panelColor)
    surface.SetDrawColor(accent.r, accent.g, accent.b, 210)
    surface.DrawRect(x, y, 4, height)

    local healthFraction = LS_HUD.Health / maxHealth
    local healthColor = healthFraction > 0.35 and Color(90, 190, 110) or Color(215, 65, 55)
    if LS_HUD.HitFlash > 0 then
        healthColor = Color(255, 255 - 120 * LS_HUD.HitFlash, 255 - 160 * LS_HUD.HitFlash)
    end
    drawBar(x + 14, y + 10, width - 26, 20, healthFraction, healthColor, "HEALTH", health)
    drawBar(x + 14, y + 36, width - 26, 16, armorMax > 0 and (LS_HUD.Armor / armorMax) or 0, Color(70, 150, 230),
        armorMax > 0 and "ARMOR" or "NO ARMOR", armorMax > 0 and (armor .. " / " .. armorMax) or "")

    -- Ammo and weapon: bottom right.
    local weapon = player:GetActiveWeapon()
    if IsValid(weapon) then
        local clip, clipMax = weapon:Clip1(), weapon:GetMaxClip1()
        local reserve = player:GetAmmoCount(weapon:GetPrimaryAmmoType())
        local ax, ay, aw, ah = ScrW() - 270 - 28, ScrH() - 96 - 22, 270, 96
        draw.RoundedBox(4, ax, ay, aw, ah, panelColor)
        -- Cached: only looked up again when the weapon or the inventory changes.
        local class = weapon:GetClass()

        if LS_HUD.CachedClass ~= class or LS_HUD.CachedInventory ~= LS_ClientInventory or
            LS_HUD.CachedEquipment ~= LS_ClientEquipment then

            LS_HUD.CachedClass = class
            LS_HUD.CachedInventory = LS_ClientInventory
            LS_HUD.CachedEquipment = LS_ClientEquipment
            LS_HUD.WeaponName = string.upper(weapon:GetPrintName() or class)
            LS_HUD.WeaponColor = Color(235, 238, 245)

            for _, item in ipairs(LS_ClientInventory or {}) do
                if item.class == class and LS_IsEquippedClient(item.id) then
                    LS_HUD.WeaponName = string.upper((item.prefix or "") .. " " .. (item.weapon or LS_HUD.WeaponName))
                    LS_HUD.WeaponColor = LS_UI.RarityColors[item.rarity] or LS_HUD.WeaponColor
                    break
                end
            end
        end

        local weaponName, weaponColor = LS_HUD.WeaponName, LS_HUD.WeaponColor
        surface.SetDrawColor(weaponColor.r, weaponColor.g, weaponColor.b, 220)
        surface.DrawRect(ax + aw - 4, ay, 4, ah)

        draw.SimpleText(weaponName, "LS_HUDLabel", ax + 14, ay + 12, weaponColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if clipMax > 0 or clip >= 0 then
            local low = clipMax > 0 and clip <= math.ceil(clipMax * 0.25)
            draw.SimpleText(clip, "LS_HUDAmmo", ax + 14, ay + 54, low and Color(230, 75, 60) or Color(245, 245, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("/ " .. reserve, "LS_HUDNumber", ax + 120, ay + 60, Color(185, 195, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("MELEE", "LS_HUDNumber", ax + 14, ay + 56, Color(245, 245, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Damage vignette flash.
    if LS_HUD.HitFlash > 0 then
        surface.SetDrawColor(200, 30, 20, 70 * LS_HUD.HitFlash)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
end)

-- Credits balance and gain toasts, stacked above the ammo panel.
LS_HUD.Toasts = LS_HUD.Toasts or {}

net.Receive("LS_CurrencyGain", function()
    local amount, reason = net.ReadInt(32), net.ReadString()
    table.insert(LS_HUD.Toasts, 1, {Amount = amount, Reason = reason, At = CurTime()})
    while #LS_HUD.Toasts > 4 do table.remove(LS_HUD.Toasts) end
    if amount > 0 then surface.PlaySound("ambient/levels/labs/coinslot1.wav") end
end)

hook.Add("HUDPaint", "LS_CreditsHUD", function()
    local player = LocalPlayer()
    if not IsValid(player) or not player:Alive() then return end

    local right = ScrW() - 28
    local baseY = ScrH() - 96 - 22 - 34
    draw.RoundedBox(4, right - 270, baseY, 270, 28, panelColor)
    surface.SetDrawColor(255, 205, 90, 210)
    surface.DrawRect(right - 4, baseY, 4, 28)
    draw.SimpleText("CREDITS", "LS_HUDLabel", right - 262, baseY + 14, Color(160, 170, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.Comma(LS_Currency.Get()) .. " CR", "LS_HUDLabel", right - 14, baseY + 14, Color(255, 205, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local now = CurTime()
    for index = #LS_HUD.Toasts, 1, -1 do
        if now - LS_HUD.Toasts[index].At > 4 then table.remove(LS_HUD.Toasts, index) end
    end
    for index, toast in ipairs(LS_HUD.Toasts) do
        local alpha = math.Clamp(4 - (now - toast.At), 0, 1) * 255
        local y = baseY - index * 22
        local sign = toast.Amount >= 0 and "+" or ""
        local base = toast.Color or Color(255, 205, 90)
        local color = toast.Amount >= 0 and Color(base.r, base.g, base.b, alpha) or Color(230, 90, 80, alpha)
        draw.SimpleText(sign .. toast.Amount .. " " .. (toast.Unit or "CR"), "LS_HUDLabel", right - 14, y, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(toast.Reason, "LS_HUDLabel", right - 80, y, Color(190, 198, 212, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end)


-- Talent buff chips (Momentum, Marksman, Berserker), stacked above the vitals.
local buffIDs = {"momentum", "marksman", "berserker", "stim", "secondwind", "adrenaline", "reactive", "armorbreak", "overcharge", "overdose"}

hook.Add("HUDPaint", "LS_BuffChips", function()

    local player = LocalPlayer()

    if not IsValid(player) or not player:Alive() then
        return
    end

    local now = CurTime()
    local row = 0

    for _, id in ipairs(buffIDs) do

        if player:GetNW2Float("LS_BuffEnd_" .. id, 0) > now then

            local text = player:GetNW2String("LS_Buff_" .. id, "")
            local x = ScrW() / 2
            local y = ScrH() - 62 - 22 - 26 - row * 24

            surface.SetFont("LS_HUDLabel")
            local width = surface.GetTextSize(text) + 24

            draw.RoundedBox(4, x - width / 2, y - 10, width, 20, panelColor)
            draw.SimpleText(text, "LS_HUDLabel", x, y, Color(255, 205, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            row = row + 1

        end

    end

end)
