-- Gadgets: one equippable ability (grenade, stim, shield, sentry) with a cooldown,
-- used with a key. Gadgets are loot items in the "GADGET" slot, with rarity and
-- rolled stats like weapons:
--   Cooldown Reduction  shorter cooldown
--   Power               stronger effect (damage, healing, durability)
--   Duration            longer effect (stim time, sentry lifetime)

LS_Gadgets = LS_Gadgets or {}
LS_Gadgets.Registered = LS_Gadgets.Registered or {}
LS_Gadgets.Order = LS_Gadgets.Order or {}

-- Chance (percent) that a generated loot item is a gadget instead of a weapon.
LS_Gadgets.DropChance = 8

LS_Gadgets.Prefixes = {"Field", "Combat", "Tactical", "Prototype"}

-- Gadget stat rolls are the weapon rarity ranges, scaled per stat.
local statScale = {["Cooldown Reduction"] = 1.5, Power = 2, Duration = 2}

function LS_Gadgets.Register(definition)

    definition.Stats = definition.Stats or {"Cooldown Reduction", "Power"}
    definition.Cooldown = definition.Cooldown or 30

    LS_Gadgets.Registered[definition.ID] = definition

    if not table.HasValue(LS_Gadgets.Order, definition.ID) then
        table.insert(LS_Gadgets.Order, definition.ID)
    end

end

function LS_Gadgets.Get(id)
    return LS_Gadgets.Registered[id]
end

function LS_Gadgets.GetStat(item, stat)
    return item and item.stats and item.stats[stat] or 0
end

-- Seconds of cooldown after use, after Cooldown Reduction (capped at 60%).
function LS_Gadgets.GetCooldown(definition, item)

    local reduction = math.Clamp(LS_Gadgets.GetStat(item, "Cooldown Reduction"), 0, 60)

    return definition.Cooldown * (1 - reduction / 100)

end

function LS_Gadgets.RollStatValue(stat, rarity)

    local range = LS_Items.RarityRanges[rarity] or {1, 5}
    local scale = statScale[stat] or 1
    local value = math.random(math.floor(range[1] * scale), math.floor(range[2] * scale))

    if stat == "Cooldown Reduction" then
        value = math.min(value, 50)
    end

    return value

end

function LS_Gadgets.GenerateItem(rarity, forcedID)

    local id = forcedID or LS_Gadgets.Order[math.random(#LS_Gadgets.Order)]
    local definition = LS_Gadgets.Get(id)

    if not definition then
        return nil
    end

    rarity = rarity or LS_Items.GetWeightedRarity()

    local item = {
        weapon = definition.Name,
        gadget = definition.ID,
        slot = "GADGET",
        archetype = "GADGET",
        rarity = rarity,
        prefix = LS_Gadgets.Prefixes[math.random(#LS_Gadgets.Prefixes)],
        stats = {},
        talents = {}
    }

    local available = table.Copy(definition.Stats)
    local count = math.min(LS_Items.RarityStatCount[rarity] or 1, #available)
    local range = LS_Items.RarityRanges[rarity] or {1, 5}

    for _ = 1, count do

        local stat = table.remove(available, math.random(#available))
        local scale = statScale[stat] or 1
        local value = math.random(math.floor(range[1] * scale), math.floor(range[2] * scale))

        if stat == "Cooldown Reduction" then
            value = math.min(value, 50)
        end

        item.stats[stat] = value

    end

    -- Talents: gadget-only perks that suit this gadget, rolled like weapon talents.
    local perks = {}

    for _, talent in pairs(LS_Talents.Registered) do
        if talent.Slot == "GADGET" and (not talent.Gadgets or table.HasValue(talent.Gadgets, definition.ID)) then
            table.insert(perks, talent)
        end
    end

    for _ = 1, LS_Items.RarityTalentCount[rarity] or 0 do

        if #perks == 0 then
            break
        end

        table.insert(item.talents, LS_Talents.Roll(table.remove(perks, math.random(#perks)).ID))

    end

    return item

end

-- Called from LS_Items.GenerateItem: occasionally turns a loot roll into a gadget.
function LS_Gadgets.TryGenerate(rarityWeights, chance)

    if #LS_Gadgets.Order == 0 or math.random(100) > (chance or LS_Gadgets.DropChance) then
        return nil
    end

    return LS_Gadgets.GenerateItem(LS_Items.GetWeightedRarity(rarityWeights))

end

----------------------------------------------------------------------
-- Definitions
----------------------------------------------------------------------

LS_Gadgets.Register({

    ID = "grenade",
    Name = "Frag Grenade",
    Description = "Throw a grenade that detonates after a short fuse. Power raises damage and blast radius.",
    Model = "models/weapons/w_grenade.mdl",
    Cooldown = 20,
    Stats = {"Cooldown Reduction", "Power"}

})

LS_Gadgets.Register({

    ID = "stim",
    Name = "Stim Shot",
    Description = "Inject a stim that restores 40 health over 5 seconds. Power heals more; Duration stretches it out.",
    Model = "models/healthvial.mdl",
    Cooldown = 25,
    Stats = {"Cooldown Reduction", "Power", "Duration"}

})

LS_Gadgets.Register({

    ID = "shield",
    Name = "Riot Plate",
    Description = "A plate worn on your back that absorbs damage from behind. When it breaks it takes a long time to rebuild. Power adds durability.",
    Model = "models/hunter/plates/plate1x1.mdl",
    Cooldown = 60,
    Passive = true,
    BaseDurability = 500,
    Stats = {"Cooldown Reduction", "Power"}

})

LS_Gadgets.Register({

    ID = "sentry",
    Name = "Sentry Turret",
    Description = "Deploy a turret that shoots nearby enemies for a short time. Power raises its damage; Duration keeps it up longer.",
    Model = "models/combine_turrets/floor_turret.mdl",
    Cooldown = 40,
    Stats = {"Cooldown Reduction", "Power", "Duration"}

})

if CLIENT then
    return
end

----------------------------------------------------------------------
-- Server: state, use, and each gadget's behavior
----------------------------------------------------------------------

util.AddNetworkString("LS_UseGadget")

local function stateOf(player)

    player.LS_GadgetState = player.LS_GadgetState or {ReadyAt = 0, StartAt = 0, ActiveUntil = 0}

    return player.LS_GadgetState

end

function LS_Gadgets.GetEquipped(player)

    local itemID = LS_Equipment.Slots.GADGET

    if not itemID then
        return nil
    end

    local item = LS_Inventory.GetItemByID(itemID)
    local definition = item and LS_Gadgets.Get(item.gadget)

    if not definition then
        return nil
    end

    return item, definition

end

-- Pushes the HUD state to the client.
function LS_Gadgets.Sync(player)

    local item, definition = LS_Gadgets.GetEquipped(player)

    if not item then
        player:SetNW2String("LS_GadgetID", "")
        return
    end

    local state = stateOf(player)

    player:SetNW2String("LS_GadgetID", definition.ID)
    player:SetNW2String("LS_GadgetRarity", item.rarity)
    player:SetNW2Bool("LS_GadgetPassive", definition.Passive and true or false)
    player:SetNW2Float("LS_GadgetStart", state.StartAt)
    player:SetNW2Float("LS_GadgetEnd", state.ReadyAt)
    player:SetNW2Float("LS_GadgetActiveEnd", state.ActiveUntil)
    player:SetNW2Bool("LS_GadgetShield", IsValid(state.Shield))

end

local function removeShield(player)

    local state = stateOf(player)

    if IsValid(state.Shield) then
        state.Shield:Remove()
    end

    state.Shield = nil
    player.LS_BackShield = nil

end

local function createShield(player, item, definition)

    local plate = ents.Create("ls_back_shield")

    if not IsValid(plate) then
        return
    end

    local position, angles = LS_BackShield.GetTransform(player)

    plate:SetPos(position)
    plate:SetAngles(angles)
    plate:SetWearer(player)
    plate:Spawn()
    plate:Activate()

    local durability = math.floor(definition.BaseDurability * (1 + LS_Gadgets.GetStat(item, "Power") / 100))
    local fortified = LS_Talents.GetInstance(item, "fortified")

    if fortified then
        durability = math.floor(durability * (1 + fortified.rolls.Durability / 100))
    end

    plate:SetDurabilityPool(math.max(1, durability))

    local state = stateOf(player)

    state.Shield = plate
    player.LS_BackShield = plate

    LS_Gadgets.Sync(player)

end

-- The equipment system calls this when a gadget is equipped or restored.
function LS_Gadgets.OnEquip(player, item)

    if not IsValid(player) then
        return
    end

    local state = stateOf(player)

    removeShield(player)

    state.ReadyAt = 0
    state.StartAt = 0
    state.ActiveUntil = 0

    LS_Gadgets.Sync(player)

end

-- A worn shield tells us when it breaks, which starts its rebuild cooldown.
function LS_Gadgets.ShieldBroken(player)

    if not IsValid(player) then
        return
    end

    local item, definition = LS_Gadgets.GetEquipped(player)
    local state = stateOf(player)

    state.Shield = nil
    player.LS_BackShield = nil

    if item then
        local cooldown = LS_Gadgets.GetCooldown(definition, item)
        local fortified = LS_Talents.GetInstance(item, "fortified")

        if fortified then
            cooldown = cooldown * (1 + fortified.rolls.Cooldown / 100)
        end

        state.StartAt = CurTime()
        state.ReadyAt = CurTime() + cooldown
    end

    LS_Gadgets.Sync(player)

end

-- Each gadget's effect. Returns the seconds it stays "active" (for the HUD),
-- nothing for instant gadgets, or false if it could not be used.
LS_Gadgets.Behavior = {}

-- Power as a multiplier: the item's Power stat plus any temporary bonus
-- (Overcharge) a talent added to info.PowerBonus.
local function powerOf(item, info)
    return 1 + (LS_Gadgets.GetStat(item, "Power") + (info.PowerBonus or 0)) / 100
end

----------------------------------------------------------------------
-- Frag Grenade
----------------------------------------------------------------------

local function sendFireField(position, radius, duration)

    net.Start("LS_FieldFX")
        net.WriteVector(position)
        net.WriteFloat(radius)
        net.WriteFloat(duration)
        net.WriteColor(Color(255, 140, 50))
    net.Broadcast()

end

local function burnField(player, position, info)

    local radius = 150
    local endsAt = CurTime() + info.FireDuration
    local timerName = "LS_FireField_" .. tostring(SysTime()) .. math.random(1000)

    sendFireField(position, radius, info.FireDuration)

    timer.Create(timerName, 0.5, 0, function()

        if CurTime() >= endsAt or not IsValid(player) then
            timer.Remove(timerName)
            return
        end

        for _, entity in ipairs(ents.FindInSphere(position, radius)) do
            if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 then
                LS_Combat.ApplyDot(entity, {Attacker = player, Weapon = player}, "burn", info.FireDamage, 2, 0, false)
            end
        end

    end)

end

local function detonate(player, position, damage, radius, info)

    -- The thrower is not hurt by their own grenade.
    player.LS_GrenadeBlast = true
    LS_Combat.CreateExplosion({Attacker = player, Weapon = player}, position, damage, radius)
    player.LS_GrenadeBlast = nil

    if info.ConcussiveForce then

        for _, entity in ipairs(ents.FindInSphere(position, radius)) do

            if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 then

                local direction = entity:GetPos() - position
                direction.z = 0
                direction:Normalize()

                entity:SetGroundEntity(NULL)
                entity:SetVelocity(direction * info.ConcussiveForce + Vector(0, 0, 160))
                LS_Combat.FreezeNPC(entity, info.ConcussiveStun)

            end

        end

    end

    if info.FireDuration then
        burnField(player, position, info)
    end

end

local function throwBomblet(player, position, damage, info)

    local bomblet = ents.Create("prop_physics")

    if not IsValid(bomblet) then
        return
    end

    bomblet:SetModel("models/weapons/w_grenade.mdl")
    bomblet:SetPos(position)
    bomblet:Spawn()
    bomblet:SetModelScale(0.6, 0)
    bomblet:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local physics = bomblet:GetPhysicsObject()

    if IsValid(physics) then
        physics:SetVelocity(VectorRand() * 260 + Vector(0, 0, 220))
    end

    timer.Simple(0.7, function()

        if not IsValid(bomblet) then
            return
        end

        local blast = bomblet:GetPos() + Vector(0, 0, 6)

        bomblet:Remove()

        if IsValid(player) then
            detonate(player, blast, damage, 120, {})
        end

    end)

end

LS_Gadgets.Behavior.grenade = function(player, item, info)

    local power = powerOf(item, info)
    local aim = player:GetAimVector()
    local grenade = ents.Create("prop_physics")

    if not IsValid(grenade) then
        return false
    end

    grenade:SetModel("models/weapons/w_grenade.mdl")
    grenade:SetPos(player:GetShootPos() + aim * 24)
    grenade:SetAngles(aim:Angle())
    grenade:Spawn()
    grenade:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local physics = grenade:GetPhysicsObject()

    if IsValid(physics) then
        physics:SetVelocity(aim * 900 + Vector(0, 0, 140) + player:GetVelocity())
        physics:AddAngleVelocity(Vector(math.Rand(-300, 300), math.Rand(-300, 300), 0))
    end

    -- Sticky: attach to the first enemy it hits.
    if info.StickyBonus then
        grenade:AddCallback("PhysicsCollide", function(entity, data)

            local hit = data.HitEntity

            if entity.LS_Stuck or not IsValid(hit) or not hit:IsNPC() then
                return
            end

            entity.LS_Stuck = true

            timer.Simple(0, function()
                if IsValid(entity) and IsValid(hit) then
                    entity:SetMoveType(MOVETYPE_NONE)
                    entity:SetParent(hit)
                    entity:EmitSound("weapons/slam/mine_mode.wav", 70, 120)
                end
            end)

        end)
    end

    player:EmitSound("weapons/slam/throw.wav", 70, 100)

    local ticks = 0

    timer.Create("LS_Grenade_" .. grenade:EntIndex(), 0.5, 4, function()

        ticks = ticks + 1

        if not IsValid(grenade) then
            return
        end

        if ticks < 4 then
            grenade:EmitSound("weapons/grenade/tick1.wav", 65, 100 + ticks * 12)
            return
        end

        local position = grenade:GetPos() + Vector(0, 0, 8)
        local stuckBonus = (grenade.LS_Stuck and info.StickyBonus or 0) / 100
        local damage = 130 * power * (1 + stuckBonus)
        local radius = 230 * (1 + (power - 1) * 0.5)

        grenade:Remove()

        if not IsValid(player) then
            return
        end

        detonate(player, position, damage, radius, info)

        for _ = 1, info.ClusterCount or 0 do
            throwBomblet(player, position, 130 * power * (info.ClusterDamage or 30) / 100, info)
        end

    end)

end

hook.Add("EntityTakeDamage", "LS_GrenadeNoSelfDamage", function(target, dmginfo)

    if IsValid(target) and target.LS_GrenadeBlast and dmginfo:GetAttacker() == target then
        return true
    end

end)

----------------------------------------------------------------------
-- Stim Shot
----------------------------------------------------------------------

LS_Gadgets.Behavior.stim = function(player, item, info)

    local total = 40 * powerOf(item, info)
    local duration = 5 * (1 + LS_Gadgets.GetStat(item, "Duration") / 100)
    local ticks = math.max(1, math.floor(duration / 0.5))
    local perTick = math.max(1, math.Round(total / ticks))

    player:EmitSound("items/medshot4.wav", 70, 100)

    timer.Create("LS_Stim_" .. player:EntIndex(), 0.5, ticks, function()

        if IsValid(player) and player:Alive() then
            LS_Combat.HealPlayer(player, perTick)
        end

    end)

    LS_Combat.SetBuff(player, "stim", "STIM  +" .. math.floor(total) .. " HP", duration)

    -- Cleanse: drop any slow and shrug off toxins for a while.
    if info.CleanseSeconds then
        player.LS_ColdUntil = 0
        player.LS_PoisonImmuneUntil = CurTime() + info.CleanseSeconds
    end

    -- Overdose: faster movement and fire rate while the stim lasts.
    if info.OverdoseSpeed then

        local weapon = player:GetActiveWeapon()
        local timerName = "LS_Overdose_" .. player:EntIndex()

        LS_Combat.SetMoveMod(player, "overdose", 1 + info.OverdoseSpeed / 100)
        LS_Combat.SetWeaponFireMod(weapon, "overdose", 1 + info.OverdoseFireRate / 100)
        LS_Combat.SetBuff(player, "overdose", "OVERDOSE", duration)

        timer.Create(timerName, duration, 1, function()
            if IsValid(player) then
                LS_Combat.SetMoveMod(player, "overdose", nil)
            end

            LS_Combat.SetWeaponFireMod(weapon, "overdose", nil)
        end)

    end

    return duration

end

----------------------------------------------------------------------
-- Sentry Turret
----------------------------------------------------------------------

local function deploySentry(player, item, info, position, angles, lifetime)

    local sentry = ents.Create("ls_sentry")

    if not IsValid(sentry) then
        return nil
    end

    sentry:SetPos(position)
    sentry:SetAngles(angles)
    sentry:SetOwnerPlayer(player)
    sentry.Damage = 9 * powerOf(item, info)
    sentry.Lifetime = lifetime
    sentry.RocketDamage = info.RocketDamage and (45 * info.RocketDamage / 100 * powerOf(item, info)) or nil
    sentry.TeslaChance = info.TeslaChance
    sentry.TeslaDamage = info.TeslaDamage
    sentry.TeslaTargets = info.TeslaTargets
    sentry.DecoyRadius = info.DecoyRadius
    sentry.DecoyChance = info.DecoyChance
    sentry:Spawn()
    sentry:Activate()

    return sentry

end

LS_Gadgets.Behavior.sentry = function(player, item, info)

    local lifetime = 18 * (1 + LS_Gadgets.GetStat(item, "Duration") / 100)
    local yaw = Angle(0, player:EyeAngles().y, 0)
    local forward, right = yaw:Forward(), yaw:Right()
    local origin = player:GetPos() + forward * 70

    local function groundAt(point)
        local ground = util.TraceLine({
            start = point + Vector(0, 0, 60),
            endpos = point - Vector(0, 0, 120),
            mask = MASK_SOLID_BRUSHONLY
        })

        return (ground.Hit and ground.HitPos or point) + Vector(0, 0, 2)
    end

    -- Twin: two turrets, each up for less time.
    if info.TwinPenalty then
        lifetime = lifetime * (1 - info.TwinPenalty / 100)

        local first = deploySentry(player, item, info, groundAt(origin + right * 60), yaw, lifetime)
        deploySentry(player, item, info, groundAt(origin - right * 60), yaw, lifetime)

        if not IsValid(first) then
            return false
        end
    elseif not IsValid(deploySentry(player, item, info, groundAt(origin), yaw, lifetime)) then
        return false
    end

    return lifetime

end

-- The shield is passive: it is worn automatically and has no use key.
LS_Gadgets.Behavior.shield = function() return false end

----------------------------------------------------------------------
-- Talent events
----------------------------------------------------------------------

-- Restores a percentage of the armor pool (Rhythm, Armor Stim).
function LS_Gadgets.RefillArmor(player, percent)

    if IsValid(player) and (player.LS_ArmorMax or 0) > 0 then
        player.LS_ArmorPool = math.min(player.LS_ArmorMax, (player.LS_ArmorPool or 0) + player.LS_ArmorMax * percent / 100)
    end

end

-- Called by the Riot Plate whenever it absorbs a hit.
function LS_Gadgets.TriggerShieldHit(player, attacker, damage, plate)

    local item = LS_Gadgets.GetEquipped(player)

    if item then
        LS_Talents.Trigger("OnShieldHit", {
            Player = player, Item = item, Attacker = attacker, Damage = damage, Plate = plate
        }, item)
    end

end

hook.Add("OnNPCKilled", "LS_GadgetKill", function(npc, attacker)

    if not IsValid(attacker) or not attacker:IsPlayer() then
        return
    end

    local item = LS_Gadgets.GetEquipped(attacker)

    if item then
        LS_Talents.Trigger("OnGadgetKill", {
            Player = attacker, Item = item, Target = npc, State = stateOf(attacker)
        }, item)
    end

end)

function LS_Gadgets.Use(player)

    if not IsValid(player) or not player:Alive() then
        return
    end

    local item, definition = LS_Gadgets.GetEquipped(player)

    if not item or definition.Passive then
        return
    end

    local state = stateOf(player)
    local now = CurTime()

    if now < state.ReadyAt then
        player:EmitSound("buttons/button10.wav", 60, 100, 0.5)
        return
    end

    -- Talents adjust `info` before the gadget's effect reads it.
    local info = {PowerBonus = 0}

    LS_Talents.Trigger("OnGadgetUse", {
        Player = player, Item = item, Gadget = definition.ID, Info = info, State = state
    }, item)

    local behavior = LS_Gadgets.Behavior[definition.ID]
    local active = behavior and behavior(player, item, info)

    if active == false then
        return
    end

    state.StartAt = now
    state.ReadyAt = now + LS_Gadgets.GetCooldown(definition, item)
    state.ActiveUntil = active and (now + active) or 0

    LS_Gadgets.Sync(player)

end

net.Receive("LS_UseGadget", function(_, player)
    LS_Gadgets.Use(player)
end)

-- Passive gadgets (the shield) rebuild themselves once their cooldown is over.
timer.Create("LS_GadgetThink", 0.5, 0, function()

    for _, player in ipairs(player.GetAll()) do

        if IsValid(player) and player:Alive() then

            local item, definition = LS_Gadgets.GetEquipped(player)

            if item and definition.Passive then

                local state = stateOf(player)

                if not IsValid(state.Shield) and CurTime() >= state.ReadyAt then
                    createShield(player, item, definition)
                end

            end

        end

    end

end)

hook.Add("PlayerDeath", "LS_GadgetDeath", function(player)

    removeShield(player)

    if player.LS_GadgetState then
        player.LS_GadgetState.ActiveUntil = 0
    end

    timer.Remove("LS_Stim_" .. player:EntIndex())

end)

-- Testing aid: ls_givegadget <grenade|stim|shield|sentry> [rarity] [talent id]
concommand.Add("ls_givegadget", function(player, _, args)

    if not IsValid(player) then
        return
    end

    local id = string.lower(args[1] or "")
    local rarity = args[2] and string.upper(string.sub(args[2], 1, 1)) .. string.lower(string.sub(args[2], 2)) or nil

    if not LS_Gadgets.Get(id) then
        print("Usage: ls_givegadget <" .. table.concat(LS_Gadgets.Order, "|") .. "> [rarity]")
        return
    end

    if rarity and not table.HasValue(LS_Items.Rarities, rarity) then
        rarity = nil
    end

    local item = LS_Gadgets.GenerateItem(rarity, id)

    -- Optional third argument: force a specific talent, for testing.
    local forced = args[3] and LS_Talents.Get(string.lower(args[3]))

    if forced and forced.Slot == "GADGET" then
        item.talents = {LS_Talents.Roll(forced.ID)}
    end

    LS_Inventory.AddItem(item)
    LS_Networking.SendInventory(player)

    print("[LS] Added gadget: " .. item.rarity .. " " .. item.prefix .. " " .. item.weapon)

end)
