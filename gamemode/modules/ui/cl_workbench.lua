-- Workbench UI. Two modes:
--   CRAFT    pick an item and a rarity, see the cost, and craft it
--   REFORGE  pick an item you own and reroll its stats or talents

LS_UI = LS_UI or {}

local function rarityColor(rarity)
    return (LS_UI.RarityColors or {})[rarity] or color_white
end

local function findItem(itemID)

    for _, item in ipairs(LS_ClientInventory or {}) do
        if item.id == itemID then
            return item
        end
    end

end

local function listEntries(kind)

    local entries = {}

    if kind == "weapon" then

        for name, data in SortedPairs(LS_Weapons.Data) do
            table.insert(entries, {
                Kind = "weapon", ID = name, Name = name,
                Sub = (data.archetype or "") .. "  •  " .. (data.slot or ""),
                Item = {class = data.class}
            })
        end

    elseif kind == "gadget" then

        for _, id in ipairs(LS_Gadgets.Order) do
            local definition = LS_Gadgets.Get(id)

            table.insert(entries, {
                Kind = "gadget", ID = id, Name = definition.Name, Sub = "GADGET",
                Description = definition.Description, Item = {gadget = id}
            })
        end

    else

        for _, id in ipairs(LS_Armor.Order) do
            local definition = LS_Armor.Get(id)

            table.insert(entries, {
                Kind = "armor", ID = id, Name = definition.Name, Sub = "ARMOR",
                Description = definition.Description, Item = {armor = id}
            })
        end

    end

    return entries

end

-- Stats and talents of an item, as used by the crafting result card.
local function drawItemCard(item, x, y, width)

    local color = rarityColor(item.rarity)

    draw.SimpleText(string.upper(item.rarity) .. "  •  " .. (item.slot or ""), "DermaDefaultBold", x, y, color)
    draw.SimpleText((item.prefix or "") .. " " .. (item.weapon or ""), "Trebuchet24", x, y + 16, color)

    local lineY = y + 52

    for stat, value in SortedPairs(item.stats or {}) do
        draw.SimpleText(LS_Talents.RollLabel(stat) .. "  +" .. value .. "%", "DermaDefault", x, lineY, Color(225, 228, 235))
        lineY = lineY + 16
    end

    for _, instance in ipairs(item.talents or {}) do

        local talent = LS_Talents.Get(instance.id)

        lineY = lineY + 6
        draw.SimpleText(talent and talent.Name or instance.id, "DermaDefaultBold", x, lineY, color)
        lineY = lineY + 16

        if talent then
            for _, line in ipairs(LS_Talents.WrapLines(talent.Description, "DermaDefault", width)) do
                draw.SimpleText(line, "DermaDefault", x, lineY, Color(165, 175, 190))
                lineY = lineY + 14
            end
        end

        for roll, value in SortedPairs(instance.rolls or {}) do
            draw.SimpleText("  " .. LS_Talents.RollLabel(roll) .. ": " .. LS_Talents.FormatRoll(instance.id, roll, value),
                "DermaDefault", x, lineY, Color(205, 210, 220))
            lineY = lineY + 14
        end

    end

end

local function drawCostLines(width, startY, cost, lineHeight)

    local y = startY

    local function line(label, need, have, color)
        local tint = have >= need and Color(120, 220, 130) or Color(225, 90, 80)

        draw.SimpleText(label, "DermaDefault", 14, y, color or Color(215, 220, 230))
        draw.SimpleText(string.Comma(have) .. " / " .. string.Comma(need), "DermaDefaultBold", width - 14, y, tint, TEXT_ALIGN_RIGHT)
        y = y + lineHeight
    end

    line("Credits", cost.Credits, LS_Currency.Get(), Color(255, 205, 90))

    for _, id in ipairs(LS_Components.Order) do
        if (cost[id] or 0) > 0 then
            line(LS_Components.Names[id], cost[id], LS_Components.Get(id), LS_Components.Colors[id])
        end
    end

end

local function canAfford(cost)

    if LS_Currency.Get() < cost.Credits then
        return false
    end

    for _, id in ipairs(LS_Components.Order) do
        if (cost[id] or 0) > LS_Components.Get(id) then
            return false
        end
    end

    return true

end

local function bigButton(parent, x, y, width, height, onClick)

    local button = vgui.Create("DButton", parent)
    button:SetText("")
    button:SetPos(x, y)
    button:SetSize(width, height)
    button.DoClick = onClick

    return button

end

function LS_UI.OpenWorkbench()

    if IsValid(LS_UI.WorkbenchFrame) then
        LS_UI.WorkbenchFrame:Remove()
    end

    local frameWidth, frameHeight = 940, math.min(650, ScrH() - 40)

    local frame = vgui.Create("DFrame")
    frame:SetSize(frameWidth, frameHeight)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    LS_UI.WorkbenchFrame = frame

    local mode = LS_UI.WorkbenchMode or "craft"
    local groups = {craft = {}, reforge = {}}

    -- Widgets belong to a mode and are shown or hidden with it.
    local function track(group, panel)
        table.insert(groups[group], panel)
        return panel
    end

    frame.Paint = function(self, width, height)

        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(120, 190, 255, 220)
        surface.DrawRect(0, 0, 5, height)

        draw.SimpleText("WORKBENCH", "Trebuchet24", 28, 14, Color(245, 245, 248))
        draw.SimpleText(mode == "craft" and "Craft a specific item. Its rarity is guaranteed; its rolls are random."
            or "Reroll an item you own. Click a stat or talent to lock it, so it is kept.", "DermaDefault", 30, 44, Color(160, 170, 185))

        local x = width - 70

        draw.SimpleText(string.Comma(LS_Currency.Get()) .. " CR", "Trebuchet18", x, 16, Color(255, 205, 90), TEXT_ALIGN_RIGHT)
        x = x - 110

        for index = #LS_Components.Order, 1, -1 do
            local id = LS_Components.Order[index]

            draw.SimpleText(LS_Components.Names[id] .. " " .. LS_Components.Get(id), "Trebuchet18", x, 16, LS_Components.Colors[id], TEXT_ALIGN_RIGHT)
            x = x - 110
        end

    end

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

    local function setMode(newMode)

        mode = newMode
        LS_UI.WorkbenchMode = newMode

        for name, panels in pairs(groups) do
            for _, panel in ipairs(panels) do
                if IsValid(panel) then
                    panel:SetVisible(name == newMode)
                end
            end
        end

    end

    for index, definition in ipairs({{"craft", "CRAFT"}, {"reforge", "REFORGE"}}) do

        local button = bigButton(frame, 24 + (index - 1) * 132, 72, 126, 28, function()
            surface.PlaySound("buttons/button14.wav")
            setMode(definition[1])
        end)

        button.Paint = function(self, width, height)
            local active = mode == definition[1]
            draw.RoundedBox(3, 0, 0, width, height, Color(255, 205, 90, active and 230 or (self:IsHovered() and 90 or 40)))
            draw.SimpleText(definition[2], "DermaDefaultBold", width / 2, height / 2,
                active and Color(16, 19, 25) or Color(215, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

    end

    local top = 114
    local rightX = 348
    local rightWidth = frameWidth - rightX - 24
    local bottom = frameHeight - 20

    ------------------------------------------------------------------
    -- CRAFT mode
    ------------------------------------------------------------------

    local craftTab, craftSelected, craftRarity = "weapon", nil, "Rare"
    local craftList

    local craftPreview = track("craft", vgui.Create("DModelPanel", frame))
    craftPreview:SetPos(rightX, top)
    craftPreview:SetSize(240, 190)
    craftPreview:SetMouseInputEnabled(false)

    local function refreshCraftPreview()

        if craftSelected then
            LS_UI.ConfigureModel(craftPreview, LS_UI.WeaponModel(craftSelected.Item), true, 0.4)
        else
            craftPreview:SetModel("models/props_junk/PopCan01a.mdl")
        end

    end

    local function rebuildCraftList()

        craftList:Clear()

        for _, entry in ipairs(listEntries(craftTab)) do

            local row = craftList:Add("DButton")
            row:SetText("")
            row:Dock(TOP)
            row:DockMargin(0, 0, 4, 4)
            row:SetTall(46)
            row.Paint = function(self, width, height)
                local active = craftSelected and craftSelected.ID == entry.ID and craftSelected.Kind == entry.Kind
                draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(120, 190, 255, active and 70 or (self:IsHovered() and 40 or 12)))
                surface.SetDrawColor(120, 190, 255, active and 255 or 90)
                surface.DrawOutlinedRect(0, 0, width, height, active and 2 or 1)
                draw.SimpleText(entry.Name, "DermaDefaultBold", 12, 10, Color(245, 245, 248))
                draw.SimpleText(entry.Sub, "DermaDefault", 12, 26, Color(155, 165, 180))
            end
            row.DoClick = function()
                craftSelected = entry
                surface.PlaySound("buttons/button15.wav")
                refreshCraftPreview()
            end

        end

    end

    for index, definition in ipairs({{"weapon", "WEAPONS"}, {"gadget", "GADGETS"}, {"armor", "ARMOR"}}) do

        local button = track("craft", bigButton(frame, 24 + (index - 1) * 98, top, 94, 26, function()
            craftTab = definition[1]
            craftSelected = nil
            surface.PlaySound("buttons/button14.wav")
            rebuildCraftList()
            refreshCraftPreview()
        end))

        button.Paint = function(self, width, height)
            local active = craftTab == definition[1]
            draw.RoundedBox(3, 0, 0, width, height, Color(120, 190, 255, active and 230 or (self:IsHovered() and 90 or 40)))
            draw.SimpleText(definition[2], "DermaDefaultBold", width / 2, height / 2,
                active and Color(16, 19, 25) or Color(215, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

    end

    craftList = track("craft", vgui.Create("DScrollPanel", frame))
    craftList:SetPos(24, top + 34)
    craftList:SetSize(300, bottom - top - 34)

    local craftInfo = track("craft", vgui.Create("DPanel", frame))
    craftInfo:SetPos(rightX + 250, top)
    craftInfo:SetSize(rightWidth - 250, 190)
    craftInfo.Paint = function(self, width, height)

        if not craftSelected then
            draw.SimpleText("Select an item to craft.", "DermaDefault", 0, 4, Color(160, 170, 185))
            return
        end

        draw.SimpleText(craftSelected.Name, "Trebuchet24", 0, 0, Color(245, 245, 248))
        draw.SimpleText(craftSelected.Sub, "DermaDefaultBold", 0, 28, Color(155, 165, 180))

        local y = 52

        if craftSelected.Description then
            for _, line in ipairs(LS_Talents.WrapLines(craftSelected.Description, "DermaDefault", width)) do
                draw.SimpleText(line, "DermaDefault", 0, y, Color(185, 195, 210))
                y = y + 15
            end
        end

    end

    local rarityY = top + 206

    for index, rarity in ipairs(LS_Items.Rarities) do

        local width = math.floor((rightWidth + 6) / 5)

        local button = track("craft", bigButton(frame, rightX + (index - 1) * width, rarityY, width - 6, 32, function()
            craftRarity = rarity
            surface.PlaySound("buttons/button15.wav")
        end))

        button.Paint = function(self, w, h)
            local color = rarityColor(rarity)
            local active = craftRarity == rarity

            draw.RoundedBox(3, 0, 0, w, h, Color(color.r, color.g, color.b, active and 230 or (self:IsHovered() and 110 or 55)))
            draw.SimpleText(string.upper(rarity), "DermaDefaultBold", w / 2, h / 2,
                active and Color(16, 19, 25) or color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

    end

    local craftCost = track("craft", vgui.Create("DPanel", frame))
    craftCost:SetPos(rightX, rarityY + 46)
    craftCost:SetSize(rightWidth, 150)
    craftCost.Paint = function(self, width, height)

        draw.RoundedBox(4, 0, 0, width, height, Color(20, 23, 30, 245))
        draw.SimpleText("COST", "DermaDefaultBold", 14, 10, Color(170, 180, 195))
        drawCostLines(width, 34, LS_Crafting.Costs[craftRarity], 22)

    end

    local function canCraft()
        return craftSelected ~= nil and canAfford(LS_Crafting.Costs[craftRarity])
    end

    local craftButton = track("craft", bigButton(frame, rightX, bottom - 46, rightWidth, 46, function()

        if not canCraft() then
            surface.PlaySound("buttons/button10.wav")
            return
        end

        surface.PlaySound("buttons/button14.wav")

        net.Start("LS_CraftItem")
            net.WriteString(craftSelected.Kind)
            net.WriteString(craftSelected.ID)
            net.WriteUInt(table.KeyFromValue(LS_Items.Rarities, craftRarity), 3)
        net.SendToServer()

    end))

    craftButton.Paint = function(self, width, height)
        local enabled = canCraft()
        local color = rarityColor(craftRarity)

        draw.RoundedBox(3, 0, 0, width, height, Color(color.r, color.g, color.b, enabled and (self:IsHovered() and 255 or 200) or 70))
        draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, enabled and 230 or 160))
        draw.SimpleText(craftSelected and ("CRAFT " .. string.upper(craftRarity) .. " " .. string.upper(craftSelected.Name)) or "SELECT AN ITEM",
            "Trebuchet18", width / 2, height / 2, Color(color.r, color.g, color.b, enabled and 255 or 110),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    rebuildCraftList()
    refreshCraftPreview()

    ------------------------------------------------------------------
    -- REFORGE mode
    ------------------------------------------------------------------

    local rfItemID, rfAction, rfLock = nil, 1, nil
    local rfList, rfRolls
    local rebuildReforge

    local function rfItem()
        return rfItemID and findItem(rfItemID)
    end

    -- Is the chosen lock meaningful for the chosen action?
    local function lockActive(item)

        local action = LS_Crafting.ReforgeActions[rfAction]

        if not item or not rfLock or not action.Lockable or rfLock.Type ~= action.Lockable then
            return false
        end

        if rfLock.Type == "stat" then
            return item.stats and item.stats[rfLock.Key] ~= nil
        end

        for _, instance in ipairs(item.talents or {}) do
            if instance.id == rfLock.Key then
                return true
            end
        end

        return false

    end

    local function actionAvailable(item, index)

        local action = LS_Crafting.ReforgeActions[index]

        return item ~= nil and (not action.NeedsTalents or #(item.talents or {}) > 0)

    end

    local rfPreview = track("reforge", vgui.Create("DModelPanel", frame))
    rfPreview:SetPos(rightX, top)
    rfPreview:SetSize(200, 150)
    rfPreview:SetMouseInputEnabled(false)

    local rfInfo = track("reforge", vgui.Create("DPanel", frame))
    rfInfo:SetPos(rightX + 210, top)
    rfInfo:SetSize(rightWidth - 210, 150)
    rfInfo.Paint = function(self, width, height)

        local item = rfItem()

        if not item then
            draw.SimpleText("Select an item to reforge.", "DermaDefault", 0, 4, Color(160, 170, 185))
            return
        end

        local color = rarityColor(item.rarity)

        draw.SimpleText(string.upper(item.rarity) .. "  •  " .. (item.slot or ""), "DermaDefaultBold", 0, 0, color)
        draw.SimpleText((item.prefix or "") .. " " .. (item.weapon or ""), "Trebuchet24", 0, 16, color)

        if LS_ClientIsEquipped(item.id) then
            draw.SimpleText("EQUIPPED - changes apply immediately", "DermaDefault", 0, 50, Color(120, 220, 130))
        end

    end

    local function rebuildReforgeList()

        rfList:Clear()

        local items = table.Copy(LS_ClientInventory or {})

        local rank = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5}

        table.sort(items, function(a, b)
            if rank[a.rarity] ~= rank[b.rarity] then return (rank[a.rarity] or 0) > (rank[b.rarity] or 0) end
            return a.id > b.id
        end)

        for _, item in ipairs(items) do

            local row = rfList:Add("DButton")
            row:SetText("")
            row:Dock(TOP)
            row:DockMargin(0, 0, 4, 4)
            row:SetTall(40)
            row.Paint = function(self, width, height)
                local color = rarityColor(item.rarity)
                local active = rfItemID == item.id

                draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(color.r, color.g, color.b, active and 80 or (self:IsHovered() and 50 or 22)))
                surface.SetDrawColor(color.r, color.g, color.b, active and 255 or 120)
                surface.DrawOutlinedRect(0, 0, width, height, active and 2 or 1)
                draw.SimpleText((item.prefix or "") .. " " .. (item.weapon or ""), "DermaDefaultBold", 10, 8, color)
                draw.SimpleText(string.upper(item.rarity) .. "  •  " .. (item.slot or "") ..
                    (LS_ClientIsEquipped(item.id) and "  •  EQUIPPED" or ""), "DermaDefault", 10, 23, Color(155, 165, 180))
            end
            row.DoClick = function()
                rfItemID = item.id
                rfLock = nil
                surface.PlaySound("buttons/button15.wav")
                rebuildReforge()
            end

        end

    end

    local function rebuildRolls()

        rfRolls:Clear()

        local item = rfItem()

        if not item then
            return
        end

        local color = rarityColor(item.rarity)

        local function header(text)
            local label = rfRolls:Add("DLabel")
            label:Dock(TOP)
            label:DockMargin(6, 4, 6, 2)
            label:SetTall(18)
            label:SetFont("DermaDefaultBold")
            label:SetTextColor(Color(170, 180, 195))
            label:SetText(text)
        end

        header("STATS")

        local statCount = 0

        for stat, value in SortedPairs(item.stats or {}) do

            statCount = statCount + 1

            local row = rfRolls:Add("DButton")
            row:SetText("")
            row:Dock(TOP)
            row:DockMargin(4, 0, 4, 2)
            row:SetTall(24)
            row.Paint = function(self, width, height)
                local locked = rfLock and rfLock.Type == "stat" and rfLock.Key == stat

                draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                draw.RoundedBox(2, 1, 1, width - 2, height - 2, Color(120, 190, 255, locked and 70 or (self:IsHovered() and 35 or 10)))
                draw.SimpleText(LS_Talents.RollLabel(stat), "DermaDefault", 10, height / 2, Color(225, 228, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("+" .. value .. "%", "DermaDefaultBold", width - (locked and 80 or 12), height / 2, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                if locked then
                    draw.SimpleText("LOCKED", "DermaDefaultBold", width - 12, height / 2, Color(120, 190, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            row.DoClick = function()
                local same = rfLock and rfLock.Type == "stat" and rfLock.Key == stat
                rfLock = not same and {Type = "stat", Key = stat} or nil
                rfAction = 2
                surface.PlaySound("buttons/button15.wav")
            end

        end

        if statCount == 0 then
            header("(no stats)")
        end

        if #(item.talents or {}) > 0 then

            header("TALENTS")

            for _, instance in ipairs(item.talents) do

                local talent = LS_Talents.Get(instance.id)
                local lines = talent and LS_Talents.WrapLines(talent.Description, "DermaDefault", rightWidth - 40) or {}
                local rollParts = {}

                for roll, value in SortedPairs(instance.rolls or {}) do
                    table.insert(rollParts, LS_Talents.RollLabel(roll) .. " " .. LS_Talents.FormatRoll(instance.id, roll, value))
                end

                local rollText = table.concat(rollParts, "  •  ")

                local row = rfRolls:Add("DButton")
                row:SetText("")
                row:Dock(TOP)
                row:DockMargin(4, 0, 4, 2)
                row:SetTall(24 + #lines * 14 + 16)
                row.Paint = function(self, width, height)
                    local locked = rfLock and rfLock.Type == "talent" and rfLock.Key == instance.id

                    draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                    draw.RoundedBox(2, 1, 1, width - 2, height - 2, Color(120, 190, 255, locked and 70 or (self:IsHovered() and 35 or 10)))
                    draw.SimpleText(talent and talent.Name or instance.id, "DermaDefaultBold", 10, 6, color)

                    if locked then
                        draw.SimpleText("LOCKED", "DermaDefaultBold", width - 12, 6, Color(120, 190, 255), TEXT_ALIGN_RIGHT)
                    end

                    local y = 24

                    for _, line in ipairs(lines) do
                        draw.SimpleText(line, "DermaDefault", 10, y, Color(165, 175, 190))
                        y = y + 14
                    end

                    draw.SimpleText(rollText, "DermaDefault", 10, y + 2, Color(205, 210, 220))
                end
                row.DoClick = function()
                    local same = rfLock and rfLock.Type == "talent" and rfLock.Key == instance.id
                    rfLock = not same and {Type = "talent", Key = instance.id} or nil
                    rfAction = 4
                    surface.PlaySound("buttons/button15.wav")
                end

            end

        end

    end

    rfList = track("reforge", vgui.Create("DScrollPanel", frame))
    rfList:SetPos(24, top)
    rfList:SetSize(300, bottom - top)

    rfRolls = track("reforge", vgui.Create("DScrollPanel", frame))
    rfRolls:SetPos(rightX, top + 158)
    rfRolls:SetSize(rightWidth, 150)

    local actionWidth = math.floor((rightWidth + 6) / 4)

    for index, action in ipairs(LS_Crafting.ReforgeActions) do

        local button = track("reforge", bigButton(frame, rightX + (index - 1) * actionWidth, top + 316, actionWidth - 6, 30, function()

            if not actionAvailable(rfItem(), index) then
                surface.PlaySound("buttons/button10.wav")
                return
            end

            rfAction = index
            surface.PlaySound("buttons/button15.wav")

        end))

        button.Paint = function(self, width, height)
            local active = rfAction == index
            local enabled = actionAvailable(rfItem(), index)

            draw.RoundedBox(3, 0, 0, width, height, Color(255, 205, 90, enabled and (active and 230 or (self:IsHovered() and 90 or 45)) or 20))
            draw.SimpleText(action.Name, "DermaDefaultBold", width / 2, height / 2,
                active and enabled and Color(16, 19, 25) or Color(215, 220, 230, enabled and 255 or 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

    end

    local actionText = track("reforge", vgui.Create("DPanel", frame))
    actionText:SetPos(rightX, top + 350)
    actionText:SetSize(rightWidth, 22)
    actionText.Paint = function(self, width, height)
        draw.SimpleText(LS_Crafting.ReforgeActions[rfAction].Description, "DermaDefault", 2, 4, Color(185, 195, 210))
    end

    local function currentCost()

        local item = rfItem()

        return item and LS_Crafting.GetReforgeCost(item.rarity, rfAction, lockActive(item))

    end

    local rfCost = track("reforge", vgui.Create("DPanel", frame))
    rfCost:SetPos(rightX, top + 378)
    rfCost:SetSize(rightWidth, 90)
    rfCost.Paint = function(self, width, height)

        draw.RoundedBox(4, 0, 0, width, height, Color(20, 23, 30, 245))

        local cost = currentCost()

        if not cost then
            draw.SimpleText("Select an item.", "DermaDefault", 14, 12, Color(160, 170, 185))
            return
        end

        local locked = lockActive(rfItem())

        draw.SimpleText(locked and "COST (lock adds 50%)" or "COST", "DermaDefaultBold", 14, 6, Color(170, 180, 195))
        drawCostLines(width, 24, cost, 16)

    end

    local function canReforge()

        local item, cost = rfItem(), currentCost()

        return item ~= nil and cost ~= nil and actionAvailable(item, rfAction) and canAfford(cost)

    end

    local rfButton = track("reforge", bigButton(frame, rightX, bottom - 44, rightWidth, 44, function()

        if not canReforge() then
            surface.PlaySound("buttons/button10.wav")
            return
        end

        surface.PlaySound("buttons/button14.wav")

        net.Start("LS_ReforgeItem")
            net.WriteUInt(rfItemID, 16)
            net.WriteUInt(rfAction, 3)
            net.WriteString(lockActive(rfItem()) and rfLock.Key or "")
        net.SendToServer()

    end))

    rfButton.Paint = function(self, width, height)
        local enabled = canReforge()

        draw.RoundedBox(3, 0, 0, width, height, Color(255, 205, 90, enabled and (self:IsHovered() and 255 or 200) or 70))
        draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, enabled and 230 or 160))
        draw.SimpleText(rfItem() and ("REFORGE: " .. LS_Crafting.ReforgeActions[rfAction].Name) or "SELECT AN ITEM",
            "Trebuchet18", width / 2, height / 2, Color(255, 205, 90, enabled and 255 or 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    rebuildReforge = function()

        if rfItemID and not findItem(rfItemID) then
            rfItemID, rfLock = nil, nil
        end

        local item = rfItem()

        if item then
            LS_UI.ConfigureModel(rfPreview, LS_UI.WeaponModel(item), true, 0.4)

            if not actionAvailable(item, rfAction) then
                rfAction = 1
            end
        else
            rfPreview:SetModel("models/props_junk/PopCan01a.mdl")
        end

        rebuildReforgeList()
        rebuildRolls()

    end

    -- Rebuilt when the server sends an updated inventory (after a reforge).
    frame.RefreshReforge = function()
        rebuildReforge()
    end

    -- Lock clicks change rfLock/rfAction without rebuilding; the rows read them live.
    rebuildReforge()

    setMode(mode)

end

----------------------------------------------------------------------
-- The crafted item
----------------------------------------------------------------------

function LS_UI.ShowCraftResult(item)

    if IsValid(LS_UI.CraftResultFrame) then
        LS_UI.CraftResultFrame:Remove()
    end

    local width, height = 520, 470
    local color = rarityColor(item.rarity)

    local frame = vgui.Create("DFrame")
    frame:SetSize(width, height)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    LS_UI.CraftResultFrame = frame

    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, w - 6, h - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(color.r, color.g, color.b, 230)
        surface.DrawRect(0, 0, 5, h)
        draw.SimpleText("CRAFTED", "Trebuchet24", 28, 18, Color(245, 245, 248))
        drawItemCard(item, 260, 56, w - 260 - 24)
    end

    local model = vgui.Create("DModelPanel", frame)
    model:SetPos(24, 70)
    model:SetSize(220, 200)
    model:SetMouseInputEnabled(false)
    LS_UI.ConfigureModel(model, LS_UI.WeaponModel(item), true, 0.4)

    local close = vgui.Create("DButton", frame)
    close:SetText("")
    close:SetPos(24, height - 20 - 36)
    close:SetSize(width - 48, 36)
    close.Paint = function(self, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(color.r, color.g, color.b, self:IsHovered() and 255 or 200))
        draw.RoundedBox(2, 2, 2, w - 4, h - 4, Color(22, 25, 31, 230))
        draw.SimpleText("CLOSE", "DermaDefaultBold", w / 2, h / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() frame:Remove() end

    surface.PlaySound("ambient/machines/hydraulic_1.wav")

    local cue = {Rare = "buttons/button17.wav", Epic = "buttons/button9.wav", Legendary = "ambient/energy/whiteflash.wav"}

    if cue[item.rarity] then
        surface.PlaySound(cue[item.rarity])
    end

end

net.Receive("LS_OpenWorkbench", function()
    LS_UI.OpenWorkbench()
end)

net.Receive("LS_CraftResult", function()
    LS_UI.ShowCraftResult(net.ReadTable())
end)

net.Receive("LS_ReforgeResult", function()
    surface.PlaySound("ambient/machines/hydraulic_1.wav")
    surface.PlaySound("buttons/button9.wav")
end)

-- The Workbench's reforge view follows inventory updates.
hook.Add("LS_InventoryUpdated", "LS_WorkbenchRefresh", function()

    local frame = LS_UI.WorkbenchFrame

    if IsValid(frame) and frame.RefreshReforge then
        frame.RefreshReforge()
    end

end)

-- Component gains and spends use the same toasts as credits.
net.Receive("LS_ComponentGain", function()

    local id, amount, reason = net.ReadString(), net.ReadInt(32), net.ReadString()

    table.insert(LS_HUD.Toasts, 1, {
        Amount = amount, Reason = reason, At = CurTime(),
        Unit = string.upper(LS_Components.Names[id] or id), Color = LS_Components.Colors[id]
    })

    while #LS_HUD.Toasts > 4 do
        table.remove(LS_HUD.Toasts)
    end

end)

----------------------------------------------------------------------
-- A label over the Workbench when you are near it
----------------------------------------------------------------------

local nextScan, benches = 0, {}

hook.Add("HUDPaint", "LS_WorkbenchLabel", function()

    if CurTime() >= nextScan then
        nextScan = CurTime() + 0.5
        benches = ents.FindByClass("ls_workbench")
    end

    local origin = LocalPlayer():GetPos()

    for _, bench in ipairs(benches) do

        if IsValid(bench) and bench:GetPos():DistToSqr(origin) < 350 * 350 then

            local screen = (bench:WorldSpaceCenter() + Vector(0, 0, 40)):ToScreen()

            if screen.visible then
                draw.SimpleTextOutlined("WORKBENCH  [E]", "Trebuchet18", screen.x, screen.y, Color(120, 190, 255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            end

        end

    end

end)
