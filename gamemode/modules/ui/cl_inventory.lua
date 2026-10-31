LS_UI = LS_UI or {}

LS_UI.RarityColors = {
    Common = Color(200, 200, 200),
    Uncommon = Color(60, 225, 95),
    Rare = Color(65, 145, 255),
    Epic = Color(190, 80, 255),
    Legendary = Color(255, 155, 45)
}

local rarityOrder = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5}

local function rarityColor(item)
    return LS_UI.RarityColors[item and item.rarity] or color_white
end

function LS_ClientIsEquipped(itemID)
    for _, equippedID in pairs(LS_ClientEquipment or {}) do
        if equippedID == itemID then return true end
    end
    return false
end

local function getItem(itemID)
    for _, item in ipairs(LS_ClientInventory or {}) do
        if item.id == itemID then return item end
    end
end

local function equippedItem(slot)
    return getItem((LS_ClientEquipment or {})[slot])
end

local function weaponModel(item)
    -- Armor shows its own model.
    if item and item.armor then
        local definition = LS_Armor and LS_Armor.Get(item.armor)

        return definition and definition.Model or "models/items/battery.mdl"
    end

    -- Gadgets show their own model.
    if item and item.gadget then
        local definition = LS_Gadgets and LS_Gadgets.Get(item.gadget)

        return definition and definition.Model or "models/props_junk/PopCan01a.mdl"
    end

    local weapon = item and item.class and weapons.Get(item.class)
    -- Workshop models can be mounted and render correctly before
    -- util.IsValidModel recognises them client-side. The SWEP's registered
    -- world model is therefore the reliable source here.
    if weapon and weapon.WorldModel and weapon.WorldModel ~= "" then
        return weapon.WorldModel
    end
    return "models/props_junk/PopCan01a.mdl"
end

local function configureModel(panel, path, rotate, zoom)
    panel:SetModel(path)
    panel:SetFOV(32)
    panel.LayoutEntity = function(self, entity)
        if rotate then entity:SetAngles(Angle(0, (RealTime() * 18) % 360, 0)) end
    end
    timer.Simple(0, function()
        if not IsValid(panel) or not IsValid(panel.Entity) then return end
        local minimum, maximum = panel.Entity:GetRenderBounds()
        local centre = (minimum + maximum) * 0.5
        local radius = math.max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
        local distance = math.max(14, (radius / math.tan(math.rad(panel:GetFOV()) * 0.5)) * (zoom or 0.62))
        panel:SetLookAt(centre)
        panel:SetCamPos(centre + Vector(distance, distance, distance * 0.55))
    end)
end

LS_UI.WeaponModel = weaponModel
LS_UI.ConfigureModel = configureModel

local function humanize(name)
    return string.Trim(string.gsub(name, "(%u)", " %1"))
end

local function actionButton(parent, label, color)
    local button = vgui.Create("DButton", parent)
    button:SetText("")
    button.Label = label
    button.Paint = function(self, width, height)
        local enabled = self:IsEnabled()
        local alpha = enabled and (self:IsHovered() and 255 or 190) or 70
        draw.RoundedBox(3, 0, 0, width, height, Color(color.r, color.g, color.b, alpha))
        draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, enabled and 225 or 155))
        draw.SimpleText(self.Label, "DermaDefaultBold", width / 2, height / 2,
            Color(245, 245, 248, enabled and 255 or 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return button
end

function LS_UI.OpenInventory()
    if IsValid(LS_UI.InventoryFrame) then LS_UI.InventoryFrame:Remove() end

    local frameWidth = math.min(1060, ScrW() - 70)
    local frameHeight = math.min(680, ScrH() - 70)
    local frame = vgui.Create("DFrame")
    frame:SetSize(frameWidth, frameHeight)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, width, height)
        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(28, 32, 40, 250))
        surface.SetDrawColor(255, 255, 255, 20)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end
    LS_UI.InventoryFrame = frame

    local close = vgui.Create("DButton", frame)
    close:SetText("×")
    close:SetFont("Trebuchet24")
    close:SetTextColor(Color(220, 225, 235))
    close:SetPos(frameWidth - 42, 9)
    close:SetSize(32, 28)
    close.Paint = function(self, width, height)
        if self:IsHovered() then draw.RoundedBox(3, 0, 0, width, height, Color(170, 65, 65, 180)) end
    end
    close.DoClick = function() frame:Remove() end

    local header = vgui.Create("DPanel", frame)
    header:SetPos(18, 14)
    header:SetSize(frameWidth - 74, 100)
    header.Paint = function(self, width, height)
        draw.SimpleText("ARMORY", "Trebuchet24", 0, 0, Color(245, 245, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Equipped gear is shown on the right", "DermaDefault", 2, 28, Color(155, 165, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.Comma(LS_Currency.Get()) .. " CR", "Trebuchet18", 2, 48, Color(255, 205, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local x = 2

        for _, id in ipairs(LS_Components.Order) do
            draw.SimpleText(LS_Components.Names[id] .. " " .. LS_Components.Get(id), "DermaDefaultBold", x, 72,
                LS_Components.Colors[id], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            x = x + 82
        end
    end

    local leftWidth, contentTop = math.floor(frameWidth * 0.57), 124
    local contentHeight = frameHeight - contentTop - 18
    local inventoryPanel = vgui.Create("DPanel", frame)
    inventoryPanel:SetPos(18, contentTop)
    inventoryPanel:SetSize(leftWidth - 12, contentHeight)
    inventoryPanel.Paint = function(self, width, height) draw.RoundedBox(4, 0, 0, width, height, Color(20, 23, 30, 245)) end
    local detailsPanel = vgui.Create("DPanel", frame)
    detailsPanel:SetPos(leftWidth + 14, contentTop)
    detailsPanel:SetSize(frameWidth - leftWidth - 32, contentHeight)
    detailsPanel.Paint = inventoryPanel.Paint

    local filterBar = vgui.Create("DPanel", inventoryPanel)
    filterBar:Dock(TOP)
    filterBar:DockMargin(10, 10, 10, 8)
    filterBar:SetTall(56)
    filterBar.Paint = function() end
    local scroll = vgui.Create("DScrollPanel", inventoryPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 0, 3, 10)
    local grid = vgui.Create("DIconLayout", scroll)
    grid:Dock(FILL)
    grid:SetSpaceX(7)
    grid:SetSpaceY(7)

    local actionBar = vgui.Create("DPanel", detailsPanel)
    actionBar:Dock(BOTTOM)
    actionBar:DockMargin(10, 0, 10, 10)
    actionBar:SetTall(42)
    actionBar.Paint = function() end
    local equip = actionButton(actionBar, "EQUIP", Color(70, 155, 240))
    equip:Dock(LEFT)
    equip:SetWide(145)
    equip:SetEnabled(false)
    local dismantle = actionButton(actionBar, "DISMANTLE", Color(210, 78, 75))
    dismantle:Dock(RIGHT)
    dismantle:SetWide(190)
    dismantle:SetEnabled(false)

    local detailScroll = vgui.Create("DScrollPanel", detailsPanel)
    detailScroll:Dock(FILL)
    detailScroll:DockMargin(10, 10, 4, 8)
    local detail = vgui.Create("DPanel", detailScroll)
    detail:Dock(TOP)
    detail:SetTall(1)
    detail.Paint = function() end

    local slotFilter, sortMode, searchText, selectedItem = "ALL", "Newest", ""
    local refresh, updateDetails
    -- Ctrl+click builds a multi-selection for bulk dismantling.
    local multi, multiCount = {}, 0
    local function multiValue()
        local total = 0
        for id in pairs(multi) do total = total + LS_Currency.GetDismantleValue(getItem(id)) end
        return total
    end
    local function clearMulti() multi, multiCount = {}, 0 end
    local function multiComponents()
        local total = {}
        for id in pairs(multi) do
            for component, amount in pairs(LS_Components.GetYield(getItem(id))) do
                total[component] = (total[component] or 0) + amount
            end
        end
        local text = LS_Components.Describe(total)
        return text ~= "" and (" and " .. text) or ""
    end
    local function addText(text, font, color, height, align)
        local label = vgui.Create("DLabel", detail)
        label:Dock(TOP)
        label:DockMargin(10, 0, 10, 0)
        label:SetTall(height or 18)
        label:SetFont(font)
        label:SetTextColor(color)
        label:SetText(text)
        label:SetContentAlignment(align or 4)
        return label
    end

    updateDetails = function()
        detail:Clear()
        detail:SetTall(1)
        if not selectedItem then
            addText("SELECT A WEAPON", "Trebuchet24", Color(225, 228, 235), 34, 5)
            local help = addText("Choose an item from the grid to inspect its model, rolls, talents, and loadout slot.", "DermaDefault", Color(155, 165, 180), 42, 5)
            help:SetWrap(true)
            equip:SetEnabled(false)
            dismantle:SetEnabled(false)
            dismantle.Label = "DISMANTLE"
            return
        end

        local color = rarityColor(selectedItem)
        local preview = vgui.Create("DModelPanel", detail)
        preview:Dock(TOP)
        preview:DockMargin(6, 4, 6, 8)
        preview:SetTall(210)
        configureModel(preview, weaponModel(selectedItem), true, 0.38)
        addText(string.upper(selectedItem.rarity), "DermaDefaultBold", color, 18)
        addText((selectedItem.prefix or "") .. " " .. (selectedItem.weapon or "Weapon"), "Trebuchet24", Color(245, 245, 248), 31)
        addText("SLOT: " .. (selectedItem.slot or "UNKNOWN"), "DermaDefaultBold", Color(155, 165, 180), 19)

        if selectedItem.gadget or selectedItem.armor then
            local definition = selectedItem.gadget and LS_Gadgets and LS_Gadgets.Get(selectedItem.gadget) or
                (LS_Armor and LS_Armor.Get(selectedItem.armor))

            if definition then
                local description = addText(definition.Description, "DermaDefault", Color(185, 195, 210), 54, 7)
                description:SetWrap(true)
            end
        end
        local divider = vgui.Create("DPanel", detail)
        divider:Dock(TOP)
        divider:DockMargin(10, 7, 10, 7)
        divider:SetTall(1)
        divider.Paint = function(self, width, height) surface.SetDrawColor(color.r, color.g, color.b, 120) surface.DrawRect(0, 0, width, height) end
        addText("MODIFIERS", "DermaDefaultBold", Color(170, 180, 195), 20)
        local statCount = 0
        for stat, value in SortedPairs(selectedItem.stats or {}) do
            addText(humanize(stat) .. "     +" .. value .. "%", "DermaDefault", Color(225, 228, 235), 18)
            statCount = statCount + 1
        end
        if statCount == 0 then addText("No rolled modifiers", "DermaDefault", Color(155, 165, 180), 18) end
        addText("TALENTS", "DermaDefaultBold", Color(170, 180, 195), 25)
        if #(selectedItem.talents or {}) == 0 then
            addText("No talents", "DermaDefault", Color(155, 165, 180), 18)
        else
            for _, instance in ipairs(selectedItem.talents) do
                local talent = LS_Talents and LS_Talents.Get(instance.id)
                addText(talent and talent.Name or instance.id, "DermaDefaultBold", color, 19)

                -- What the talent does, then its rolled values.
                if talent and talent.Description then
                    for _, line in ipairs(LS_Talents.WrapLines(talent.Description, "DermaDefault", 350)) do
                        addText("  " .. line, "DermaDefault", Color(165, 175, 190), 16)
                    end
                end

                for roll, value in SortedPairs(instance.rolls or {}) do
                    addText("    " .. LS_Talents.RollLabel(roll) .. ": " .. LS_Talents.FormatRoll(instance.id, roll, value),
                        "DermaDefault", Color(205, 210, 220), 17)
                end
            end
        end
        local equipped = equippedItem(selectedItem.slot)
        addText("LOADOUT", "DermaDefaultBold", Color(170, 180, 195), 25)
        if equipped and equipped.id ~= selectedItem.id then
            local compare = addText("Equipped: " .. equipped.rarity .. " " .. equipped.prefix .. " " .. equipped.weapon, "DermaDefault", rarityColor(equipped), 34)
            compare:SetWrap(true)
        elseif equipped then
            addText("This item is equipped", "DermaDefault", color, 18)
        else
            addText("No " .. (selectedItem.slot or "") .. " item equipped", "DermaDefault", Color(155, 165, 180), 18)
        end
        addText("DISMANTLE YIELD", "DermaDefaultBold", Color(170, 180, 195), 25)
        local yieldText = LS_Currency.GetDismantleValue(selectedItem) .. " CR"
        local components = LS_Components.Describe(LS_Components.GetYield(selectedItem))
        if components ~= "" then yieldText = yieldText .. ", " .. components end
        addText(yieldText, "DermaDefault", Color(205, 210, 220), 18)
        detail:InvalidateLayout(true)
        detail:SizeToChildren(false, true)
        equip:SetEnabled(not (equipped and equipped.id == selectedItem.id))
        dismantle:SetEnabled(not equipped or equipped.id ~= selectedItem.id)
        dismantle.Label = "DISMANTLE  +" .. LS_Currency.GetDismantleValue(selectedItem) .. " CR"
        if multiCount > 0 then
            dismantle:SetEnabled(true)
            dismantle.Label = "DISMANTLE " .. multiCount .. "  +" .. multiValue() .. " CR"
        end
    end

    refresh = function()
        grid:Clear()
        local items = table.Copy(LS_ClientInventory or {})
        table.sort(items, function(a, b)
            if sortMode == "Rarity" then
                local ar, br = rarityOrder[a.rarity] or 0, rarityOrder[b.rarity] or 0
                if ar ~= br then return ar > br end
            elseif sortMode == "Weapon" and a.weapon ~= b.weapon then return a.weapon < b.weapon end
            return a.id > b.id
        end)
        for _, item in ipairs(items) do
            local searchable = string.lower((item.weapon or "") .. " " .. (item.prefix or "") .. " " .. (item.rarity or ""))
            if not LS_ClientIsEquipped(item.id) and (slotFilter == "ALL" or item.slot == slotFilter) and (searchText == "" or string.find(searchable, searchText, 1, true)) then
                local slot = grid:Add("DButton")
                slot:SetSize(104, 110)
                slot:SetText("")
                slot.Paint = function(self, width, height)
                    local color = rarityColor(item)
                    local selected = (selectedItem and selectedItem.id == item.id) or multi[item.id]
                    local highlight = selected and 95 or (self:IsHovered() and 60 or 30)
                    draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                    draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(color.r, color.g, color.b, highlight))
                    surface.SetDrawColor(color.r, color.g, color.b, selected and 255 or 165)
                    surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
                    surface.SetDrawColor(color.r, color.g, color.b, 110)
                    surface.SetMaterial(Material("gui/gradient_down"))
                    surface.DrawTexturedRect(2, math.floor(height * 0.53), width - 4, math.ceil(height * 0.45))
                end
                local model = vgui.Create("DModelPanel", slot)
                model:SetPos(5, 3)
                model:SetSize(94, 72)
                model:SetMouseInputEnabled(false)
                configureModel(model, weaponModel(item), false, 0.5)
                local name = vgui.Create("DLabel", slot)
                name:SetPos(5, 77)
                name:SetSize(94, 15)
                name:SetFont("DermaDefaultBold")
                name:SetTextColor(Color(245, 245, 248))
                name:SetText(item.weapon or "Weapon")
                name:SetContentAlignment(5)
                local prefix = vgui.Create("DLabel", slot)
                prefix:SetPos(5, 92)
                prefix:SetSize(94, 14)
                prefix:SetFont("DermaDefault")
                prefix:SetTextColor(Color(rarityColor(item).r, rarityColor(item).g, rarityColor(item).b))
                prefix:SetText(item.prefix or item.rarity or "")
                prefix:SetContentAlignment(5)
                slot.DoClick = function()
                    if input.IsControlDown() then
                        if LS_ClientIsEquipped(item.id) then surface.PlaySound("buttons/button10.wav") return end
                        if multiCount == 0 and selectedItem and not LS_ClientIsEquipped(selectedItem.id) then
                            multi[selectedItem.id], multiCount = true, 1
                        end
                        if multi[item.id] then multi[item.id], multiCount = nil, multiCount - 1
                        else multi[item.id], multiCount = true, multiCount + 1 end
                        surface.PlaySound("ui/buttonrollover.wav")
                    else
                        clearMulti()
                    end
                    selectedItem = item
                    updateDetails()
                end
                slot.DoDoubleClick = function()
                    selectedItem = item
                    updateDetails()
                    surface.PlaySound("items/ammo_pickup.wav")
                    net.Start("LS_EquipItem")
                    net.WriteUInt(item.id, 16)
                    net.SendToServer()
                end
            end
        end
        updateDetails()
    end

    local filter = vgui.Create("DComboBox", filterBar)
    filter:SetPos(0, 0)
    filter:SetSize(122, 24)
    filter:AddChoice("All slots", "ALL")
    filter:AddChoice("Primary", "PRIMARY")
    filter:AddChoice("Secondary", "SECONDARY")
    filter:AddChoice("Melee", "MELEE")
    filter:AddChoice("Armor", "ARMOR")
    filter:AddChoice("Gadget", "GADGET")
    filter:SetValue("All slots")
    filter.OnSelect = function(self, index, value, data) slotFilter = data refresh() end
    local sort = vgui.Create("DComboBox", filterBar)
    sort:SetPos(130, 0)
    sort:SetSize(112, 24)
    sort:AddChoice("Newest", "Newest")
    sort:AddChoice("Rarity", "Rarity")
    sort:AddChoice("Weapon name", "Weapon")
    sort:SetValue("Newest")
    sort.OnSelect = function(self, index, value, data) sortMode = data refresh() end
    local search = vgui.Create("DTextEntry", filterBar)
    search:SetPos(0, 30)
    search:SetSize(filterBar:GetWide(), 24)
    search:SetPlaceholderText("Search weapon, prefix, or rarity   (Ctrl+click: multi-select)")
    search.OnValueChange = function(self, value) searchText = string.lower(value or "") refresh() end

    equip.DoClick = function()
        if not selectedItem then return end
        net.Start("LS_EquipItem")
        net.WriteUInt(selectedItem.id, 16)
        net.SendToServer()
    end
    dismantle.DoClick = function()
        if multiCount > 0 then
            Derma_Query("Dismantle " .. multiCount .. " selected items for " .. multiValue() .. " CR" .. multiComponents() .. "? This cannot be undone.", "Dismantle Items", "Dismantle", function()
                net.Start("LS_DismantleItems")
                net.WriteUInt(multiCount, 8)
                for id in pairs(multi) do net.WriteUInt(id, 16) end
                net.SendToServer()
                clearMulti()
            end, "Cancel")
            return
        end
        if not selectedItem then return end
        Derma_Query("Dismantle " .. selectedItem.rarity .. " " .. selectedItem.prefix .. " " .. selectedItem.weapon .. " for " .. LS_Currency.GetDismantleValue(selectedItem) .. " CR" ..
            (LS_Components.Describe(LS_Components.GetYield(selectedItem)) ~= "" and (" and " .. LS_Components.Describe(LS_Components.GetYield(selectedItem))) or "") ..
            "? This cannot be undone.", "Dismantle Item", "Dismantle", function()
            net.Start("LS_DismantleItem")
            net.WriteUInt(selectedItem.id, 16)
            net.SendToServer()
        end, "Cancel")
    end
    -- The equipped section: one card per slot, with the item's model.
    local function buildLoadout()
        local slots = {"PRIMARY", "SECONDARY", "MELEE", "ARMOR", "GADGET"}
        local loadoutX = 250
        local cardWidth = math.floor((header:GetWide() - loadoutX) / #slots) - 6

        for index, slot in ipairs(slots) do
            local item = equippedItem(slot)
            local card = vgui.Create("DButton", header)
            card:SetText("")
            card:SetPos(loadoutX + (index - 1) * (cardWidth + 6), 0)
            card:SetSize(cardWidth, 98)
            card.Paint = function(self, width, height)
                local color = item and rarityColor(item) or Color(100, 108, 120)
                local selected = item and selectedItem and selectedItem.id == item.id
                local highlight = item and (selected and 85 or (self:IsHovered() and 55 or 30)) or 12

                draw.RoundedBox(3, 0, 0, width, height, Color(15, 18, 24, 245))
                draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(color.r, color.g, color.b, highlight))
                surface.SetDrawColor(color.r, color.g, color.b, item and (selected and 255 or 165) or 60)
                surface.DrawOutlinedRect(0, 0, width, height, selected and 2 or 1)
                draw.SimpleText(slot, "DermaDefaultBold", 7, 4, Color(160, 170, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                if item then
                    draw.SimpleText(item.weapon or "", "DermaDefaultBold", width / 2, height - 12, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("EMPTY", "DermaDefault", width / 2, height / 2, Color(110, 118, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            if item then
                local model = vgui.Create("DModelPanel", card)
                model:SetPos(4, 18)
                model:SetSize(cardWidth - 8, 56)
                model:SetMouseInputEnabled(false)
                configureModel(model, weaponModel(item), false, 0.5)

                card.DoClick = function()
                    clearMulti()
                    selectedItem = item
                    updateDetails()
                end
            end
        end
    end

    buildLoadout()
    refresh()
end

hook.Add("PlayerButtonDown", "LS_OpenInventory", function(player, button)
    if player == LocalPlayer() and button == KEY_I then LS_UI.OpenInventory() end
end)

hook.Add("Think", "LS_InventoryKey", function()
    if input.IsKeyDown(KEY_I) then
        if not LS_UI.InventoryKeyHeld then LS_UI.InventoryKeyHeld = true LS_UI.OpenInventory() end
    else
        LS_UI.InventoryKeyHeld = false
    end
end)

LS_ClientInventory = LS_ClientInventory or {}
LS_ClientEquipment = LS_ClientEquipment or {}
net.Receive("LS_SendInventory", function()
    local data = net.ReadTable()
    LS_ClientInventory = data.Items or {}
    LS_ClientEquipment = data.Equipment or {}
    if IsValid(LS_UI.InventoryFrame) then LS_UI.OpenInventory() end
    hook.Run("LS_InventoryUpdated")
end)
