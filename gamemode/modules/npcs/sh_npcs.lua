LS_NPCs = {}

-- Cleanup used to be attached to OnNPCKilled. Remove that legacy callback on
-- module reload so an already-running server cannot keep its stale closure.
hook.Remove("OnNPCKilled", "LS_NPCCorpseCleanup")

LS_NPCs.Registered = {}
LS_NPCs.Variants = {}

-- Global multiplier on every enemy's loot chance (see ls_lootscale).
LS_NPCs.LootScale = 1

-- Set by the active contract's tier (1 outside contracts).
LS_NPCs.MissionLootMult = 1

LS_NPCs.HealthPerLevel = 0.15
LS_NPCs.XPPerLevel = 0.20

function LS_NPCs.GetScaledHealth(definition, level)

    level = level or 1

    return math.floor(

        definition.BaseHealth *

        (1 + (level - 1) * LS_NPCs.HealthPerLevel)

    )

end

function LS_NPCs.GetScaledXP(definition, level)

    level = level or 1

    return math.floor(

        definition.BaseXP *

        (1 + (level - 1) * LS_NPCs.XPPerLevel)

    )

end

function LS_NPCs.Register(data)

    data.Class = data.Class or ""
    data.Faction = data.Faction or "Neutral"

    data.BaseHealth = data.BaseHealth or 100
    data.DamageMultiplier = data.DamageMultiplier or 1

    data.LootChance = data.LootChance or 100
    data.BaseXP = data.BaseXP or 0
    data.WeaponProficiency = data.WeaponProficiency or nil
    data.ProficiencyByLevel = data.ProficiencyByLevel or nil
    data.Equipment = data.Equipment or {}
    data.Relationship = data.Relationship or "hostile_player"
    data.NoWeaponDrop = data.NoWeaponDrop ~= false

    LS_NPCs.Registered[data.ID] = data

end

function LS_NPCs.Get(id)

    return LS_NPCs.Registered[id]

end

function LS_NPCs.RegisterVariant(data)

    data.Name = data.Name or nil
    data.Badge = data.Badge or data.Name or ""
    data.Color = data.Color or Color(255, 255, 255)
    data.HealthMultiplier = data.HealthMultiplier or 1
    data.XPMultiplier = data.XPMultiplier or 1
    data.LootChanceMultiplier = data.LootChanceMultiplier or 1
    data.DamageReduction = data.DamageReduction or 0

    LS_NPCs.Variants[data.ID] = data

end

function LS_NPCs.GetVariant(id)

    return LS_NPCs.Variants[id]

end

function LS_NPCs.RollVariant(definition)

    local variants = definition.Variants or {
        normal = 100
    }

    local totalWeight = 0

    for _, weight in pairs(variants) do
        totalWeight = totalWeight + weight
    end

    if totalWeight <= 0 then
        return LS_NPCs.GetVariant("normal")
    end

    local roll = math.random(totalWeight)
    local currentWeight = 0

    for id, weight in pairs(variants) do

        currentWeight = currentWeight + weight

        if roll <= currentWeight then
            return LS_NPCs.GetVariant(id) or
                LS_NPCs.GetVariant("normal")
        end

    end

    return LS_NPCs.GetVariant("normal")

end

function LS_NPCs.Spawn(id, position, forcedVariantID, forcedLevel)

    local definition = LS_NPCs.Get(id)

    if not definition then
        return nil
    end

    local npc = ents.Create(definition.Class)

    if not IsValid(npc) then
        return nil
    end

    if definition.Model then
        npc:SetModel(definition.Model)
    end

    npc:SetPos(position)

    if definition.NoWeaponDrop then
        npc:SetKeyValue(
            "spawnflags",
            bit.bor(npc:GetSpawnFlags(), SF_NPC_NO_WEAPON_DROP)
        )
    end

    npc:Spawn()

    if definition.Skin then
        npc:SetSkin(definition.Skin)
    end

    LS_NPCs.Initialize(npc, definition, forcedVariantID, forcedLevel)

return npc

end

function LS_NPCs.Initialize(npc, definition, forcedVariantID, forcedLevel)

    local level = forcedLevel or 1

	if not forcedLevel and definition.LevelRange then

		level = math.random(
			definition.LevelRange[1],
			definition.LevelRange[2]
		)

	elseif not forcedLevel and definition.Level then

		level = definition.Level

	end

	npc.LS_Level = level
	npc.LS_Definition = definition

    local variant = LS_NPCs.GetVariant(forcedVariantID) or
        LS_NPCs.RollVariant(definition)

	npc.LS_Name = definition.Name or definition.ID
	npc.LS_BaseName = definition.Name or definition.ID
	npc.LS_Variant = variant.ID
	npc.LS_VariantData = variant
	npc.LS_DamageReduction = variant.DamageReduction

	npc.LS_Faction = definition.Faction or "Neutral"

	npc.LS_Prefix = variant.Name
	npc.LS_Suffix = nil

	npc.LS_XP = math.floor(
		LS_NPCs.GetScaledXP(
			definition,
			level
		) * variant.XPMultiplier
	)

    npc.LS_LootChance = math.min(
        100,
        math.floor(definition.LootChance *
            variant.LootChanceMultiplier *
            (LS_NPCs.LootScale or 1) *
            (LS_NPCs.MissionLootMult or 1))
    )

    -- Elite is a loot tier and can override rarity odds. Other variants keep
    -- the NPC family's table, so a tougher enemy type is rewarded consistently
    -- whether it happens to be Normal, Volatile, or Armored.
    npc.LS_RarityWeights = variant.RarityWeights or definition.RarityWeights
		
		local health = math.floor(
			LS_NPCs.GetScaledHealth(
				definition,
				level
			) * variant.HealthMultiplier
		)

		npc:SetNW2String("LS_Name", npc.LS_BaseName)
		npc:SetNW2Int("LS_Level", level)
		npc:SetNW2Int("LS_MaxHealth", health)
		npc:SetNW2Bool("LS_IsFrameworkNPC", true)
		npc:SetNW2String("LS_Variant", variant.ID)
		npc:SetNW2String("LS_VariantBadge", variant.Badge or "")
		npc:SetNW2Vector("LS_VariantColor", Vector(
			variant.Color.r,
			variant.Color.g,
			variant.Color.b
		))

		npc.LS_MaxHealth = health
		npc:SetHealth(health)
		npc:SetMaxHealth(health)

		LS_NPCs.ApplyVariantVisuals(npc, variant)
		LS_NPCs.ApplyShield(npc, variant, health)

		if LS_NPCs.StartBehavior then
			LS_NPCs.StartBehavior(npc, variant)
		end

		LS_NPCs.ApplyEquipment(npc, definition, level)
		LS_NPCs.ApplyRelationships(npc, definition)
		LS_NPCs.ApplyNPCRelationships(npc)

end

function LS_NPCs.GetWeaponProficiency(definition, level)

    local proficiency = definition.WeaponProficiency
    local bestLevel = -1

    for minimumLevel, scaledProficiency in pairs(
        definition.ProficiencyByLevel or {}
    ) do
        if level >= minimumLevel and minimumLevel > bestLevel then
            proficiency = scaledProficiency
            bestLevel = minimumLevel
        end
    end

    return proficiency

end

function LS_NPCs.ApplyEquipment(npc, definition, level)

	if not IsValid(npc) then
		return
	end

	for _, weaponClass in ipairs(definition.Equipment or {}) do
		npc:Give(weaponClass)
	end

	local proficiency = LS_NPCs.GetWeaponProficiency(definition, level or 1)

	if proficiency ~= nil then
		npc.LS_WeaponProficiency = proficiency
		npc:SetCurrentWeaponProficiency(proficiency)
	end

end

function LS_NPCs.ApplyRelationships(npc, definition)

	if not IsValid(npc) or definition.Relationship ~= "hostile_player" then
		return
	end

	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and npc.AddEntityRelationship then
			npc:AddEntityRelationship(ply, D_HT, 99)
		end
	end

end

function LS_NPCs.ApplyNPCRelationships(npc)

    if not IsValid(npc) or not npc:IsNPC() then
        return
    end

    for _, otherNPC in ipairs(ents.FindByClass("npc_*")) do

        if otherNPC == npc or not otherNPC:IsNPC() or
            not otherNPC:GetNW2Bool("LS_IsFrameworkNPC", false) then
            continue
        end

        if npc.AddEntityRelationship then
            npc:AddEntityRelationship(otherNPC, D_NU, 99)
        end

        if otherNPC.AddEntityRelationship then
            otherNPC:AddEntityRelationship(npc, D_NU, 99)
        end

    end

end

function LS_NPCs.List()

    print("=== NPCS ===")

    for id, npc in pairs(LS_NPCs.Registered) do

        print(id, npc.Name)

    end

end

function LS_NPCs.GetDisplayName(npc)

    if not IsValid(npc) then
        return "Unknown"
    end

    local parts = {}

    if npc.LS_Prefix then
        table.insert(parts, npc.LS_Prefix)
    end

    table.insert(parts, npc.LS_Name or "Unknown")

    if npc.LS_Suffix then
        table.insert(parts, npc.LS_Suffix)
    end

    return table.concat(parts, " ")

end

function LS_NPCs.GetHealthPercent(npc)

    if not IsValid(npc) then
        return 0
    end

    if not npc.LS_MaxHealth or npc.LS_MaxHealth <= 0 then
        return 0
    end

    return npc:Health() / npc.LS_MaxHealth

end

function LS_NPCs.GetLevel(npc)

    if not IsValid(npc) then
        return 1
    end

    return npc.LS_Level or 1

end

LS_NPCs.RegisterVariant({

    ID = "normal",
    Color = Color(255, 255, 255)

})

LS_NPCs.RegisterVariant({

    ID = "alpha",
    LootChanceMultiplier = 5,
    Name = "Alpha",
    Badge = "ALPHA  ◆",
    Color = Color(212, 72, 118),

    HealthMultiplier = 1.75,
    XPMultiplier = 3,

    RarityWeights = {
        Common = 15,
        Uncommon = 25,
        Rare = 28,
        Epic = 22,
        Legendary = 10
    }

})

LS_NPCs.RegisterVariant({

    ID = "elite",
    LootChanceMultiplier = 2,
    Name = "Elite",
    Badge = "ELITE  ◆",
    Color = Color(245, 171, 55),

    HealthMultiplier = 1.5,
    XPMultiplier = 1.5,

    RarityWeights = {
        Common = 25,
        Uncommon = 30,
        Rare = 23,
        Epic = 16,
        Legendary = 6
    }

})

-- Toxic and Shielded remain reserved until their status and shield mechanics
-- exist. Volatile and Armored below are active, fully-defined combat affixes.
LS_NPCs.RegisterVariant({

    ID = "volatile",
    LootChanceMultiplier = 1.3,
    Name = "Volatile",
    Badge = "VOLATILE  ◆",
    Color = Color(238, 102, 55),

    HealthMultiplier = 1.15,
    XPMultiplier = 1.2

})

LS_NPCs.RegisterVariant({

    ID = "toxic",
    LootChanceMultiplier = 1.3,
    Name = "Toxic",
    Badge = "TOXIC  ◆",
    Color = Color(101, 204, 91),

    HealthMultiplier = 1.2,
    XPMultiplier = 1.3

})

LS_NPCs.RegisterVariant({

    ID = "armored",
    LootChanceMultiplier = 1.3,
    Name = "Armored",
    Badge = "ARMORED  ◆",
    Color = Color(105, 164, 220),

    HealthMultiplier = 1.1,
    XPMultiplier = 1.25,
    DamageReduction = 0.25

})

LS_NPCs.RegisterVariant({

    ID = "shielded",
    LootChanceMultiplier = 1.6,
    Name = "Shielded",
    Badge = "SHIELDED  ◆",
    Color = Color(109, 220, 235),

    XPMultiplier = 1.5,

    -- The shield absorbs damage before health. If it breaks and the NPC is
    -- left alone for ShieldRegenDelay seconds, it comes back at full strength.
    ShieldFraction = 0.6,
    ShieldRegenDelay = 7

})

LS_NPCs.Register({

    ID = "zombie",

    Name = "Zombie",

    Class = "npc_zombie",

    Faction = "Undead",

    BaseHealth = 100,
    BaseXP = 10,

    LevelRange = {1,5},

    LootChance = 12,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "fast_zombie",

    Name = "Fast Zombie",

    Class = "npc_fastzombie",

    Faction = "Undead",

    BaseHealth = 65,
    BaseXP = 12,

    LevelRange = {1, 5},

    LootChance = 12,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "zombine",

    Name = "Zombine",

    Class = "npc_zombine",

    Faction = "Undead",

    BaseHealth = 145,
    BaseXP = 16,

    LevelRange = {2, 5},

    LootChance = 16,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "antlion",

    Name = "Antlion",

    Class = "npc_antlion",

    Faction = "Antlion",

    BaseHealth = 80,
    BaseXP = 8,

    LevelRange = {1, 5},

    LootChance = 12,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "rebel",

    Name = "Rebel",

    Class = "npc_citizen",

    Faction = "Resistance",

    BaseHealth = 90,
    BaseXP = 12,

    LevelRange = {1, 5},

    LootChance = 14,

    Equipment = {
        "weapon_smg1"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_AVERAGE,

    ProficiencyByLevel = {
        [3] = WEAPON_PROFICIENCY_GOOD
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "metropolice",

    Name = "Metropolice",

    Class = "npc_metropolice",

    Faction = "Combine",

    BaseHealth = 75,
    BaseXP = 10,

    LevelRange = {1, 5},

    LootChance = 14,

    Equipment = {
        "weapon_pistol"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_AVERAGE,

    ProficiencyByLevel = {
        [4] = WEAPON_PROFICIENCY_GOOD
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "poison_zombie",

    Name = "Poison Zombie",

    Class = "npc_poisonzombie",

    Faction = "Undead",

    BaseHealth = 350,
    BaseXP = 30,

    LevelRange = {3, 5},

    LootChance = 30,

    RarityWeights = {
        Common = 35,
        Uncommon = 30,
        Rare = 20,
        Epic = 11,
        Legendary = 4
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "antlion_guard",

    Name = "Antlion Guard",

    Class = "npc_antlionguard",

    Faction = "Antlion",

    BaseHealth = 540,
    BaseXP = 50,

    LevelRange = {4, 5},

    LootChance = 55,

    RarityWeights = {
        Common = 30,
        Uncommon = 30,
        Rare = 22,
        Epic = 13,
        Legendary = 5
    },

    Reinforcements = {
        TriggerHealthPercent = 0.5,
        Count = {2, 3},
        NPCIDs = {
            "antlion"
        }
    },

    Variants = {
        normal = 68,
        elite = 20,
        volatile = 5,
        armored = 5,
        alpha = 2
    }

})

LS_NPCs.Register({

    ID = "combine_soldier",

    Name = "Combine Soldier",

    Class = "npc_combine_s",

    Faction = "Combine",

    BaseHealth = 120,
    BaseXP = 14,

    LevelRange = {1, 5},

    LootChance = 16,

    Equipment = {
        "weapon_smg1"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_GOOD,

    ProficiencyByLevel = {
        [4] = WEAPON_PROFICIENCY_VERY_GOOD
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

-- Higher-tier Combine and Resistance troops. The encounter director picks these
-- by enemy level (see encounter.Themes).
LS_NPCs.Register({

    ID = "combine_shotgunner",

    Name = "Shotgun Soldier",

    Class = "npc_combine_s",

    Faction = "Combine",

    Skin = 1,

    BaseHealth = 130,
    BaseXP = 16,

    LevelRange = {2, 5},

    LootChance = 16,

    Equipment = {
        "weapon_shotgun"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_GOOD,

    ProficiencyByLevel = {
        [4] = WEAPON_PROFICIENCY_VERY_GOOD
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "combine_elite_soldier",

    Name = "Elite Soldier",

    Class = "npc_combine_s",

    Model = "models/combine_super_soldier.mdl",

    Faction = "Combine",

    BaseHealth = 210,
    BaseXP = 22,

    LevelRange = {3, 5},

    LootChance = 18,

    Equipment = {
        "weapon_ar2"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_VERY_GOOD,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "rebel_shotgunner",

    Name = "Rebel Shotgunner",

    Class = "npc_citizen",

    Faction = "Resistance",

    BaseHealth = 110,
    BaseXP = 14,

    LevelRange = {2, 5},

    LootChance = 15,

    Equipment = {
        "weapon_shotgun"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_GOOD,

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

LS_NPCs.Register({

    ID = "rebel_veteran",

    Name = "Rebel Veteran",

    Class = "npc_citizen",

    Faction = "Resistance",

    BaseHealth = 160,
    BaseXP = 18,

    LevelRange = {3, 5},

    LootChance = 16,

    Equipment = {
        "weapon_ar2"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_GOOD,

    ProficiencyByLevel = {
        [4] = WEAPON_PROFICIENCY_VERY_GOOD
    },

    Variants = {
        normal = 70,
        elite = 20,
        volatile = 5,
        armored = 5
    }

})

-- Boss-grade Alpha hunt targets. They are only spawned as Alphas by contracts
-- and call in their own faction's reinforcements several times during the
-- fight, so their health is tuned to roughly match the Antlion Guard's.
local function bossWaves()
    return {
        {TriggerHealthPercent = 0.8, Count = {2, 3}},
        {TriggerHealthPercent = 0.55, Count = {2, 3}},
        {TriggerHealthPercent = 0.3, Count = {3, 4}}
    }
end

local combineWaves = bossWaves()
local resistanceWaves = bossWaves()
for _, wave in ipairs(combineWaves) do wave.NPCIDs = {"metropolice"} end
for _, wave in ipairs(resistanceWaves) do wave.NPCIDs = {"rebel"} end

LS_NPCs.Register({

    ID = "combine_elite",

    Name = "Combine Elite",

    Class = "npc_combine_s",

    Model = "models/combine_super_soldier.mdl",

    Faction = "Combine",

    BaseHealth = 650,
    BaseXP = 60,

    LevelRange = {4, 5},

    LootChance = 100,

    RarityWeights = {
        Common = 30,
        Uncommon = 30,
        Rare = 22,
        Epic = 13,
        Legendary = 5
    },

    Equipment = {
        "weapon_ar2"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_VERY_GOOD,

    Reinforcements = {
        Waves = combineWaves
    },

    Variants = {
        normal = 100
    }

})

LS_NPCs.Register({

    ID = "rebel_commander",

    Name = "Rebel Commander",

    Class = "npc_citizen",

    Faction = "Resistance",

    BaseHealth = 600,
    BaseXP = 55,

    LevelRange = {4, 5},

    LootChance = 100,

    RarityWeights = {
        Common = 30,
        Uncommon = 30,
        Rare = 22,
        Epic = 13,
        Legendary = 5
    },

    Equipment = {
        "weapon_ar2"
    },

    WeaponProficiency = WEAPON_PROFICIENCY_VERY_GOOD,

    Reinforcements = {
        Waves = resistanceWaves
    },

    Variants = {
        normal = 100
    }

})

hook.Add("OnEntityCreated", "LS_NPCHeadcrabHUD", function(npc)

    if npc:GetClass() ~= "npc_headcrab" then
        return
    end

    timer.Simple(0, function()

        if not IsValid(npc) or
            npc:GetNW2Bool("LS_IsFrameworkNPC", false) then
            return
        end

        local maxHealth = math.max(
            1,
            npc:Health(),
            npc:GetMaxHealth()
        )

        npc.LS_Name = "Headcrab"
        npc.LS_BaseName = "Headcrab"
        npc.LS_Level = 1
        npc.LS_MaxHealth = maxHealth

        npc:SetNW2String("LS_Name", "Headcrab")
        npc:SetNW2String("LS_Variant", "")
		npc:SetNW2String("LS_VariantBadge", "")
		npc:SetNW2Vector("LS_VariantColor", Vector(255, 255, 255))
        npc:SetNW2Int("LS_Level", 1)
        npc:SetNW2Int("LS_MaxHealth", maxHealth)
        npc:SetNW2Bool("LS_IsFrameworkNPC", true)

        LS_NPCs.ApplyNPCRelationships(npc)

    end)

end)

hook.Add("PlayerSpawn", "LS_NPCRefreshPlayerRelationships", function(ply)

    timer.Simple(0, function()

        if not IsValid(ply) then
            return
        end

        for _, npc in ipairs(ents.FindByClass("npc_*")) do
            if IsValid(npc) and npc.LS_Definition then
                LS_NPCs.ApplyRelationships(npc, npc.LS_Definition)
            end
        end

    end)

end)

-- Keep your existing hook below this.
hook.Add("OnNPCKilled", "LS_NPCLootDrop", function(npc, attacker, inflictor)

    local definition = npc.LS_Definition

    if not definition then
        return
    end

    if math.random(100) > npc.LS_LootChance then
        return
    end

    local loot = ents.Create("ls_loot")

    if not IsValid(loot) then
        return
    end

    loot:SetPos(
        npc:GetPos() + Vector(0, 0, 20)
    )

    loot:SetItem(
        LS_Items.GenerateItem(
            LS_Missions and LS_Missions.AdjustLootWeights and
            LS_Missions.AdjustLootWeights(npc.LS_RarityWeights) or
            npc.LS_RarityWeights
        )
    )

    loot:Spawn()

end)

hook.Add("OnNPCKilled", "LS_NPCVolatileDeath", function(npc, attacker, inflictor)

    if npc:GetNW2String("LS_Variant", "") ~= "volatile" then
        return
    end

    -- BlastDamage can still touch this dying NPC during OnNPCKilled. Marking it
    -- first makes the death effect strictly one-shot instead of recursively
    -- invoking this hook until the engine crashes.
    if npc.LS_VolatileDetonated then
        return
    end

    npc.LS_VolatileDetonated = true

    if not LS_Combat or not LS_Combat.CreateExplosion then
        return
    end

    LS_Combat.CreateExplosion(
        {
            Attacker = IsValid(attacker) and attacker or npc,
            Weapon = IsValid(inflictor) and inflictor or npc
        },
        npc:WorldSpaceCenter(),
        45,
        170
    )

end)

function LS_NPCs.CleanupRagdoll(ragdoll)

    if not IsValid(ragdoll) or ragdoll.LS_CorpseCleanupQueued then
        return
    end

    ragdoll.LS_CorpseCleanupQueued = true

    ragdoll:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
    ragdoll:SetRenderMode(RENDERMODE_TRANSCOLOR)

    local physicsObject = ragdoll:GetPhysicsObject()

    if IsValid(physicsObject) then
        physicsObject:EnableCollisions(false)
    end

    local fadeStart = 4
    local fadeSteps = 10

    for step = 1, fadeSteps do
        timer.Simple(fadeStart + step * 0.1, function()
            if IsValid(ragdoll) then
                ragdoll:SetColor(Color(
                    255,
                    255,
                    255,
                    math.floor(255 * (1 - step / fadeSteps))
                ))
            end
        end)
    end

    timer.Simple(fadeStart + 1.1, function()
        if IsValid(ragdoll) then
            ragdoll:Remove()
        end
    end)

end

hook.Add("CreateEntityRagdoll", "LS_NPCCorpseCleanup", function(npc, ragdoll)

    if not IsValid(npc) or not (npc.LS_Definition or
        npc.LS_BaseName == "Headcrab" or
        npc:GetNW2Bool("LS_IsFrameworkNPC", false)) then
        return
    end

    LS_NPCs.CleanupRagdoll(ragdoll)

end)

-- Some Source NPCs do not consistently provide their ragdoll to
-- CreateEntityRagdoll. Zombie and headcrab corpses can be created several
-- ticks after OnNPCKilled, so retry for a short window rather than checking
-- only once. CleanupRagdoll is idempotent, making duplicate detection safe.
hook.Add("OnNPCKilled", "LS_NPCCorpseCleanupFallback", function(npc)

    if not IsValid(npc) or not (npc.LS_Definition or
        npc.LS_BaseName == "Headcrab" or
        npc:GetNW2Bool("LS_IsFrameworkNPC", false)) then
        return
    end

    local deathPosition = npc:GetPos()

    for attempt = 1, 12 do
        timer.Simple(attempt * 0.15, function()
            local closestRagdoll
            local closestDistance = math.huge

            for _, entity in ipairs(ents.FindInSphere(deathPosition, 150)) do
                if IsValid(entity) and entity:GetClass() == "prop_ragdoll" then
                    local distance = entity:GetPos():DistToSqr(deathPosition)

                    if distance < closestDistance then
                        closestDistance = distance
                        closestRagdoll = entity
                    end
                end
            end

            LS_NPCs.CleanupRagdoll(closestRagdoll)
        end)
    end

end)

hook.Add("EntityTakeDamage", "LS_NPCArmoredDamageReduction", function(npc, dmginfo)

    if not IsValid(npc) or not npc:IsNPC() then
        return
    end

    local reduction = npc.LS_DamageReduction or 0

    if reduction <= 0 then
        return
    end

    -- Armor Breaker ignores a percentage of the reduction.
    local pierce = LS_Talents.GetPlayerRoll(dmginfo:GetAttacker(), "armor_breaker", "ArmorPierce")

    if pierce then
        reduction = reduction * (1 - math.Clamp(pierce, 0, 100) / 100)
    end

    dmginfo:ScaleDamage(math.Clamp(1 - reduction, 0, 1))

end)

hook.Add("EntityTakeDamage", "LS_NPCPreventFriendlyDamage", function(target, dmginfo)

    local attacker = dmginfo:GetAttacker()

    if not IsValid(target) or not IsValid(attacker) or
        not target:IsNPC() or not attacker:IsNPC() or
        not target:GetNW2Bool("LS_IsFrameworkNPC", false) or
        not attacker:GetNW2Bool("LS_IsFrameworkNPC", false) then
        return
    end

    return true

end)

hook.Add("ShouldCollide", "LS_NPCPreventCollisions", function(first, second)

    if not IsValid(first) or not IsValid(second) or
        not first:IsNPC() or not second:IsNPC() or
        not first:GetNW2Bool("LS_IsFrameworkNPC", false) or
        not second:GetNW2Bool("LS_IsFrameworkNPC", false) then
        return
    end

    return false

end)

-- Variants get a body tint (their color blended halfway to white, so the
-- model stays readable). Outline halos and health bar badges are client side.
function LS_NPCs.ApplyVariantVisuals(npc, variant)

    if not variant or variant.ID == "normal" or not variant.Color then
        return
    end

    local c = variant.Color

    npc:SetColor(Color(
        Lerp(0.5, 255, c.r),
        Lerp(0.5, 255, c.g),
        Lerp(0.5, 255, c.b)
    ))

end

LS_NPCs.Shielded = LS_NPCs.Shielded or {}

function LS_NPCs.ApplyShield(npc, variant, health)

    if not variant or not variant.ShieldFraction then
        return
    end

    npc.LS_ShieldMax = math.max(1, math.floor(health * variant.ShieldFraction))
    npc.LS_Shield = npc.LS_ShieldMax
    npc.LS_ShieldRegenDelay = variant.ShieldRegenDelay or 7

    npc:SetNW2Int("LS_ShieldMax", npc.LS_ShieldMax)
    npc:SetNW2Int("LS_Shield", npc.LS_Shield)

    table.insert(LS_NPCs.Shielded, npc)

end

if SERVER then

    util.AddNetworkString("LS_ToxicCloud")

    hook.Add("EntityTakeDamage", "LS_NPCShieldAbsorb", function(npc, dmginfo)

        if not IsValid(npc) or not npc:IsNPC() or
            not npc.LS_ShieldMax or (npc.LS_Shield or 0) <= 0 then
            return
        end

        local damage = dmginfo:GetDamage()

        if damage <= 0 then
            return
        end

        -- Armor Breaker makes the shield lose more than the damage dealt.
        local shieldBonus = LS_Talents.GetPlayerRoll(dmginfo:GetAttacker(), "armor_breaker", "ShieldBonus")
        local multiplier = 1 + (shieldBonus or 0) / 100
        local effective = damage * multiplier
        local absorbed = math.min(npc.LS_Shield, effective)

        LS_Combat.ShowDamageNumber(dmginfo:GetAttacker(), npc:WorldSpaceCenter(), absorbed / multiplier, 5)

        npc.LS_Shield = npc.LS_Shield - absorbed
        npc.LS_ShieldHitAt = CurTime()
        dmginfo:SetDamage((effective - absorbed) / multiplier)
        npc:SetNW2Int("LS_Shield", math.floor(npc.LS_Shield))

        if npc.LS_Shield <= 0 then
            npc:EmitSound("ambient/energy/zap1.wav", 80, 90)
            local effect = EffectData()
            effect:SetOrigin(npc:WorldSpaceCenter())
            effect:SetMagnitude(3)
            effect:SetScale(2)
            effect:SetRadius(24)
            util.Effect("cball_explode", effect)
        else
            npc:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 65, 110, 0.6)
        end

    end)

    timer.Create("LS_NPCShieldRegen", 0.5, 0, function()

        for index = #LS_NPCs.Shielded, 1, -1 do

            local npc = LS_NPCs.Shielded[index]

            if not IsValid(npc) or npc:Health() <= 0 then
                table.remove(LS_NPCs.Shielded, index)
            elseif (npc.LS_Shield or 0) <= 0 and
                CurTime() - (npc.LS_ShieldHitAt or 0) >= npc.LS_ShieldRegenDelay then
                npc.LS_Shield = npc.LS_ShieldMax
                npc:SetNW2Int("LS_Shield", npc.LS_Shield)
                npc:EmitSound("ambient/energy/whiteflash.wav", 70, 140, 0.5)
            end

        end

    end)

    -- Toxic NPCs leave a poison cloud where they die. It damages players
    -- standing in it, bypassing armor, and the client draws it as green smoke.
    local CLOUD_RADIUS = 130
    local CLOUD_DURATION = 6

    function LS_NPCs.CreateToxicCloud(position)

        net.Start("LS_ToxicCloud")
            net.WriteVector(position)
            net.WriteFloat(CLOUD_RADIUS)
            net.WriteFloat(CLOUD_DURATION)
        net.Broadcast()

        local endsAt = CurTime() + CLOUD_DURATION
        local timerName = "LS_ToxicCloud_" .. tostring(SysTime()) .. math.random(1000)

        timer.Create(timerName, 0.5, 0, function()

            if CurTime() >= endsAt then
                timer.Remove(timerName)
                return
            end

            for _, player in ipairs(player.GetAll()) do

                if IsValid(player) and player:Alive() and
                    CurTime() >= (player.LS_PoisonImmuneUntil or 0) and
                    player:GetPos():Distance(position) <= CLOUD_RADIUS then

                    local damage = DamageInfo()
                    damage:SetDamage(4)
                    damage:SetDamageType(DMG_POISON)
                    damage:SetAttacker(game.GetWorld())
                    damage:SetInflictor(game.GetWorld())
                    player:TakeDamageInfo(damage)

                end

            end

        end)

    end

    hook.Add("OnNPCKilled", "LS_NPCToxicDeath", function(npc)

        if IsValid(npc) and npc:GetNW2String("LS_Variant", "") == "toxic" then
            LS_NPCs.CreateToxicCloud(npc:WorldSpaceCenter())
        end

    end)

end

function LS_NPCs.FindReinforcementPosition(origin)

    for _ = 1, 8 do

        local direction = Vector(
            math.Rand(-1, 1),
            math.Rand(-1, 1),
            0
        )

        if direction:LengthSqr() <= 0 then
            continue
        end

        direction:Normalize()

        local candidate = origin +
            direction * math.random(120, 220) +
            Vector(0, 0, 96)

        local trace = util.TraceHull({
            start = candidate,
            endpos = candidate - Vector(0, 0, 320),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_NPCSOLID
        })

        if trace.Hit and not trace.StartSolid then
            return trace.HitPos + Vector(0, 0, 4)
        end

    end

    return nil

end

-- Reinforcements are either one group (TriggerHealthPercent / Count / NPCIDs
-- on the definition itself) or a list of groups in .Waves, each with its own
-- health trigger, so a boss can call for help several times.
local function reinforcementGroups(definition)
    local data = definition and definition.Reinforcements
    if not data then
        return nil
    end
    return data.Waves or {data}
end

function LS_NPCs.SpawnReinforcements(npc, group)

    group = group or (npc.LS_Definition and
        npc.LS_Definition.Reinforcements)

    if not group or not group.NPCIDs or #group.NPCIDs == 0 then
        return
    end

    local count = math.random(
        group.Count[1],
        group.Count[2]
    )

    for _ = 1, count do

        local position = LS_NPCs.FindReinforcementPosition(npc:GetPos())

        if position then
            local reinforcement = LS_NPCs.Spawn(
                table.Random(group.NPCIDs),
                position
            )

            if IsValid(reinforcement) then
                reinforcement.LS_SummonedBy = npc
            end

            if IsValid(reinforcement) and npc.LS_EncounterID then
                if LS_Encounter and LS_Encounter.RegisterNPC then
                    LS_Encounter.RegisterNPC(reinforcement)
                else
                    reinforcement.LS_EncounterID = npc.LS_EncounterID
                end
            end
        end

    end

end

hook.Add("EntityTakeDamage", "LS_NPCAlphaReinforcements", function(npc, dmginfo)

    if not IsValid(npc) or not npc:IsNPC() or
        npc.LS_Variant ~= "alpha" or
        npc.LS_ReinforcementsSpawned or
        npc.LS_ReinforcementCheckQueued then
        return
    end

    local groups = reinforcementGroups(npc.LS_Definition)

    if not groups then
        return
    end

    npc.LS_ReinforcementCheckQueued = true

    timer.Simple(0, function()

        if not IsValid(npc) then
            return
        end

        npc.LS_ReinforcementCheckQueued = nil

        local health = npc:Health()

        if health <= 0 then
            return
        end

        npc.LS_ReinforcementsDone = npc.LS_ReinforcementsDone or {}

        local remaining = 0

        for index, group in ipairs(groups) do

            if not npc.LS_ReinforcementsDone[index] then

                if health <= npc.LS_MaxHealth *
                    (group.TriggerHealthPercent or 0.5) then
                    npc.LS_ReinforcementsDone[index] = true
                    LS_NPCs.SpawnReinforcements(npc, group)
                else
                    remaining = remaining + 1
                end

            end

        end

        if remaining == 0 then
            npc.LS_ReinforcementsSpawned = true
        end

    end)

end)

hook.Add("PlayerDroppedWeapon", "LS_NPCRemoveDroppedWeapons", function(owner, weapon)

    if not IsValid(owner) or not owner:IsNPC() or
        not owner.LS_Definition or not IsValid(weapon) then
        return
    end

    -- This is a fallback for NPC types or addons that ignore the native
    -- SF_NPC_NO_WEAPON_DROP spawn flag.
    timer.Simple(0, function()
        if IsValid(weapon) then
            weapon:Remove()
        end
    end)

end)


if SERVER then

    concommand.Add("ls_lootscale", function(_, _, args)

        local scale = tonumber(args[1])

        if scale then
            LS_NPCs.LootScale = math.max(0, scale)
        end

        print("[LS] Loot chance scale: " .. LS_NPCs.LootScale .. " (1 = default, 0 = no drops, 10 = nearly always)")

    end)

end
