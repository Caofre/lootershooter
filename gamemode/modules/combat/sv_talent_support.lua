-- Server plumbing for the extra talents: kill / miss / reload triggers,
-- a damage-over-time engine, and HUD buff labels.

if not SERVER then
    return
end

----------------------------------------------------------------------
-- Movement speed multipliers. Several effects (Cryo slow, Adrenaline) can be
-- active together, so each sets its own named multiplier and the product is applied.
----------------------------------------------------------------------

function LS_Combat.SetMoveMod(player, key, multiplier)

    if not IsValid(player) then
        return
    end

    player.LS_MoveMods = player.LS_MoveMods or {}
    player.LS_MoveMods[key] = multiplier

    local product = 1

    for _, value in pairs(player.LS_MoveMods) do
        product = product * value
    end

    player:SetLaggedMovementValue(product)

end

-- Fire rate multipliers on a weapon (Momentum, Overdose). Each effect sets its
-- own named multiplier; the weapon's delay is its base delay divided by the product.
function LS_Combat.SetWeaponFireMod(weapon, key, multiplier)

    if not IsValid(weapon) or not weapon.Primary or not weapon.Primary.Delay then
        return
    end

    weapon.LS_DelayBase = weapon.LS_DelayBase or weapon.Primary.Delay
    weapon.LS_FireMods = weapon.LS_FireMods or {}
    weapon.LS_FireMods[key] = multiplier

    local product = 1

    for _, value in pairs(weapon.LS_FireMods) do
        product = product * value
    end

    weapon.Primary.Delay = weapon.LS_DelayBase / product

end

----------------------------------------------------------------------
-- Buff labels (shown on the HUD by cl_hud.lua)
----------------------------------------------------------------------

function LS_Combat.SetBuff(player, id, text, duration)

    if not IsValid(player) or not player:IsPlayer() then
        return
    end

    player:SetNW2String("LS_Buff_" .. id, text)
    player:SetNW2Float("LS_BuffEnd_" .. id, CurTime() + duration)

end

function LS_Combat.ClearBuff(player, id)

    if IsValid(player) and player:IsPlayer() then
        player:SetNW2Float("LS_BuffEnd_" .. id, 0)
    end

end

----------------------------------------------------------------------
-- Trigger relays
----------------------------------------------------------------------

local function relay(eventName, player, weapon, target)

    if not IsValid(player) or not player:IsPlayer() then
        return
    end

    local item = LS_Equipment.GetEquippedWeaponItem(player)

    if not item then
        return
    end

    LS_Talents.Trigger(eventName, LS_Combat.BuildContext(player, target, weapon, item), item)

end

hook.Add("OnNPCKilled", "LS_Combat_OnKill", function(npc, attacker)

    if IsValid(attacker) and attacker:IsPlayer() then
        relay("OnKill", attacker, attacker:GetActiveWeapon(), npc)
    end

end)

-- Raised by weapon_ls_base after each shot: `hit` says whether any bullet
-- struck an NPC.
hook.Add("LS_WeaponFired", "LS_Combat_OnMiss", function(weapon, owner, hit)

    if not hit then
        relay("OnMiss", owner, weapon)
    end

end)

hook.Add("LS_WeaponReload", "LS_Combat_OnReload", function(weapon, owner)

    relay("OnReload", owner, weapon)

end)

----------------------------------------------------------------------
-- Damage over time (Bleed, Burn)
----------------------------------------------------------------------

LS_Combat.Dots = LS_Combat.Dots or {}

local DOT_TICK = 0.5

function LS_Combat.ApplyDot(target, context, id, damagePerSecond, duration, generation, spreads)

    if not IsValid(target) or not target:IsNPC() or target:Health() <= 0 then
        return
    end

    local key = target:EntIndex() .. "_" .. id
    local existing = LS_Combat.Dots[key]
    local endsAt = CurTime() + duration

    if existing and existing.Target == target then
        existing.EndsAt = math.max(existing.EndsAt, endsAt)
        existing.Dps = math.max(existing.Dps, damagePerSecond)
        return
    end

    LS_Combat.Dots[key] = {
        Target = target,
        Attacker = context.Attacker,
        Weapon = context.Weapon,
        ID = id,
        Dps = damagePerSecond,
        EndsAt = endsAt,
        Generation = generation or 0,
        Spreads = spreads
    }

end

local function spreadFire(dot)

    local source = dot.Target

    for _, entity in ipairs(ents.FindInSphere(source:GetPos(), 150)) do

        if entity ~= source and IsValid(entity) and entity:IsNPC() and entity:Health() > 0 and
            entity:GetNW2Bool("LS_IsFrameworkNPC", false) and
            not LS_Combat.Dots[entity:EntIndex() .. "_burn"] then

            LS_Combat.ApplyDot(
                entity,
                {Attacker = dot.Attacker, Weapon = dot.Weapon},
                "burn",
                dot.Dps,
                math.max(2, dot.EndsAt - CurTime()),
                dot.Generation + 1,
                dot.Generation < 1
            )

            return

        end

    end

end

timer.Create("LS_CombatDots", DOT_TICK, 0, function()

    local now = CurTime()

    for key, dot in pairs(LS_Combat.Dots) do

        local target = dot.Target

        if not IsValid(target) or target:Health() <= 0 or now >= dot.EndsAt then

            if IsValid(target) and dot.ID == "burn" then
                target:Extinguish()
            end

            LS_Combat.Dots[key] = nil

        else

            local attacker = IsValid(dot.Attacker) and dot.Attacker or game.GetWorld()
            local damage = DamageInfo()

            damage:SetDamage(dot.Dps * DOT_TICK)
            damage:SetAttacker(attacker)
            damage:SetInflictor(IsValid(dot.Weapon) and dot.Weapon or attacker)
            damage:SetDamageType(dot.ID == "burn" and DMG_BURN or DMG_GENERIC)

            LS_Combat.SuppressTalentTriggers(function()
                target:TakeDamageInfo(damage)
            end)

            if dot.ID == "burn" then
                target:Ignite(0.8)

                if dot.Spreads and math.random() < 0.25 then
                    spreadFire(dot)
                end
            else
                local effect = EffectData()
                effect:SetOrigin(target:WorldSpaceCenter())
                util.Effect("BloodImpact", effect)
            end

        end

    end

end)


----------------------------------------------------------------------
-- Freezing: roots an NPC in place for a moment (Frost). Nothing can be
-- frozen again for a few seconds after it thaws, and bosses thaw in half the time.
----------------------------------------------------------------------

local FREEZE_IMMUNITY = 4

function LS_Combat.FreezeNPC(npc, duration)

    if not IsValid(npc) or not npc:IsNPC() or npc:Health() <= 0 or
        CurTime() < (npc.LS_FreezeImmuneUntil or 0) then
        return false
    end

    if npc.LS_Variant == "alpha" then
        duration = duration * 0.5
    end

    npc.LS_FreezeImmuneUntil = CurTime() + duration + FREEZE_IMMUNITY
    npc.LS_PreFreezeColor = npc:GetColor()

    npc.LS_Frozen = true
    npc:SetSchedule(SCHED_NPC_FREEZE)
    npc:SetColor(Color(185, 230, 255))
    npc:EmitSound("physics/glass/glass_impact_bullet" .. math.random(1, 4) .. ".wav", 75, 110)

    local effect = EffectData()
    effect:SetOrigin(npc:WorldSpaceCenter())
    util.Effect("GlassImpact", effect)

    timer.Simple(duration, function()

        if not IsValid(npc) or npc:Health() <= 0 then
            return
        end

        npc.LS_Frozen = nil
        npc:SetCondition(COND.NPC_UNFREEZE)
        npc:ClearSchedule()

        if npc.LS_PreFreezeColor then
            npc:SetColor(npc.LS_PreFreezeColor)
            npc.LS_PreFreezeColor = nil
        end

    end)

    return true

end


----------------------------------------------------------------------
-- Dying NPCs must never stay frozen or slowed.
----------------------------------------------------------------------

function LS_Combat.ReleaseNPC(npc)

    if not IsValid(npc) then
        return
    end

    npc.LS_Frozen = nil
    npc.LS_FrostFactor = nil

    npc:SetCondition(COND.NPC_UNFREEZE)
    npc:SetPlaybackRate(1)

end

local function releaseIfDead(npc)

    if not IsValid(npc) or not npc:IsNPC() or npc:Health() > 0 then
        return
    end

    LS_Combat.ReleaseNPC(npc)

    -- Once more shortly after, in case the death schedule re-applied a rate.
    timer.Simple(0.1, function()
        if IsValid(npc) then
            npc:SetCondition(COND.NPC_UNFREEZE)
            npc:SetPlaybackRate(1)
        end
    end)

end

hook.Add("PostEntityTakeDamage", "LS_ReleaseDyingNPC", function(target)
    releaseIfDead(target)
end)

hook.Add("OnNPCKilled", "LS_ReleaseKilledNPC", function(npc)
    releaseIfDead(npc)
end)
