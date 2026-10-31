LS_Networking = {}


function LS_Networking.SendInventory(ply)

    net.Start("LS_SendInventory")
        net.WriteTable({
            Items = LS_Inventory.Items,
            Equipment = LS_Equipment.Slots
        })
    net.Send(ply)

end

if SERVER then

    util.AddNetworkString("LS_CreateTestWeapon")
    util.AddNetworkString("LS_LootPickup")

    net.Receive("LS_CreateTestWeapon", function(_, ply)

        local weaponName = net.ReadString()
        local rarity = net.ReadString()
        local requestedStats = net.ReadTable()
        local requestedTalents = net.ReadTable()
        local weaponData = LS_Weapons.GetWeaponData(weaponName)

        if not weaponData or not table.HasValue(LS_Items.Rarities, rarity) then
            return
        end

        local item = {
            weapon = weaponName,
            class = weaponData.class,
            slot = weaponData.slot,
            archetype = weaponData.archetype,
            rarity = rarity,
            prefix = "Test",
            stats = {},
            talents = {}
        }

        for _, statName in ipairs(LS_Items.StatTypes) do

            local value = tonumber(requestedStats[statName]) or 0

            if value > 0 then
                item.stats[statName] = math.Clamp(math.floor(value), 1, 500)
            end

        end

        for talentID, requestedRolls in pairs(requestedTalents) do

            local talent = LS_Talents.Get(talentID)

            if talent and istable(requestedRolls) then

                local instance = LS_Talents.Roll(talentID)

                for rollName in pairs(talent.Rolls) do

                    local value = tonumber(requestedRolls[rollName])

                    if value then
                        local maximum = rollName == "Chance" and 100 or 500
                        instance.rolls[rollName] = math.Clamp(
                            math.floor(value),
                            0,
                            maximum
                        )
                    end

                end

                table.insert(item.talents, instance)
            end

        end

        LS_Inventory.AddItem(item)
        LS_Networking.SendInventory(ply)

    end)

end
