LS_Weapons = {}

LS_Weapons.Data = {

    M4A1 = {
        class = "weapon_ttt_m4a1",
        slot = "PRIMARY",
        archetype = "RIFLE",

        damage = 19,
        rpm = 650,
        magazine = 30
    },

    MP40 = {
        class = "weapon_ttt_mp40",
        slot = "PRIMARY",
        archetype = "SMG",

        damage = 30,
        rpm = 500,
        magazine = 32
    },

    ["FN P90"] = {
        class = "weapon_ttt_p90",
        slot = "PRIMARY",
        archetype = "SMG",

        damage = 12,
        rpm = 1200,
        magazine = 50
    },

    FAMAS = {
        class = "weapon_ttt_famas",
        slot = "PRIMARY",
        archetype = "RIFLE",

        damage = 17,
        rpm = 750,
        magazine = 30
    },

    MAC10 = {
        class = "weapon_ttt_mac10",
        slot = "PRIMARY",
        archetype = "SMG",

        damage = 16,
        rpm = 923,
        magazine = 30
    },

    M16 = {
        class = "weapon_ttt_m16",
        slot = "PRIMARY",
        archetype = "RIFLE",

        damage = 31,
        rpm = 364,
        magazine = 24
    },

    MP5 = {
        class = "weapon_ttt_mp5",
        slot = "PRIMARY",
        archetype = "SMG",

        damage = 18,
        rpm = 750,
        magazine = 30
    },

    XM1014 = {
        class = "weapon_ttt_xm1014",
        slot = "PRIMARY",
        archetype = "SHOTGUN",

        damage = 7,
        rpm = 71,
        magazine = 8
    },

    AUG = {
        class = "weapon_ttt_aug",
        slot = "PRIMARY",
        archetype = "RIFLE",
        damage = 19,
        rpm = 667,
        magazine = 30
    },

    Galil = {
        class = "weapon_ttt_galil",
        slot = "PRIMARY",
        archetype = "RIFLE",
        damage = 18,
        rpm = 706,
        magazine = 30
    },

    SG552 = {
        class = "weapon_ttt_sg552",
        slot = "PRIMARY",
        archetype = "RIFLE",
        damage = 19,
        rpm = 667,
        magazine = 30
    },

    TMP = {
        class = "weapon_ttt_tmp",
        slot = "PRIMARY",
        archetype = "SMG",
        damage = 9,
        rpm = 1714,
        magazine = 45
    },

    ["H.U.G.E-249"] = {
        class = "weapon_ttt_m249",
        slot = "PRIMARY",
        archetype = "LMG",
        damage = 10,
        rpm = 1250,
        magazine = 150
    },

    SG550 = {
        class = "weapon_ttt_sg550",
        slot = "PRIMARY",
        archetype = "SNIPER",

        damage = 40,
        rpm = 120,
        magazine = 20
    },

    ["Dual Elites"] = {
        class = "weapon_ttt_dual_elites",
        slot = "SECONDARY",
        archetype = "PISTOL",

        damage = 20,
        rpm = 400,
        magazine = 20
    },

    Deagle = {
        class = "weapon_ttt_deagle",
        slot = "SECONDARY",
        archetype = "PISTOL",

        damage = 37,
        rpm = 150,
        magazine = 8
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
    final.reloadSpeed = 1

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

    if item.stats["Reload Speed"] then
        final.reloadSpeed =
            1 + item.stats["Reload Speed"] / 100
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

    weapon:SetNWFloat("LS_ReloadSpeed", finalStats.reloadSpeed)

end

function LS_Weapons.RefreshPlayerWeapons(ply)
    if not IsValid(ply) then return end

    for _, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item and item.class then

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
