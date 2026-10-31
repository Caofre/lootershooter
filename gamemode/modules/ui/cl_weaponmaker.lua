local function SortedKeys(data)

    local keys = {}

    for key in pairs(data) do
        table.insert(keys, key)
    end

    table.sort(keys)

    return keys

end

function LS_OpenWeaponMaker()

    if IsValid(LS_WeaponMaker) then
        LS_WeaponMaker:Remove()
    end

    local frame = vgui.Create("DFrame")
    LS_WeaponMaker = frame
    frame:SetSize(520, 610)
    frame:Center()
    frame:SetTitle("Weapon Maker")
    frame:MakePopup()

    local content = vgui.Create("DScrollPanel", frame)
    content:Dock(FILL)
    content:DockMargin(10, 8, 10, 10)

    local weaponSelector = vgui.Create("DComboBox", content)
    weaponSelector:Dock(TOP)
    weaponSelector:SetTall(28)
    weaponSelector:SetValue("Select weapon")

    for _, weaponName in ipairs(SortedKeys(LS_Weapons.Data)) do
        weaponSelector:AddChoice(weaponName, weaponName)
    end

    local raritySelector = vgui.Create("DComboBox", content)
    raritySelector:Dock(TOP)
    raritySelector:DockMargin(0, 8, 0, 0)
    raritySelector:SetTall(28)
    raritySelector:SetValue("Legendary")

    for _, rarity in ipairs(LS_Items.Rarities) do
        raritySelector:AddChoice(rarity, rarity)
    end

    local statsLabel = vgui.Create("DLabel", content)
    statsLabel:Dock(TOP)
    statsLabel:DockMargin(0, 16, 0, 5)
    statsLabel:SetText("Stat bonuses (%)")

    local statInputs = {}

    for _, statName in ipairs(LS_Items.StatTypes) do

        local row = vgui.Create("DPanel", content)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 5)
        row:SetTall(24)
        row.Paint = nil

        local label = vgui.Create("DLabel", row)
        label:Dock(LEFT)
        label:SetWide(150)
        label:SetText(statName .. " %")
        label:SetContentAlignment(4)

        local input = vgui.Create("DNumberWang", row)
        input:Dock(FILL)
        input:SetMinMax(0, 500)
        input:SetDecimals(0)
        input:SetValue(0)
        input:SetTooltip(statName .. " bonus percentage")
        statInputs[statName] = input

    end

    local talentsLabel = vgui.Create("DLabel", content)
    talentsLabel:Dock(TOP)
    talentsLabel:DockMargin(0, 12, 0, 5)
    talentsLabel:SetText("Talents (choose roll values; Chance supports 0-100%)")

    local talentChoices = {}

    for _, talentID in ipairs(SortedKeys(LS_Talents.Registered)) do

        local talent = LS_Talents.Get(talentID)

        if talent.Slot then
            continue
        end

        local checkbox = vgui.Create("DCheckBoxLabel", content)
        checkbox:Dock(TOP)
        checkbox:DockMargin(0, 0, 0, 4)
        checkbox:SetText(talent.Name .. " — " .. talent.Description)
        checkbox:SetValue(false)
        checkbox:SizeToContents()

        local rollInputs = {}

        for _, rollName in ipairs(SortedKeys(talent.Rolls)) do

            local range = talent.Rolls[rollName]
            local row = vgui.Create("DPanel", content)
            row:Dock(TOP)
            row:DockMargin(20, 0, 0, 3)
            row:SetTall(22)
            row.Paint = nil

            local label = vgui.Create("DLabel", row)
            label:Dock(LEFT)
            label:SetWide(180)
            label:SetContentAlignment(4)
            label:SetText(rollName .. " (normal " .. range[1] .. "-" .. range[2] .. ")")

            local input = vgui.Create("DNumberWang", row)
            input:Dock(FILL)
            input:SetMinMax(0, rollName == "Chance" and 100 or 500)
            input:SetDecimals(0)
            input:SetValue(range[2])
            rollInputs[rollName] = input

        end

        talentChoices[talentID] = {
            checkbox = checkbox,
            rolls = rollInputs
        }

    end

    local createButton = vgui.Create("DButton", content)
    createButton:Dock(TOP)
    createButton:DockMargin(0, 14, 0, 0)
    createButton:SetTall(32)
    createButton:SetText("Create test weapon")

    createButton.DoClick = function()

        local _, weaponName = weaponSelector:GetSelected()

        if not weaponName then
            notification.AddLegacy("Choose a weapon first.", NOTIFY_ERROR, 3)
            return
        end

        local _, rarity = raritySelector:GetSelected()
        rarity = rarity or "Legendary"

        local stats = {}

        for statName, input in pairs(statInputs) do
            stats[statName] = input:GetValue()
        end

        local talents = {}

        for talentID, choice in pairs(talentChoices) do
            if choice.checkbox:GetChecked() then

                talents[talentID] = {}

                for rollName, input in pairs(choice.rolls) do
                    talents[talentID][rollName] = input:GetValue()
                end

            end
        end

        net.Start("LS_CreateTestWeapon")
            net.WriteString(weaponName)
            net.WriteString(rarity)
            net.WriteTable(stats)
            net.WriteTable(talents)
        net.SendToServer()

        frame:Close()

    end

end

concommand.Add("ls_weaponmaker", LS_OpenWeaponMaker)
