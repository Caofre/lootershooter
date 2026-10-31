LS_Items = {}


LS_Items.Rarities = {
    "Common",
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary"
}

LS_Items.RarityWeights = {

    Common = 45,
    Uncommon = 30,
    Rare = 14,
    Epic = 8,
    Legendary = 3

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

LS_Items.RarityTalentCount = {
    Common = 0,
    Uncommon = 0,
    Rare = 1,
    Epic = 2,
    Legendary = 3
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

function LS_Items.GetWeightedRarity(weights)

    weights = weights or LS_Items.RarityWeights

    local totalWeight = 0

    for _, rarity in ipairs(LS_Items.Rarities) do
        totalWeight = totalWeight + (weights[rarity] or 0)
    end

    if totalWeight <= 0 then
        return table.Random(LS_Items.Rarities)
    end

    local roll = math.random(totalWeight)

    local currentWeight = 0

    for _, rarity in ipairs(LS_Items.Rarities) do

        currentWeight = currentWeight + (weights[rarity] or 0)

        if roll <= currentWeight then
            return rarity
        end

    end

end

-- A fresh value for one stat on an existing weapon item (used by reforging).
function LS_Items.RollStatValue(item, stat)

    local range = LS_Items.RarityRanges[item.rarity]
    local value = math.random(range[1], range[2])

    if stat == LS_Items.PrefixBonusStats[item.prefix] then
        value = math.floor(value * 1.5)
    end

    return value

end

function LS_Items.GenerateItem(rarityWeights, options)

    -- Occasionally the roll is a gadget instead of a weapon.
    if LS_Gadgets and LS_Gadgets.TryGenerate and not (options and options.Weapon) then
        local gadget = LS_Gadgets.TryGenerate(rarityWeights, options and options.GadgetChance)

        if gadget then
            return gadget
        end
    end

    -- ...or armor.
    if LS_Armor and LS_Armor.TryGenerate and not (options and options.Weapon) then
        local armor = LS_Armor.TryGenerate(rarityWeights, options and options.ArmorChance)

        if armor then
            return armor
        end
    end

    local item = {}

    -- Basic item properties
    local weaponName, weaponData = LS_Weapons.GetRandomWeapon()

    -- Crafting asks for a specific weapon.
    if options and options.Weapon and LS_Weapons.Data[options.Weapon] then
        weaponName, weaponData = options.Weapon, LS_Weapons.Data[options.Weapon]
    end

	item.weapon = weaponName
	item.slot = weaponData.slot
	item.archetype = weaponData.archetype
	item.class = weaponData.class

	item.rarity = options and options.Rarity or LS_Items.GetWeightedRarity(rarityWeights)
	item.prefix = table.Random(LS_Items.Prefixes)

    -- Stat storage
    item.stats = {}
	-- Talent storage
	item.talents = {}
	
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
	local talentCount =
		LS_Items.RarityTalentCount[item.rarity]

	local availableTalents = {}

	for id, talent in pairs(LS_Talents.Registered) do

		if not talent.Slot then
			table.insert(
			availableTalents,
			talent
		)
		end

	end

	for i = 1, talentCount do

		if #availableTalents == 0 then
			break
		end

		local talent =
			table.remove(
				availableTalents,
				math.random(#availableTalents)
			)

		table.insert(
			item.talents,
			LS_Talents.Roll(talent.ID)
		)

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

