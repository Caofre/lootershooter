LS_Weapons = {}

LS_Weapons.Data = {

    AK47 = {
        class = "weapon_ttt_m4a1",
        slot = "PRIMARY",
        archetype = "RIFLE",

        damage = 36,
        rpm = 600,
        magazine = 30
    },

    MP5 = {
        class = "weapon_ttt_mp40",
        slot = "PRIMARY",
        archetype = "SMG",

        damage = 26,
        rpm = 800,
        magazine = 30
    },

    SCOUT = {
        class = "weapon_ttt_sg550",
        slot = "PRIMARY",
        archetype = "SNIPER",

        damage = 75,
        rpm = 60,
        magazine = 10
    },

    GLOCK = {
        class = "weapon_ttt_dual_elites",
        slot = "SECONDARY",
        archetype = "PISTOL",

        damage = 20,
        rpm = 400,
        magazine = 20
    },

    M249 = {
        class = "weapon_ttt_m4a1",
        slot = "PRIMARY",
        archetype = "LMG",

        damage = 32,
        rpm = 750,
        magazine = 100
    }

}

function LS_Weapons.GetRandomWeapon()

    local weaponNames = {}

    for weaponName, _ in pairs(LS_Weapons.Data) do
        table.insert(weaponNames, weaponName)
    end

    local randomName =
        table.Random(weaponNames)

    return randomName,
           LS_Weapons.Data[randomName]

end

function LS_Weapons.GetWeaponData(name)

    return LS_Weapons.Data[name]

end

function LS_Weapons.CalculateFinalStats(item)

    local weaponData =
        LS_Weapons.GetWeaponData(item.weapon)

    if not weaponData then return nil end

    local final = {}

    final.damage = weaponData.damage
    final.rpm = weaponData.rpm
    final.magazine = weaponData.magazine

    if item.stats["Damage"] then
        final.damage =
            final.damage *
            (1 + item.stats["Damage"] / 100)
    end

    if item.stats["Fire Rate"] then
        final.rpm =
            final.rpm *
            (1 + item.stats["Fire Rate"] / 100)
    end

    if item.stats["Magazine Size"] then
        final.magazine =
            final.magazine *
            (1 + item.stats["Magazine Size"] / 100)
    end

    return final

end

function LS_Weapons.ApplyModifiers(weapon, item)
	if not IsValid(weapon) then
    print("Invalid weapon")
    return
end

	if not weapon.Primary then
    print("No Primary table:", weapon:GetClass())
    return
end
    if not IsValid(weapon) then return end
    if not item then return end

    local baseData =
        LS_Weapons.GetWeaponData(item.weapon)

    if not baseData then return end

    local finalStats =
        LS_Weapons.CalculateFinalStats(item)

    weapon.Primary.Damage =
        finalStats.damage

    weapon.Primary.Delay =
        60 / finalStats.rpm

    weapon.Primary.ClipSize =
        finalStats.magazine

end

function LS_Weapons.RefreshPlayerWeapons(ply)
	print("WEAPON:", weapon)
	PrintTable(weapon)
    if not IsValid(ply) then return end

    for _, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item then

                local weapon =
                    ply:GetWeapon(item.class)

                if IsValid(weapon) then

                    LS_Weapons.ApplyModifiers(
                        weapon,
                        item
                    )

                end

            end

        end

    end

end
