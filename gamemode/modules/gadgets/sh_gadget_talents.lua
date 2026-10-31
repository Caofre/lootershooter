-- Gadget talents: perks that only roll on gadgets (Slot = "GADGET"). A talent
-- with a Gadgets list only rolls on those gadgets.
--
-- Events (see sh_gadgets.lua):
--   OnGadgetUse   when the gadget is used; talents change context.Info before
--                 the gadget's effect runs (the gadget reads those fields)
--   OnGadgetKill  when you kill an enemy
--   OnShieldHit   when the Riot Plate absorbs a hit
-- Some talents are passive and are read directly by the gadget's code
-- (Sticky, Cluster, Fortified...): they only need their roll values.

local ACTIVE = {"grenade", "stim", "sentry"}

local function chance(instance)
    return math.random(100) <= (instance.rolls.Chance or 100)
end

----------------------------------------------------------------------
-- Any gadget
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "overcharge",
    Name = "Overcharge",
    Slot = "GADGET",
    Gadgets = ACTIVE,
    Description = "If the gadget has been charged for a while, the next use is stronger.",

    Rolls = {
        Bonus = {20, 50},
        Wait = {6, 12}
    },

    OnGadgetUse = function(context, instance)

        local idle = CurTime() - (context.State.ReadyAt or 0)

        if idle < instance.rolls.Wait then
            return
        end

        context.Info.PowerBonus = (context.Info.PowerBonus or 0) + instance.rolls.Bonus
        LS_Combat.SetBuff(context.Player, "overcharge", "OVERCHARGED  +" .. instance.rolls.Bonus .. "%", 2.5)

    end

})

LS_Talents.Register({

    ID = "quick_recovery",
    Name = "Quick Recovery",
    Slot = "GADGET",
    Description = "Kills shave seconds off the gadget's cooldown.",

    Rolls = {
        Seconds = {1, 3}
    },

    OnGadgetKill = function(context, instance)

        local state = context.State

        if CurTime() >= state.ReadyAt then
            return
        end

        state.ReadyAt = math.max(CurTime(), state.ReadyAt - instance.rolls.Seconds)
        LS_Gadgets.Sync(context.Player)

    end

})

LS_Talents.Register({

    ID = "rhythm",
    Name = "Rhythm",
    Slot = "GADGET",
    Gadgets = ACTIVE,
    Description = "Using the gadget restores part of your armor pool.",

    Rolls = {
        Refill = {10, 25}
    },

    OnGadgetUse = function(context, instance)

        LS_Gadgets.RefillArmor(context.Player, instance.rolls.Refill)

    end

})

----------------------------------------------------------------------
-- Frag Grenade
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "sticky",
    Name = "Sticky",
    Slot = "GADGET",
    Gadgets = {"grenade"},
    Description = "The grenade sticks to the first enemy it touches, and hits harder if it does.",

    Rolls = {
        Bonus = {15, 40}
    },

    OnGadgetUse = function(context, instance)
        context.Info.StickyBonus = instance.rolls.Bonus
    end

})

LS_Talents.Register({

    ID = "cluster",
    Name = "Cluster",
    Slot = "GADGET",
    Gadgets = {"grenade"},
    Description = "The grenade bursts into smaller bomblets.",

    Rolls = {
        Count = {3, 5},
        Damage = {25, 45}
    },

    OnGadgetUse = function(context, instance)
        context.Info.ClusterCount = instance.rolls.Count
        context.Info.ClusterDamage = instance.rolls.Damage
    end

})

LS_Talents.Register({

    ID = "incendiary",
    Name = "Incendiary",
    Slot = "GADGET",
    Gadgets = {"grenade"},
    Description = "The blast leaves a burning area that sets enemies on fire.",

    Rolls = {
        Duration = {4, 8},
        Damage = {5, 12}
    },

    OnGadgetUse = function(context, instance)
        context.Info.FireDuration = instance.rolls.Duration
        context.Info.FireDamage = instance.rolls.Damage
    end

})

LS_Talents.Register({

    ID = "concussive",
    Name = "Concussive",
    Slot = "GADGET",
    Gadgets = {"grenade"},
    Description = "The blast knocks enemies back and stuns them.",

    Rolls = {
        Force = {300, 600},
        Stun = {1, 2}
    },

    OnGadgetUse = function(context, instance)
        context.Info.ConcussiveForce = instance.rolls.Force
        context.Info.ConcussiveStun = instance.rolls.Stun
    end

})

----------------------------------------------------------------------
-- Stim Shot
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "overdose",
    Name = "Overdose",
    Slot = "GADGET",
    Gadgets = {"stim"},
    Description = "While the stim is active, you move and shoot faster.",

    Rolls = {
        Speed = {10, 25},
        FireRate = {10, 30}
    },

    OnGadgetUse = function(context, instance)
        context.Info.OverdoseSpeed = instance.rolls.Speed
        context.Info.OverdoseFireRate = instance.rolls.FireRate
    end

})

LS_Talents.Register({

    ID = "cleanse",
    Name = "Cleanse",
    Slot = "GADGET",
    Gadgets = {"stim"},
    Description = "Using the stim removes slows and grants brief immunity to toxins.",

    Rolls = {
        Immunity = {3, 8}
    },

    OnGadgetUse = function(context, instance)
        context.Info.CleanseSeconds = instance.rolls.Immunity
    end

})

LS_Talents.Register({

    ID = "armor_stim",
    Name = "Armor Stim",
    Slot = "GADGET",
    Gadgets = {"stim"},
    Description = "The stim also restores part of your armor pool.",

    Rolls = {
        Refill = {20, 50}
    },

    OnGadgetUse = function(context, instance)
        LS_Gadgets.RefillArmor(context.Player, instance.rolls.Refill)
    end

})

----------------------------------------------------------------------
-- Riot Plate
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "spiked",
    Name = "Spiked",
    Slot = "GADGET",
    Gadgets = {"shield"},
    Description = "Enemies that hit the plate up close take damage back.",

    Rolls = {
        Reflect = {40, 120}
    },

    OnShieldHit = function(context, instance)

        local attacker, player = context.Attacker, context.Player

        if not IsValid(attacker) or not attacker:IsNPC() or
            attacker:GetPos():DistToSqr(player:GetPos()) > 250 * 250 then
            return
        end

        LS_Combat.DealTalentDamage(
            {Attacker = player, Weapon = player},
            attacker,
            math.max(1, math.floor(context.Damage * instance.rolls.Reflect / 100)),
            DMG_GENERIC
        )

    end

})

LS_Talents.Register({

    ID = "reflective",
    Name = "Reflective",
    Slot = "GADGET",
    Gadgets = {"shield"},
    Description = "Hits can bounce off the plate without wearing it down, and strike back.",

    Rolls = {
        Chance = {10, 30},
        Damage = {50, 100}
    },

    OnShieldHit = function(context, instance)

        local plate, attacker = context.Plate, context.Attacker

        if not chance(instance) or not IsValid(plate) then
            return
        end

        -- Give the durability back, and return fire.
        plate:SetDurability(math.min(plate:GetMaxDurability(), plate:GetDurability() + context.Damage))
        plate:SyncWearer()
        plate:EmitSound("weapons/fx/rics/ric" .. math.random(1, 5) .. ".wav", 75, 100)

        if IsValid(attacker) and attacker:IsNPC() then
            LS_Combat.DealTalentDamage(
                {Attacker = context.Player, Weapon = context.Player},
                attacker,
                math.max(1, math.floor(context.Damage * instance.rolls.Damage / 100)),
                DMG_BULLET
            )

            LS_Effects.TeslaBeam(plate:GetPos(), attacker:WorldSpaceCenter())
        end

    end

})

LS_Talents.Register({

    ID = "fortified",
    Name = "Fortified",
    Slot = "GADGET",
    Gadgets = {"shield"},
    Description = "A tougher plate, but it takes longer to rebuild.",

    Rolls = {
        Durability = {25, 60},
        Cooldown = {20, 50}
    }

    -- Passive: read when the plate is built and when it breaks.

})

----------------------------------------------------------------------
-- Sentry Turret (all passive: read when the turret is deployed)
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "twin",
    Name = "Twin",
    Slot = "GADGET",
    Gadgets = {"sentry"},
    Description = "Deploy two turrets, each staying up for less time.",

    Rolls = {
        Penalty = {20, 40}
    },

    OnGadgetUse = function(context, instance)
        context.Info.TwinPenalty = instance.rolls.Penalty
    end

})

LS_Talents.Register({

    ID = "rocket_pod",
    Name = "Rocket Pod",
    Slot = "GADGET",
    Gadgets = {"sentry"},
    Description = "The turret also launches slower, explosive shots.",

    Rolls = {
        Damage = {25, 60}
    },

    OnGadgetUse = function(context, instance)
        context.Info.RocketDamage = instance.rolls.Damage
    end

})

LS_Talents.Register({

    ID = "tesla_coil",
    Name = "Tesla Coil",
    Slot = "GADGET",
    Gadgets = {"sentry"},
    Description = "The turret's shots can chain to nearby enemies.",

    Rolls = {
        Chance = {20, 40},
        Damage = {30, 60},
        Targets = {1, 3}
    },

    OnGadgetUse = function(context, instance)
        context.Info.TeslaChance = instance.rolls.Chance
        context.Info.TeslaDamage = instance.rolls.Damage
        context.Info.TeslaTargets = instance.rolls.Targets
    end

})

LS_Talents.Register({

    ID = "decoy",
    Name = "Decoy",
    Slot = "GADGET",
    Gadgets = {"sentry"},
    Description = "Nearby enemies are drawn toward the turret.",

    Rolls = {
        Radius = {500, 900},
        Chance = {40, 80}
    },

    OnGadgetUse = function(context, instance)
        context.Info.DecoyRadius = instance.rolls.Radius
        context.Info.DecoyChance = instance.rolls.Chance
    end

})
