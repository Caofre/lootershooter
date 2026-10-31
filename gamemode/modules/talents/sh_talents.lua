LS_Talents = {}

LS_Talents.Registered = {}

function LS_Talents.Register(data)

    data.OnHit = data.OnHit or nil
    data.OnKill = data.OnKill or nil
    data.OnReload = data.OnReload or nil
    data.OnEquip = data.OnEquip or nil

    LS_Talents.Registered[data.ID] = data

end

function LS_Talents.Get(id)

    return LS_Talents.Registered[id]

end

function LS_Talents.GetRandom()

    local talents = {}

    for _, talent in pairs(LS_Talents.Registered) do

        table.insert(talents, talent)

    end

    return table.Random(talents)

end

function LS_Talents.Roll(id)

    local talent = LS_Talents.Get(id)

    if not talent then return nil end

    local rolled = {

        id = id,

        rolls = {}

    }

    for rollName, range in pairs(talent.Rolls) do

        rolled.rolls[rollName] =
            math.random(range[1], range[2])

    end

    return rolled

end

function LS_Talents.List()

    print("=== TALENTS ===")

    for id, talent in pairs(LS_Talents.Registered) do

        print(id, talent.Name)

        for rollName, range in pairs(talent.Rolls) do

            print(
                "   ",
                rollName,
                range[1],
                "-",
                range[2]
            )

        end

    end

end

function LS_Talents.Trigger(eventName, context, item, excludedTalents)

    if not item then
        return
    end

    if not item.talents then
        return
    end

    for _, instance in ipairs(item.talents) do

    local definition =
        LS_Talents.Get(instance.id)

        if definition and not (excludedTalents and
            excludedTalents[instance.id]) then

            local callback =
                definition[eventName]

            if callback then

                callback(
				context,
				instance
			)

            end

        end

    end

end

LS_Talents.Register({

    ID = "tesla",

    Name = "Tesla",

    Description = "Each hit has a chance to zap nearby enemies.",

    Rolls = {

        Chance = {5,15},
        Damage = {8,20},
        Targets = {2,4}

    },

    OnHit = function(context, instance)


    local chance =
    instance.rolls.Chance

	if math.random(100) > chance then
		return
	end

    	local targets =
    LS_Combat.FindNearbyTargets(
        context.Target,
        250,
        instance.rolls.Targets
    )
	
	for _, target in ipairs(targets) do

    LS_Combat.DealTalentDamage(
        context,
        target,
        instance.rolls.Damage,
        DMG_SHOCK
    )

    LS_Effects.TeslaBeam(
        context.Target:WorldSpaceCenter(),
        target:WorldSpaceCenter()
    )

end


end

})

LS_Talents.Register({

    ID = "ricochet",

    Name = "Ricochet",

    Description = "Bullets bounce to nearby enemies.",

    Rolls = {

        Chance = {5,15},
        DamagePercent = {40,80}

    },

    OnHit = function(context, instance)

        local chance =
		instance.rolls.Chance

	if math.random(100) > chance then
		return
	end

        local target =
            LS_Combat.FindNearestTarget(
                context.Target,
                300
            )

        if not IsValid(target) then
            return
        end

        local damage =
		math.max(
			1,
			math.floor(
				context.Damage *
				(instance.rolls.DamagePercent / 100)
			)
		)

        LS_Combat.DealTalentDamage(

            context,

            target,

            damage,

            DMG_BULLET,

            {
                AllowTalentTriggers = true,
                ExcludedTalents = {
                    ricochet = true
                }
            }

        )


    end

})

LS_Talents.Register({

    ID = "explosive",

    Name = "Explosive",

    Description = "Bullets have a chance to explode on impact.",

    Rolls = {

        Chance = {5,15},
        Damage = {20,50},
        Radius = {120,220}

    },

    OnHit = function(context, instance)

        local chance =
		instance.rolls.Chance

	if math.random(100) > chance then
		return
	end

        LS_Combat.CreateExplosion(

            context,

            context.Target:WorldSpaceCenter(),
			
            instance.rolls.Damage,

            instance.rolls.Radius

        )

    end

})

LS_Talents.Register({

    ID = "vampiric",

    Name = "Vampiric",

    Description = "Steals a percentage of damage dealt as health.",

    Rolls = {

        Chance = {10,20},
        LifeSteal = {15,30}

    },

    OnHit = function(context, instance)

        local chance =
		instance.rolls.Chance

	if math.random(100) > chance then
		return
	end

        local healAmount =
            math.max(
                1,
                math.floor(
                    context.Damage *
                    (instance.rolls.LifeSteal / 100)
                )
            )

        LS_Combat.HealPlayer(
            context.Attacker,
            healAmount
        )

    end

})

LS_Talents.Register({

    ID = "frost",

    Name = "Frost",

    Description = "Hits can slow enemies, and sometimes freeze them in place. Deals no damage.",

    Rolls = {

        Chance = {5,15},
        Slow = {20,60},
        Duration = {1,4},
        FreezeChance = {8,20}

    },

    OnHit = function(context, instance)
        if math.random(100) > instance.rolls.Chance then
            return
        end

        LS_Status.Apply(

            context.Target,

            "frost",

            instance.rolls.Duration,

            {

                Slow = instance.rolls.Slow

            }

        )

        -- A slowed enemy can also be frozen solid for a moment.
        if math.random(100) <= (instance.rolls.FreezeChance or 10) then
            LS_Combat.FreezeNPC(context.Target, 1)
        end

    end

})
