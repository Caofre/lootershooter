-- Additional weapon talents.
--
-- Triggers used here (see sv_talent_support.lua for the plumbing):
--   OnHit    before a hit's damage is applied; context.DamageInfo can be scaled
--   OnKill   when the player kills an NPC
--   OnMiss   when a shot hit nothing
--   OnReload when a reload starts
-- Passive talents (Armor Breaker) are read straight from the equipped item.

function LS_Talents.GetInstance(item, talentID)

    if not item or not item.talents then
        return nil
    end

    for _, instance in ipairs(item.talents) do
        if instance.id == talentID then
            return instance
        end
    end

    return nil

end

-- A rolled value from the player's currently equipped weapon, or nil.
function LS_Talents.GetPlayerRoll(player, talentID, rollName)

    if not IsValid(player) or not player:IsPlayer() or not LS_Equipment then
        return nil
    end

    local instance = LS_Talents.GetInstance(LS_Equipment.GetEquippedWeaponItem(player), talentID)

    return instance and instance.rolls[rollName] or nil

end

local function passesChance(instance)
    return math.random(100) <= (instance.rolls.Chance or 100)
end

local function refill(weapon, percent)

    if not IsValid(weapon) or not weapon.Primary or (weapon.Primary.ClipSize or 0) <= 0 then
        return
    end

    local maxClip = math.floor(weapon.Primary.ClipSize)

    weapon:SetClip1(math.min(maxClip, weapon:Clip1() + math.max(1, math.ceil(maxClip * percent / 100))))

end

----------------------------------------------------------------------
-- On kill
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "bounty",
    Name = "Bounty",
    Description = "Kills have a chance to pay out credits.",

    Rolls = {
        Chance = {25, 50},
        Credits = {3, 8}
    },

    OnKill = function(context, instance)

        if not passesChance(instance) then
            return
        end

        local level = IsValid(context.Target) and context.Target.LS_Level or 1
        local amount = math.floor(instance.rolls.Credits * (1 + (level - 1) * 0.25))

        LS_Currency.Add(context.Attacker, amount, "Bounty")

    end

})

LS_Talents.Register({

    ID = "momentum",
    Name = "Momentum",
    Description = "Kills briefly stack extra fire rate.",

    Rolls = {
        FireRate = {4, 8},
        MaxStacks = {3, 6},
        Duration = {3, 5}
    },

    OnKill = function(context, instance)

        local weapon = context.Weapon

        if not IsValid(weapon) or not weapon.Primary or not weapon.Primary.Delay then
            return
        end

        weapon.LS_MomentumStacks = math.min(instance.rolls.MaxStacks, (weapon.LS_MomentumStacks or 0) + 1)
        LS_Combat.SetWeaponFireMod(weapon, "momentum", 1 + weapon.LS_MomentumStacks * instance.rolls.FireRate / 100)

        LS_Combat.SetBuff(context.Attacker, "momentum",
            "MOMENTUM x" .. weapon.LS_MomentumStacks, instance.rolls.Duration)

        local timerName = "LS_Momentum_" .. weapon:EntIndex()

        timer.Create(timerName, instance.rolls.Duration, 1, function()
            if IsValid(weapon) then
                weapon.LS_MomentumStacks = 0
                LS_Combat.SetWeaponFireMod(weapon, "momentum", nil)
            end
        end)

    end

})

LS_Talents.Register({

    ID = "last_stand",
    Name = "Last Stand",
    Description = "Kills can refill part of the magazine.",

    Rolls = {
        Chance = {40, 80},
        Refill = {20, 50}
    },

    OnKill = function(context, instance)

        if passesChance(instance) then
            refill(context.Weapon, instance.rolls.Refill)
        end

    end

})

----------------------------------------------------------------------
-- On reload
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "quick_hands",
    Name = "Quick Hands",
    Description = "Reloads have a chance to finish instantly.",

    Rolls = {
        Chance = {15, 35}
    },

    OnReload = function(context, instance)

        local weapon = context.Weapon

        if passesChance(instance) and IsValid(weapon) and weapon.CompleteReloadNow then
            weapon:CompleteReloadNow()
            context.Attacker:EmitSound("buttons/button17.wav", 60, 130, 0.5)
        end

    end

})

LS_Talents.Register({

    ID = "shockwave",
    Name = "Shockwave",
    Description = "Reloading can blast nearby enemies away.",

    Rolls = {
        Chance = {25, 50},
        Radius = {150, 250},
        Force = {350, 650}
    },

    OnReload = function(context, instance)

        if not passesChance(instance) then
            return
        end

        local origin = context.Attacker:GetPos()

        for _, entity in ipairs(ents.FindInSphere(origin, instance.rolls.Radius)) do

            if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 then

                local direction = entity:GetPos() - origin
                direction.z = 0
                direction:Normalize()

                entity:SetGroundEntity(NULL)
                entity:SetVelocity(direction * instance.rolls.Force + Vector(0, 0, 160))

            end

        end

        local effect = EffectData()
        effect:SetOrigin(origin + Vector(0, 0, 8))
        effect:SetScale(instance.rolls.Radius / 80)
        util.Effect("ThumperDust", effect)

        sound.Play("physics/concrete/boulder_impact_hard" .. math.random(1, 4) .. ".wav", origin, 75, 110)

    end

})

----------------------------------------------------------------------
-- On hit: damage modifiers
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "headhunter",
    Name = "Headhunter",
    Description = "Headshots deal bonus damage.",

    Rolls = {
        Bonus = {35, 90}
    },

    OnHit = function(context, instance)

        if not context.Headshot or not context.DamageInfo then
            return
        end

        context.DamageInfo:ScaleDamage(1 + instance.rolls.Bonus / 100)
        context.Attacker:EmitSound("buttons/blip1.wav", 65, 190, 0.7)

    end

})

LS_Talents.Register({

    ID = "piercing",
    Name = "Piercing",
    Description = "Bullets can pass through to hit the enemy behind.",

    Rolls = {
        Chance = {20, 45},
        DamagePercent = {50, 90}
    },

    OnHit = function(context, instance)

        if not passesChance(instance) or not IsValid(context.Target) then
            return
        end

        local direction = context.HitDirection or context.Attacker:GetAimVector()
        local start = context.Target:WorldSpaceCenter()

        local trace = util.TraceLine({
            start = start,
            endpos = start + direction * 700,
            filter = {context.Attacker, context.Target},
            mask = MASK_SHOT
        })

        if trace.Hit and IsValid(trace.Entity) and trace.Entity:IsNPC() then

            LS_Combat.DealTalentDamage(
                context,
                trace.Entity,
                math.max(1, math.floor(context.Damage * instance.rolls.DamagePercent / 100)),
                DMG_BULLET
            )

            LS_Effects.TeslaBeam(start, trace.HitPos)

        end

    end

})

LS_Talents.Register({

    ID = "marksman",
    Name = "Marksman",
    Description = "Damage grows the longer you keep hitting the same target. A miss resets it.",

    Rolls = {
        PerStack = {3, 6},
        MaxStacks = {4, 8}
    },

    OnHit = function(context, instance)

        local weapon, now = context.Weapon, CurTime()

        if not IsValid(weapon) or not context.DamageInfo then
            return
        end

        if weapon.LS_MarkTarget == context.Target and now - (weapon.LS_MarkLast or 0) <= 2 then
            weapon.LS_MarkStacks = math.min(instance.rolls.MaxStacks, (weapon.LS_MarkStacks or 1) + 1)
        else
            weapon.LS_MarkTarget = context.Target
            weapon.LS_MarkStacks = 1
        end

        weapon.LS_MarkLast = now

        local bonus = (weapon.LS_MarkStacks - 1) * instance.rolls.PerStack

        if bonus > 0 then
            context.DamageInfo:ScaleDamage(1 + bonus / 100)
            LS_Combat.SetBuff(context.Attacker, "marksman",
                "MARKSMAN x" .. weapon.LS_MarkStacks .. "  +" .. bonus .. "%", 2)
        end

    end,

    OnMiss = function(context)

        local weapon = context.Weapon

        if IsValid(weapon) then
            weapon.LS_MarkTarget = nil
            weapon.LS_MarkStacks = 0
            LS_Combat.ClearBuff(context.Attacker, "marksman")
        end

    end

})

LS_Talents.Register({

    ID = "execution",
    Name = "Execution",
    Description = "Bonus damage against enemies below a health threshold.",

    Rolls = {
        Threshold = {15, 30},
        Bonus = {50, 120}
    },

    OnHit = function(context, instance)

        local target = context.Target

        if not IsValid(target) or not context.DamageInfo then
            return
        end

        local maxHealth = math.max(1, target.LS_MaxHealth or target:GetMaxHealth())

        if target:Health() / maxHealth * 100 <= instance.rolls.Threshold then
            context.DamageInfo:ScaleDamage(1 + instance.rolls.Bonus / 100)
        end

    end

})

LS_Talents.Register({

    ID = "berserker",
    Name = "Berserker",
    Description = "Deal more damage the lower your health is.",

    Rolls = {
        MaxBonus = {25, 70}
    },

    OnHit = function(context, instance)

        local attacker = context.Attacker

        if not context.DamageInfo or not IsValid(attacker) then
            return
        end

        local missing = 1 - math.Clamp(attacker:Health() / math.max(1, attacker:GetMaxHealth()), 0, 1)
        local bonus = math.floor(instance.rolls.MaxBonus * missing)

        if bonus > 0 then
            context.DamageInfo:ScaleDamage(1 + bonus / 100)
            LS_Combat.SetBuff(attacker, "berserker", "BERSERKER  +" .. bonus .. "%", 1.2)
        end

    end

})

LS_Talents.Register({

    ID = "gambler",
    Name = "Gambler",
    Description = "Each hit randomly deals bonus or reduced damage.",

    Rolls = {
        WinChance = {40, 60},
        WinBonus = {60, 120},
        LosePenalty = {30, 60}
    },

    OnHit = function(context, instance)

        if not context.DamageInfo then
            return
        end

        if math.random(100) <= instance.rolls.WinChance then
            context.DamageInfo:ScaleDamage(1 + instance.rolls.WinBonus / 100)
        else
            context.DamageInfo:ScaleDamage(1 - instance.rolls.LosePenalty / 100)
        end

    end

})

LS_Talents.Register({

    ID = "armor_breaker",
    Name = "Armor Breaker",
    Description = "Ignores part of Armored damage reduction and shreds shields and plates faster.",

    Rolls = {
        ArmorPierce = {40, 100},
        ShieldBonus = {30, 80}
    }

    -- Passive: read through LS_Talents.GetPlayerRoll by the damage hooks.

})

----------------------------------------------------------------------
-- On hit: effects
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "scavenger",
    Name = "Scavenger",
    Description = "Hits can refill part of the magazine.",

    Rolls = {
        Chance = {5, 12},
        Refill = {10, 30}
    },

    OnHit = function(context, instance)

        if passesChance(instance) then
            refill(context.Weapon, instance.rolls.Refill)
        end

    end

})

LS_Talents.Register({

    ID = "bleed",
    Name = "Bleed",
    Description = "Hits can cause damage over time.",

    Rolls = {
        Chance = {10, 25},
        Damage = {3, 8},
        Duration = {3, 6}
    },

    OnHit = function(context, instance)

        if passesChance(instance) then
            LS_Combat.ApplyDot(context.Target, context, "bleed", instance.rolls.Damage, instance.rolls.Duration)
        end

    end

})

LS_Talents.Register({

    ID = "burn",
    Name = "Burn",
    Description = "Hits can set enemies on fire. Flames can spread to nearby enemies.",

    Rolls = {
        Chance = {8, 20},
        Damage = {4, 10},
        Duration = {3, 6}
    },

    OnHit = function(context, instance)

        if passesChance(instance) then
            LS_Combat.ApplyDot(context.Target, context, "burn", instance.rolls.Damage, instance.rolls.Duration, 0, true)
        end

    end

})

LS_Talents.Register({

    ID = "stagger",
    Name = "Stagger",
    Description = "Hits can briefly stun the enemy.",

    Rolls = {
        Chance = {8, 18},
        Duration = {1, 2}
    },

    OnHit = function(context, instance)

        local target = context.Target

        if not passesChance(instance) or not IsValid(target) or not target:IsNPC() or
            CurTime() < (target.LS_StaggerImmuneUntil or 0) then
            return
        end

        local duration = instance.rolls.Duration

        -- Alpha bosses only lose half the time, and nothing can be stun-locked.
        if target.LS_Variant == "alpha" then
            duration = duration * 0.5
        end

        target.LS_StaggerImmuneUntil = CurTime() + duration + 3
        target.LS_Frozen = true
        target:SetSchedule(SCHED_NPC_FREEZE)
        target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 70, 120)

        timer.Simple(duration, function()
            if IsValid(target) and target:Health() > 0 then
                target.LS_Frozen = nil
                target:SetCondition(COND.NPC_UNFREEZE)
                target:ClearSchedule()
            end
        end)

    end

})
