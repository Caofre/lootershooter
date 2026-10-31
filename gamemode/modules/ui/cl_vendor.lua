LS_UI = LS_UI or {}

local function humanize(name)
    return string.Trim(string.gsub(name, "(%u)", " %1"))
end

function LS_UI.OpenVendor(vendor, vendorName, quiet, stock)
    local previous = LS_UI.VendorFrame
    local position
    if IsValid(previous) then
        position = {previous:GetPos()}
        previous:Remove()
    end

    local columns, rows = 3, 2
    local cardWidth, cardHeight, gap = 250, 272, 12
    local frameWidth = 36 + columns * cardWidth + (columns - 1) * gap
    local contentTop = 122
    local frameHeight = contentTop + 10 + rows * cardHeight + (rows - 1) * gap + 22

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameWidth, frameHeight)
    if position then frame:SetPos(position[1], position[2]) else frame:Center() end
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, width, height)
        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(255, 205, 90, 210)
        surface.DrawRect(0, 0, 5, height)
        draw.SimpleText(string.upper(vendorName or "Vendor"), "Trebuchet24", 28, 22, Color(245, 245, 248), TEXT_ALIGN_LEFT)
        draw.SimpleText(LS_UI.VendorTab == "crates" and "LOOT CRATES  •  Random gear, with guaranteed pity drops" or "GEAR FOR SALE  •  Stock changes after each completed contract",
            "DermaDefault", 30, 54, Color(160, 170, 185), TEXT_ALIGN_LEFT)
        draw.SimpleText(string.Comma(LS_Currency.Get()) .. " CR", "Trebuchet24", width - 70, 24, Color(255, 205, 90), TEXT_ALIGN_RIGHT)
    end
    LS_UI.VendorFrame = frame
    if not quiet then surface.PlaySound("buttons/button9.wav") end

    local close = vgui.Create("DButton", frame)
    close:SetText("×")
    close:SetFont("Trebuchet24")
    close:SetTextColor(Color(225, 230, 235))
    close:SetPos(frameWidth - 46, 11)
    close:SetSize(30, 26)
    close.Paint = function(self, width, height)
        if self:IsHovered() then draw.RoundedBox(3, 0, 0, width, height, Color(170, 65, 65, 180)) end
    end
    close.DoClick = function() frame:Remove() end

    local rarityColors = LS_UI.RarityColors or {}

    -- Two tabs share the window: the gear shelf and the loot crates.
    LS_UI.VendorTab = LS_UI.VendorTab or "gear"

    local gearPanel = vgui.Create("DPanel", frame)
    gearPanel:SetPos(0, contentTop - 4)
    gearPanel:SetSize(frameWidth, frameHeight - contentTop + 4)
    gearPanel.Paint = function() end

    local cratePanel = LS_UI.BuildCratePanel(frame, frameWidth, frameHeight - contentTop + 4)
    cratePanel:SetPos(0, contentTop - 4)

    local function showTab(tab)
        LS_UI.VendorTab = tab
        gearPanel:SetVisible(tab == "gear")
        cratePanel:SetVisible(tab == "crates")
    end

    for index, tab in ipairs({{"gear", "GEAR"}, {"crates", "CRATES"}}) do
        local tabButton = vgui.Create("DButton", frame)
        tabButton:SetText("")
        tabButton:SetPos(30 + (index - 1) * 130, 80)
        tabButton:SetSize(120, 28)
        tabButton.Paint = function(self, width, height)
            local active = LS_UI.VendorTab == tab[1]
            draw.RoundedBox(3, 0, 0, width, height, Color(255, 205, 90, active and 230 or (self:IsHovered() and 90 or 40)))
            draw.SimpleText(tab[2], "DermaDefaultBold", width / 2, height / 2, active and Color(16, 19, 25) or Color(215, 220, 230),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tabButton.DoClick = function()
            surface.PlaySound("buttons/button14.wav")
            showTab(tab[1])
        end
    end

    showTab(LS_UI.VendorTab)

    for index, entry in ipairs(stock or {}) do
        local item = entry.Item
        local color = rarityColors[item.rarity] or color_white
        local column, row = (index - 1) % columns, math.floor((index - 1) / columns)

        local card = vgui.Create("DPanel", gearPanel)
        card:SetPos(18 + column * (cardWidth + gap), 4 + row * (cardHeight + gap))
        card:SetSize(cardWidth, cardHeight)
        card.Paint = function(self, width, height)
            draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
            draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(color.r, color.g, color.b, entry.Sold and 14 or 34))
            surface.SetDrawColor(color.r, color.g, color.b, entry.Sold and 80 or 200)
            surface.DrawOutlinedRect(0, 0, width, height, 1)
        end

        local model = vgui.Create("DModelPanel", card)
        model:SetPos(6, 4)
        model:SetSize(cardWidth - 12, 96)
        model:SetMouseInputEnabled(false)
        LS_UI.ConfigureModel(model, LS_UI.WeaponModel(item), true, 0.45)

        local y = 104
        local function line(text, font, lineColor, height)
            local label = vgui.Create("DLabel", card)
            label:SetPos(12, y)
            label:SetSize(cardWidth - 24, height or 15)
            label:SetFont(font or "DermaDefault")
            label:SetTextColor(lineColor or Color(215, 220, 230))
            label:SetText(text)
            y = y + (height or 15)
        end

        line((item.prefix or "") .. " " .. (item.weapon or "Weapon"), "DermaDefaultBold", color, 18)
        line(string.upper(item.rarity or "") .. "  •  " .. (item.slot or ""), "DermaDefault", Color(155, 165, 180), 16)
        for stat, value in SortedPairs(item.stats or {}) do
            line(humanize(stat) .. "  +" .. value .. "%", "DermaDefault", Color(225, 228, 235), 14)
        end
        if #(item.talents or {}) > 0 then
            local names = {}
            for _, instance in ipairs(item.talents) do
                local talent = LS_Talents and LS_Talents.Get(instance.id)
                table.insert(names, talent and talent.Name or instance.id)
            end
            line("Talents: " .. table.concat(names, ", "), "DermaDefaultBold", color, 16)
        end

        local canAfford = LS_Currency.Get() >= entry.Price
        local buy = vgui.Create("DButton", card)
        buy:SetText("")
        buy:SetPos(10, cardHeight - 38)
        buy:SetSize(cardWidth - 20, 28)
        buy:SetEnabled(not entry.Sold)
        buy.Paint = function(self, width, height)
            local tint = entry.Sold and Color(90, 95, 105) or (canAfford and Color(255, 205, 90) or Color(210, 78, 75))
            local alpha = entry.Sold and 80 or (self:IsHovered() and 255 or 190)
            draw.RoundedBox(3, 0, 0, width, height, Color(tint.r, tint.g, tint.b, alpha))
            draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, 225))
            draw.SimpleText(entry.Sold and "SOLD" or ("BUY  " .. entry.Price .. " CR"), "DermaDefaultBold", width / 2, height / 2,
                Color(tint.r, tint.g, tint.b, entry.Sold and 150 or 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        buy.OnCursorEntered = function() if not entry.Sold then surface.PlaySound("ui/buttonrollover.wav") end end
        buy.DoClick = function()
            if not canAfford then surface.PlaySound("buttons/button10.wav") end
            net.Start("LS_VendorBuy")
                net.WriteUInt(index, 8)
            net.SendToServer()
        end
    end
end

net.Receive("LS_OpenVendor", function()
    LS_UI.OpenVendor(net.ReadEntity(), net.ReadString(), net.ReadBool(), net.ReadTable())
end)
