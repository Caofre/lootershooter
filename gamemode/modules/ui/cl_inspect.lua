LS_UI = LS_UI or {}
LS_UI.Inspect = LS_UI.Inspect or {}

local inspect = LS_UI.Inspect

surface.CreateFont("LS_InspectTitle", {
    font = "Trebuchet24",
    size = 23,
    weight = 800
})

surface.CreateFont("LS_InspectHeading", {
    font = "Trebuchet24",
    size = 15,
    weight = 800
})

surface.CreateFont("LS_InspectBody", {
    font = "Trebuchet18",
    size = 14,
    weight = 600
})

inspect.Active = false
inspect.Alpha = 0
inspect.View = inspect.View or {Yaw = 0, Pitch = 0, Right = 0, Forward = 0}

local rarityColors = {
    Common = Color(200, 200, 200),
    Uncommon = Color(60, 225, 95),
    Rare = Color(65, 145, 255),
    Epic = Color(190, 80, 255),
    Legendary = Color(255, 155, 45)
}

local function lerpColor(amount, from, to)
    return Color(
        Lerp(amount, from.r, to.r),
        Lerp(amount, from.g, to.g),
        Lerp(amount, from.b, to.b),
        Lerp(amount, from.a or 255, to.a or 255)
    )
end

local function getEquippedItem()
    local player = LocalPlayer()

    if not IsValid(player) or not LS_ClientInventory or not LS_ClientEquipment then
        return nil
    end

    local weapon = player:GetActiveWeapon()

    if not IsValid(weapon) then
        return nil
    end

    for _, itemID in pairs(LS_ClientEquipment) do
        for _, item in ipairs(LS_ClientInventory) do
            if item.id == itemID and item.class == weapon:GetClass() then
                return item, weapon
            end
        end
    end

    return nil
end

local function statLabel(name)
    return string.Trim(string.gsub(name, "(%u)", " %1"))
end

local function rollSuffix(name)
    local percentRolls = {
        Chance = true,
        DamagePercent = true,
        LifeSteal = true,
        Slow = true
    }

    return percentRolls[name] and "%" or ""
end

function inspect.SetActive(active)
    if active then
        local item = getEquippedItem()

        if not item then
            chat.AddText(Color(255, 180, 70), "[LS] Equip a Looter Shooter weapon before inspecting it.")
            return
        end
    end

    inspect.Active = active
end

concommand.Add("ls_inspect", function()
    inspect.SetActive(not inspect.Active)
end)

hook.Add("PlayerSwitchWeapon", "LS_InspectStopOnSwitch", function(player)
    if player == LocalPlayer() then
        inspect.SetActive(false)
    end
end)

hook.Add("Think", "LS_InspectCombatCancel", function()
    if not inspect.Active then
        return
    end

    local player = LocalPlayer()

    if not IsValid(player) or player:KeyDown(IN_ATTACK) or
        player:KeyDown(IN_ATTACK2) or player:KeyDown(IN_RELOAD) then
        inspect.SetActive(false)
    end
end)

hook.Add("CalcViewModelView", "LS_InspectViewModel", function(weapon, viewModel, oldPosition, oldAngle, position, angle)
    -- Keep the weapon on the left for the common CSS-derived viewmodels.
    -- Their unmodelled side is less noticeable there and it leaves the HUD
    -- card a clean, separate space on the right.
    local target = inspect.Active and {Yaw = 38, Pitch = 12, Right = 9, Forward = -5} or
        {Yaw = 0, Pitch = 0, Right = 0, Forward = 0}

    if weapon.ViewModelFlip then
        target.Yaw = -target.Yaw
        target.Right = -target.Right
    end

    local speed = math.min(FrameTime() * 7, 1)
    local view = inspect.View
    view.Yaw = Lerp(speed, view.Yaw, target.Yaw)
    view.Pitch = Lerp(speed, view.Pitch, target.Pitch)
    view.Right = Lerp(speed, view.Right, target.Right)
    view.Forward = Lerp(speed, view.Forward, target.Forward)

    if math.abs(view.Yaw) < 0.01 and math.abs(view.Pitch) < 0.01 and
        math.abs(view.Right) < 0.01 and math.abs(view.Forward) < 0.01 then
        return
    end

    local displayAngle = Angle(angle.p, angle.y, angle.r)
    displayAngle:RotateAroundAxis(displayAngle:Up(), view.Yaw)
    displayAngle:RotateAroundAxis(displayAngle:Right(), view.Pitch)

    local displayPosition = position + displayAngle:Right() * view.Right +
        displayAngle:Forward() * view.Forward

    return displayPosition, displayAngle
end)

hook.Add("HUDPaint", "LS_InspectStats", function()
    local fadeSpeed = math.min(FrameTime() * 8, 1)
    inspect.Alpha = Lerp(fadeSpeed, inspect.Alpha, inspect.Active and 255 or 0)

    if inspect.Alpha < 1 then
        return
    end

    local item = getEquippedItem()

    if not item then
        inspect.SetActive(false)
        return
    end

    local cardWidth, textWidth = 380, 340
    local cardX = math.floor(ScrW() * 0.60)
    local cardY = math.floor(ScrH() * 0.20)
    local viewModel = LocalPlayer():GetViewModel()

    if IsValid(viewModel) then
        local attachment = viewModel:GetAttachment(viewModel:LookupAttachment("muzzle")) or
            viewModel:GetAttachment(1)

        if attachment then
            local screenPosition = attachment.Pos:ToScreen()
            cardX = math.Clamp(
                math.floor(screenPosition.x + 115),
                math.floor(ScrW() * 0.50),
                ScrW() - cardWidth - 24
            )
            cardY = math.floor(screenPosition.y - 70)
        end
    end

    -- Build the card as a list of lines first, so its height fits what it says.
    local lines = {}

    local function add(text, font, color, indent, rightText)
        table.insert(lines, {Text = text, Font = font, Color = color, Indent = indent or 0, Right = rightText})
    end

    local dim, bright = Color(170, 180, 195), Color(245, 245, 248)

    add("MODIFIERS", "LS_InspectHeading", dim)

    local hasStats = false

    for stat, value in SortedPairs(item.stats or {}) do
        add(statLabel(stat), "LS_InspectBody", Color(220, 220, 225), 0, "+" .. value .. "%")
        hasStats = true
    end

    if not hasStats then
        add("No rolled modifiers", "LS_InspectBody", Color(185, 185, 190))
    end

    local talents = item.talents or {}

    if #talents > 0 then
        add("", "LS_InspectBody", dim)
        add("TALENTS", "LS_InspectHeading", dim)

        for _, instance in ipairs(talents) do
            local talent = LS_Talents and LS_Talents.Get(instance.id)

            add(talent and talent.Name or instance.id, "LS_InspectHeading", bright, 0)

            -- What the talent does, then its rolled values.
            if talent and talent.Description then
                for _, line in ipairs(LS_Talents.WrapLines(talent.Description, "LS_InspectBody", textWidth - 14)) do
                    add(line, "LS_InspectBody", Color(160, 170, 185), 10)
                end
            end

            for rollName, value in SortedPairs(instance.rolls or {}) do
                add(LS_Talents.RollLabel(rollName), "LS_InspectBody", Color(190, 195, 205), 10,
                    LS_Talents.FormatRoll(instance.id, rollName, value))
            end
        end
    end

    local lineHeight = 17
    local height = 100 + #lines * lineHeight + 30

    height = math.min(height, ScrH() - 48)
    cardY = math.Clamp(cardY, 24, ScrH() - height - 24)

    local alpha = math.floor(inspect.Alpha)
    local rarity = rarityColors[item.rarity] or color_white
    local accent = Color(rarity.r, rarity.g, rarity.b, alpha)
    local background = Color(19, 22, 28, math.floor(alpha * 0.94))
    local inner = Color(37, 41, 49, math.floor(alpha * 0.96))

    draw.RoundedBox(5, cardX, cardY, cardWidth, height, background)
    draw.RoundedBox(3, cardX + 3, cardY + 3, cardWidth - 6, height - 6, inner)
    surface.SetDrawColor(accent)
    surface.DrawRect(cardX, cardY, 6, height)
    surface.SetDrawColor(lerpColor(0.35, rarity, Color(255, 255, 255, alpha)))
    surface.DrawOutlinedRect(cardX, cardY, cardWidth, height, 1)

    draw.SimpleText(string.upper(item.rarity or "Common"), "LS_InspectHeading", cardX + 18, cardY + 14, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText((item.prefix or "") .. " " .. (item.weapon or "Weapon"), "LS_InspectTitle", cardX + 18, cardY + 34, Color(245, 245, 248, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local y = cardY + 68
    surface.SetDrawColor(255, 255, 255, math.floor(alpha * 0.12))
    surface.DrawRect(cardX + 18, y, cardWidth - 36, 1)
    y = y + 12

    local limit = cardY + height - 30

    for _, line in ipairs(lines) do
        if y + lineHeight > limit then
            break
        end

        draw.SimpleText(line.Text, line.Font, cardX + 18 + line.Indent, y,
            Color(line.Color.r, line.Color.g, line.Color.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if line.Right then
            draw.SimpleText(line.Right, "LS_InspectBody", cardX + cardWidth - 20, y, accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        y = y + lineHeight
    end

    draw.SimpleText("ls_inspect to close  •  combat input cancels", "LS_InspectBody", cardX + 18, cardY + height - 23, Color(160, 165, 175, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
