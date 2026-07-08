LS_Equipment = {}

LS_Equipment.Slots = {
    PRIMARY = nil,
    SECONDARY = nil,
    MELEE = nil,
    ARMOR = nil
}

function LS_Equipment.EquipItem(ply, item)

    if not item then
        return false
    end
	
	local oldItemID =
    LS_Equipment.Slots[item.slot]

	if oldItemID then
	
		local oldItem =
			LS_Inventory.GetItemByID(oldItemID)
	
		if oldItem and oldItem.class then

			if IsValid(ply) then
				ply:StripWeapon(oldItem.class)
			end

		end

	end

    LS_Equipment.Slots[item.slot] = item.id

    ply = Entity(1)

    if IsValid(ply) then

        ply:Give(item.class)

        timer.Simple(0, function()

            if not IsValid(ply) then return end

            local weapon =
                ply:GetWeapon(item.class)

            if not IsValid(weapon) then
                print("Weapon not found")
                return
            end

            print(
                "Found weapon:",
                weapon:GetClass()
            )

            LS_Weapons.ApplyModifiers(
                weapon,
                item
            )

        end)

    end

    LS_PlayerStats.Rebuild()

    return true

end

function LS_Equipment.ListEquipment()

    print("")
    print("=== EQUIPMENT ===")

    for slot, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item then

                print(
                    slot .. ": " ..
                    "[" .. item.id .. "] " ..
                    item.rarity .. " " ..
                    item.prefix .. " " ..
                    item.weapon
                )

            else

                print(slot .. ": Invalid Item")

            end

        else

            print(slot .. ": Empty")

        end

    end

    print("=================")
    print("")

end

function LS_Equipment.GetTotalStats()

    local totalStats = {}

    for _, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item then

                for stat, value in pairs(item.stats) do

                    totalStats[stat] =
                        (totalStats[stat] or 0)
                        + value

                end

            end

        end

    end

    return totalStats

end

function LS_Equipment.RestoreEquipment(ply)

    for slot, itemID in pairs(
        LS_Equipment.Slots
    ) do

        if not itemID then
            continue
        end

        local item =
            LS_Inventory.GetItemByID(
                itemID
            )

        if not item then
            continue
        end

        ply:Give(item.class)

        timer.Simple(0, function()

            if not IsValid(ply) then
                return
            end

            local weapon =
                ply:GetWeapon(item.class)

            if not IsValid(weapon) then
                return
            end

            LS_Weapons.ApplyModifiers(
                weapon,
                item
            )

        end)

    end

end