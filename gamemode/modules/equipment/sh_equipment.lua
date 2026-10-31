LS_Equipment = {}

LS_Equipment.Slots = {
    PRIMARY = nil,
    SECONDARY = nil,
    MELEE = nil,
    ARMOR = nil
}

function LS_Equipment.GiveWeapon(ply, item)

	if not IsValid(ply) then
		return
	end

	-- Armor is not a weapon; the armor system handles it.
	if item.armor then
		if SERVER and LS_Armor and LS_Armor.OnEquip then
			LS_Armor.OnEquip(ply, item)
		end

		return
	end

	-- Gadgets are not weapons; the gadget system handles them.
	if item.gadget then
		if SERVER and LS_Gadgets and LS_Gadgets.OnEquip then
			LS_Gadgets.OnEquip(ply, item)
		end

		return
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

		if weapon.Primary and weapon.Primary.Ammo and
			weapon.Primary.Ammo ~= "none" then
			ply:GiveAmmo(999, weapon.Primary.Ammo, true)
		end

		LS_Weapons.ApplyModifiers(
			weapon,
			item
		)

		-- Start with a full magazine at the rolled size, not the base size.
		if weapon.Primary and weapon.Primary.ClipSize and
			weapon.Primary.ClipSize > 0 then
			weapon:SetClip1(math.floor(weapon.Primary.ClipSize))
		end

	end)

end

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

    LS_Equipment.GiveWeapon(
    ply,
    item
)

    LS_PlayerStats.Rebuild()

    if LS_Save and LS_Save.MarkDirty then LS_Save.MarkDirty() end

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

function LS_Equipment.IsItemEquipped(itemID)

    for _, equippedItemID in pairs(LS_Equipment.Slots) do

        if equippedItemID == itemID then
            return true
        end

    end

    return false

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

        LS_Equipment.GiveWeapon(
		ply,
		item
	)

    end

end

function LS_Equipment.GetEquippedWeaponItem(ply)

    if not IsValid(ply) then
        return nil
    end

    local weapon = ply:GetActiveWeapon()

    if not IsValid(weapon) then
        return nil
    end

    for _, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item and item.class == weapon:GetClass() then

                return item

            end

        end

    end

    return nil

end
