LS_Items = {}


LS_Items.Rarities = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary"
}

LS_Items.RarityColors = {
    Common = Color(255,255,255),
    Uncommon = Color(50,255,50),
    Rare = Color(50,150,255),
    Epic = Color(180,80,255),
    Legendary = Color(255,170,0)
}

LS_Items.Prefixes = {
    "Rapid",
    "Heavy",
    "Tactical",
    "Extended"
}

LS_Items.RarityStatCount = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5
}

LS_Items.PrefixWeights = {

    Rapid = {
        ["Fire Rate"] = 40,
        ["Reload Speed"] = 40,
        ["Damage"] = 10,
        ["Magazine Size"] = 10
    },

    Heavy = {
        ["Damage"] = 50,
        ["Magazine Size"] = 20,
        ["Fire Rate"] = 15,
        ["Reload Speed"] = 15
    },

    Tactical = {
        ["Damage"] = 25,
        ["Fire Rate"] = 25,
        ["Reload Speed"] = 25,
        ["Magazine Size"] = 25
    },

    Extended = {
        ["Magazine Size"] = 50,
        ["Reload Speed"] = 20,
        ["Damage"] = 15,
        ["Fire Rate"] = 15
    }

}

LS_Items.PrefixBonusStats = {

    Rapid = "Fire Rate",
    Heavy = "Damage",
    Extended = "Magazine Size",
    Tactical = "Reload Speed"

}

function LS_Items.GetWeightedStat(prefix, availableStats)

    local weights = LS_Items.PrefixWeights[prefix]

    local totalWeight = 0

    for _, stat in ipairs(availableStats) do
        totalWeight = totalWeight + (weights[stat] or 0)
    end

    local roll = math.random(totalWeight)

    local currentWeight = 0

    for _, stat in ipairs(availableStats) do

        currentWeight = currentWeight + (weights[stat] or 0)

        if roll <= currentWeight then
            return stat
        end

    end

end

LS_Items.RarityRanges = {
    Common = {1, 5},
    Uncommon = {3, 8},
    Rare = {5, 10},
    Epic = {8, 13},
    Legendary = {10, 15}
}

function LS_Items.GenerateItem()

    local item = {}

    -- Basic item properties
    local weaponName,
      weaponData =
      LS_Weapons.GetRandomWeapon()

	item.weapon = weaponName
	item.slot = weaponData.slot
	item.archetype = weaponData.archetype
	item.class = weaponData.class

	item.rarity = table.Random(LS_Items.Rarities)
	item.prefix = table.Random(LS_Items.Prefixes)

    -- Stat storage
    item.stats = {}

    -- Copy available stats so we don't roll duplicates
    local availableStats = table.Copy(LS_Items.StatTypes)
	
    -- Number of stats based on rarity
    local statCount = LS_Items.RarityStatCount[item.rarity]

    -- Prevent trying to roll more stats than exist
    statCount = math.min(statCount, #availableStats)

    -- Generate unique stat rolls
    for i = 1, statCount do

        local stat =
    LS_Items.GetWeightedStat(
        item.prefix,
        availableStats
    )

	table.RemoveByValue(
    availableStats,
    stat
	)

		-- Temporary stat values
	local range = LS_Items.RarityRanges[item.rarity]

	local value = math.random(
		range[1],
		range[2]
	)

	local favoredStat =
		LS_Items.PrefixBonusStats[item.prefix]

	if stat == favoredStat then
		value = math.floor(value * 1.5)
	end

item.stats[stat] = value

    end

    return item

end

LS_Items.StatTypes = {
    "Damage",
    "Fire Rate",
    "Reload Speed",
    "Magazine Size"
}

function LS_Items.PrintItem(item)

    print("")

	local itemID = item.id or "?"

	print(
		"[" .. itemID .. "] " ..
		item.rarity .. " " ..
		item.prefix .. " " ..
		item.weapon
)

    print("")
	print("Slot: " .. item.slot)
	print("")
	print("Archetype: " .. item.archetype)
	print("")
	
	local weaponData =
    LS_Weapons.GetWeaponData(item.weapon)

if weaponData then

    print("")
    print("Base Damage: " ..
        weaponData.damage)

    print("Base RPM: " ..
        weaponData.rpm)

    print("Magazine: " ..
        weaponData.magazine)
		
		local finalStats =
    LS_Weapons.CalculateFinalStats(item)

if finalStats then

    print("")
    print("Final Damage: " ..
        math.Round(finalStats.damage, 1))

    print("Final RPM: " ..
        math.Round(finalStats.rpm, 1))

    print("Final Magazine: " ..
        math.Round(finalStats.magazine))

end
		
		

end

print("")
	
    for stat, value in pairs(item.stats) do

        print(
            stat ..
            " +" ..
            value ..
            "%"
        )
	
	
    end

    print("")

end

