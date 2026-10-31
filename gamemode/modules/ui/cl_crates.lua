-- Crate UI: the Crates tab of the vendor, and the roulette-style opening screen.

LS_UI = LS_UI or {}

surface.CreateFont("LS_CrateBig", {font = "Trebuchet24", size = 30, weight = 900})
surface.CreateFont("LS_CrateCell", {font = "Trebuchet18", size = 14, weight = 700})

local function rarityColor(rarity)
    return (LS_UI.RarityColors or {})[rarity] or color_white
end

local function humanize(name)
    return string.Trim(string.gsub(name, "(%u)", " %1"))
end

----------------------------------------------------------------------
-- Vendor tab: the crates for sale
----------------------------------------------------------------------

function LS_UI.BuildCratePanel(parent, width, height)

    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(width, height)
    panel.Paint = function() end

    local cardWidth, cardHeight, gap = 250, 272, 12

    for index, id in ipairs(LS_Crates.Order) do

        local crate = LS_Crates.Get(id)
        local odds = LS_Crates.GetOdds(crate)
        local color = crate.Color

        local card = vgui.Create("DPanel", panel)
        card:SetPos(18 + (index - 1) * (cardWidth + gap), 4)
        card:SetSize(cardWidth, cardHeight)
        card.Paint = function(self, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(15, 18, 24, 245))
            draw.RoundedBox(2, 2, 2, w - 4, h - 4, Color(color.r, color.g, color.b, 30))
            surface.SetDrawColor(color.r, color.g, color.b, 200)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local model = vgui.Create("DModelPanel", card)
        model:SetPos(6, 4)
        model:SetSize(cardWidth - 12, 84)
        model:SetMouseInputEnabled(false)
        LS_UI.ConfigureModel(model, "models/Items/item_item_crate.mdl", true, 0.7)

        local y = 92

        local function line(text, font, lineColor, lineHeight)
            local label = vgui.Create("DLabel", card)
            label:SetPos(12, y)
            label:SetSize(cardWidth - 24, lineHeight or 15)
            label:SetFont(font or "DermaDefault")
            label:SetTextColor(lineColor or Color(215, 220, 230))
            label:SetText(text)
            y = y + (lineHeight or 15)
        end

        line(crate.Name, "DermaDefaultBold", color, 18)

        local description = vgui.Create("DLabel", card)
        description:SetPos(12, y)
        description:SetSize(cardWidth - 24, 30)
        description:SetFont("DermaDefault")
        description:SetTextColor(Color(165, 175, 190))
        description:SetWrap(true)
        description:SetText(crate.Description)
        y = y + 34

        for _, rarity in ipairs(LS_Items.Rarities) do
            if odds[rarity] > 0 then
                local rarityLine = vgui.Create("DLabel", card)
                rarityLine:SetPos(12, y)
                rarityLine:SetSize(cardWidth - 24, 14)
                rarityLine:SetFont("DermaDefault")
                rarityLine:SetTextColor(rarityColor(rarity))
                rarityLine:SetText(string.format("%-10s %4.1f%%", rarity, odds[rarity]))
                y = y + 14
            end
        end

        if crate.Pity then
            line("Guaranteed " .. crate.Pity.Rarity .. "+ every " .. crate.Pity.Every .. " crates", "DermaDefault", Color(255, 205, 90), 16)
        end

        local open = vgui.Create("DButton", card)
        open:SetText("")
        open:SetPos(10, cardHeight - 38)
        open:SetSize(cardWidth - 20, 28)
        open.Paint = function(self, w, h)
            local affordable = LS_Currency.Get() >= crate.Price
            local tint = affordable and Color(255, 205, 90) or Color(210, 78, 75)

            draw.RoundedBox(3, 0, 0, w, h, Color(tint.r, tint.g, tint.b, self:IsHovered() and 255 or 190))
            draw.RoundedBox(2, 2, 2, w - 4, h - 4, Color(22, 25, 31, 225))
            draw.SimpleText("OPEN  " .. crate.Price .. " CR", "DermaDefaultBold", w / 2, h / 2, tint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        open.OnCursorEntered = function() surface.PlaySound("ui/buttonrollover.wav") end
        open.DoClick = function()
            if LS_Currency.Get() < crate.Price then
                surface.PlaySound("buttons/button10.wav")
                return
            end

            surface.PlaySound("buttons/button14.wav")
            net.Start("LS_CrateOpen")
                net.WriteString(crate.ID)
            net.SendToServer()
        end

    end

    return panel

end

----------------------------------------------------------------------
-- The opening screen
----------------------------------------------------------------------

local CELL_WIDTH, CELL_HEIGHT, CELL_GAP = 140, 120, 8
local CELL_STEP = CELL_WIDTH + CELL_GAP
local CELL_COUNT = 54
local WINNER_INDEX = 42
local SPIN_SECONDS = 6.5

local fillerNames

local function pickFillerName()

    if not fillerNames then

        fillerNames = {}

        for name in pairs(LS_Weapons.Data) do table.insert(fillerNames, name) end
        for _, definition in pairs(LS_Gadgets.Registered) do table.insert(fillerNames, definition.Name) end
        for _, definition in pairs(LS_Armor.Registered) do table.insert(fillerNames, definition.Name) end

    end

    return fillerNames[math.random(#fillerNames)]

end

local revealSounds = {
    Rare = "buttons/button17.wav",
    Epic = "buttons/button9.wav",
    Legendary = "ambient/energy/whiteflash.wav"
}

function LS_UI.OpenCrateReveal(crateID, item)

    if IsValid(LS_UI.CrateFrame) then
        LS_UI.CrateFrame:Remove()
    end

    local crate = LS_Crates.Get(crateID)

    if not crate then
        return
    end

    local frameWidth, frameHeight = 940, 480
    local stripX, stripY, stripWidth = 20, 78, frameWidth - 40

    -- Build the strip: filler cells with the real result at WINNER_INDEX.
    local cells = {}

    for index = 1, CELL_COUNT do
        cells[index] = {Rarity = LS_Items.GetWeightedRarity(crate.Weights), Name = pickFillerName()}
    end

    cells[WINNER_INDEX] = {Rarity = item.rarity, Name = (item.prefix or "") .. " " .. (item.weapon or "?"), Winner = true}

    -- A little tease: sometimes a Legendary sits right next to the prize.
    if item.rarity ~= "Legendary" and crate.Weights.Legendary and math.random() < 0.35 then
        cells[WINNER_INDEX + 1].Rarity = "Legendary"
    end

    local target = (WINNER_INDEX - 1) * CELL_STEP + CELL_WIDTH / 2 + math.Rand(-CELL_WIDTH * 0.32, CELL_WIDTH * 0.32)
    local startedAt = CurTime()
    local finished = false
    local lastCell = 0
    local flash = 0
    local modelPanel

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameWidth, frameHeight)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    LS_UI.CrateFrame = frame

    frame.Paint = function(self, width, height)

        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(crate.Color.r, crate.Color.g, crate.Color.b, 220)
        surface.DrawRect(0, 0, 5, height)
        draw.SimpleText(string.upper(crate.Name), "Trebuchet24", 28, 22, Color(245, 245, 248), TEXT_ALIGN_LEFT)
        draw.SimpleText(finished and "You received:" or "Opening...", "DermaDefault", 30, 52, Color(160, 170, 185), TEXT_ALIGN_LEFT)

        if finished then

            local color = rarityColor(item.rarity)
            local x = 300
            local y = 258

            draw.SimpleText(string.upper(item.rarity) .. "  •  " .. (item.slot or ""), "DermaDefaultBold", x, y, color)
            draw.SimpleText((item.prefix or "") .. " " .. (item.weapon or ""), "LS_CrateBig", x, y + 20, color)

            local lineY = y + 62

            for stat, value in SortedPairs(item.stats or {}) do
                draw.SimpleText(humanize(stat) .. "  +" .. value .. "%", "DermaDefault", x, lineY, Color(225, 228, 235))
                lineY = lineY + 16
            end

            for _, instance in ipairs(item.talents or {}) do
                local talent = LS_Talents.Get(instance.id)
                draw.SimpleText("• " .. (talent and talent.Name or instance.id), "DermaDefaultBold", x, lineY + 4, color)
                lineY = lineY + 18
            end

        end

        -- Reveal flash.
        if flash > 0 then
            local color = rarityColor(item.rarity)
            surface.SetDrawColor(color.r, color.g, color.b, 90 * flash)
            surface.DrawRect(0, 0, width, height)
            flash = math.max(0, flash - FrameTime() * 1.8)
        end

    end

    local strip = vgui.Create("DPanel", frame)
    strip:SetPos(stripX, stripY)
    strip:SetSize(stripWidth, CELL_HEIGHT + 20)

    local function currentOffset()
        local progress = math.Clamp((CurTime() - startedAt) / SPIN_SECONDS, 0, 1)

        -- Fast start, long slow-down.
        return target * (1 - (1 - progress) ^ 4), progress
    end

    local function reveal()

        if finished then
            return
        end

        finished = true
        flash = 1

        local color = rarityColor(item.rarity)

        surface.PlaySound(revealSounds[item.rarity] or "items/ammo_pickup.wav")

        if item.rarity == "Legendary" then
            surface.PlaySound("items/ammocrate_open.wav")
        end

        modelPanel = vgui.Create("DModelPanel", frame)
        modelPanel:SetPos(30, 250)
        modelPanel:SetSize(250, 170)
        modelPanel:SetMouseInputEnabled(false)
        LS_UI.ConfigureModel(modelPanel, LS_UI.WeaponModel(item), true, 0.4)

    end

    strip.Paint = function(self, width, height)

        draw.RoundedBox(4, 0, 0, width, height, Color(10, 12, 16, 255))

        local offset, progress = currentOffset()
        local screenX, screenY = self:LocalToScreen(0, 0)

        render.SetScissorRect(screenX, screenY, screenX + width, screenY + height, true)

        for index, cell in ipairs(cells) do

            local x = width / 2 - offset + (index - 1) * CELL_STEP

            if x > -CELL_WIDTH and x < width then

                local color = rarityColor(cell.Rarity)
                local highlight = finished and cell.Winner

                draw.RoundedBox(4, x, 10, CELL_WIDTH, CELL_HEIGHT, Color(18, 21, 28, 255))
                draw.RoundedBox(3, x + 2, 12, CELL_WIDTH - 4, CELL_HEIGHT - 4, Color(color.r, color.g, color.b, highlight and 120 or 45))
                surface.SetDrawColor(color.r, color.g, color.b, highlight and 255 or 170)
                surface.DrawOutlinedRect(x, 10, CELL_WIDTH, CELL_HEIGHT, highlight and 3 or 1)

                draw.SimpleText(cell.Name, "LS_CrateCell", x + CELL_WIDTH / 2, 10 + CELL_HEIGHT / 2 - 6, color_white,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(string.upper(cell.Rarity), "LS_CrateCell", x + CELL_WIDTH / 2, 10 + CELL_HEIGHT - 20, color,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            end

        end

        render.SetScissorRect(0, 0, 0, 0, false)

        -- Center line.
        surface.SetDrawColor(255, 205, 90, 255)
        surface.DrawRect(width / 2 - 1, 0, 3, height)

        -- A tick as each cell passes the center line.
        local passing = math.floor(offset / CELL_STEP) + 1

        if passing ~= lastCell then
            lastCell = passing

            if not finished then
                surface.PlaySound("ui/buttonrollover.wav")
            end
        end

        if progress >= 1 then
            reveal()
        end

    end

    local function button(text, x, width, onClick)
        local b = vgui.Create("DButton", frame)
        b:SetPos(x, frameHeight - 56)
        b:SetSize(width, 34)
        b:SetText("")
        b.Label = text
        b.DoClick = onClick
        b.Paint = function(self, w, h)
            local enabled = self:IsEnabled()
            local alpha = enabled and (self:IsHovered() and 255 or 190) or 70
            draw.RoundedBox(3, 0, 0, w, h, Color(255, 205, 90, alpha))
            draw.RoundedBox(2, 2, 2, w - 4, h - 4, Color(22, 25, 31, 230))
            draw.SimpleText(type(self.Label) == "function" and self.Label() or self.Label, "DermaDefaultBold", w / 2, h / 2,
                Color(255, 205, 90, enabled and 255 or 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return b
    end

    button("SKIP", 380, 130, function()
        startedAt = CurTime() - SPIN_SECONDS
    end)

    local again = button(function() return "OPEN ANOTHER  " .. crate.Price .. " CR" end, 520, 260, function()
        if finished and LS_Currency.Get() >= crate.Price then
            net.Start("LS_CrateOpen")
                net.WriteString(crate.ID)
            net.SendToServer()
        end
    end)

    again.Think = function(self)
        self:SetEnabled(finished and LS_Currency.Get() >= crate.Price)
    end

    button("CLOSE", 790, 130, function()
        frame:Remove()
    end)

end

net.Receive("LS_CrateResult", function()
    LS_UI.OpenCrateReveal(net.ReadString(), net.ReadTable())
end)
