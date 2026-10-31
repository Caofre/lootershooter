-- Armor: a regenerating shield pool worn in the ARMOR slot.
--
-- Damage you take drains the pool first. After a short delay without being hit,
-- the pool recharges. Armor items roll these stats:
--   Armor Capacity   bigger pool
--   Recharge Rate    faster refill
--   Recharge Delay   shorter wait before refilling (percent reduction)
--   Resistance       percent off all incoming damage
-- Armor also rolls perks (talents with Slot = "ARMOR"), which trigger on:
--   OnDamaged     you took a hit (after armor)
--   OnArmorBreak  the pool was just emptied

LS_Armor = LS_Armor or {}
LS_Armor.Registered = LS_Armor.Registered or {}
LS_Armor.Order = LS_Armor.Order or {}

-- Chance (percent) that a generated loot item is armor instead of a weapon.
LS_Armor.DropChance = 8

LS_Armor.Prefixes = {"Reinforced", "Ablative", "Composite", "Hardened"}

LS_Armor.StatNames = {"Armor Capacity", "Recharge Rate", "Recharge Delay", "Resistance"}

-- Armor stat rolls are the weapon rarity ranges, scaled per stat.
local statScale = {["Armor Capacity"] = 3, ["Recharge Rate"] = 2.5, ["Recharge Delay"] = 2, Resistance = 0.8}

function LS_Armor.Register(definition)

    LS_Armor.Registered[definition.ID] = definition

    if not table.HasValue(LS_Armor.Order, definition.ID) then
        table.insert(LS_Armor.Order, definition.ID)
    end

end

function LS_Armor.Get(id)
    return LS_Armor.Registered[id]
end

function LS_Armor.GetStat(item, stat)
    return item and item.stats and item.stats[stat] or 0
end

function LS_Armor.GetCapacity(definition, item)
    return math.floor(definition.Capacity * (1 + LS_Armor.GetStat(item, "Armor Capacity") / 100))
end

-- Pool points restored per second.
function LS_Armor.GetRecharge(definition, item)
    return definition.Recharge * (1 + LS_Armor.GetStat(item, "Recharge Rate") / 100)
end

-- Seconds without a hit before the pool starts refilling.
function LS_Armor.GetDelay(definition, item)
    return definition.Delay * (1 - math.min(LS_Armor.GetStat(item, "Recharge Delay"), 50) / 100)
end

-- Percent of all incoming damage ignored.
function LS_Armor.GetResistance(definition, item)
    return math.min(40, definition.Resistance + LS_Armor.GetStat(item, "Resistance"))
end

function LS_Armor.RollStatValue(stat, rarity)

    local range = LS_Items.RarityRanges[rarity] or {1, 5}
    local scale = statScale[stat] or 1
    local value = math.max(1, math.random(math.floor(range[1] * scale), math.floor(range[2] * scale)))

    if stat == "Recharge Delay" then
        value = math.min(value, 50)
    elseif stat == "Resistance" then
        value = math.min(value, 20)
    end

    return value

end

function LS_Armor.GenerateItem(rarity, forcedID)

    local id = forcedID or LS_Armor.Order[math.random(#LS_Armor.Order)]
    local definition = LS_Armor.Get(id)

    if not definition then
        return nil
    end

    rarity = rarity or LS_Items.GetWeightedRarity()

    local item = {
        weapon = definition.Name,
        armor = definition.ID,
        slot = "ARMOR",
        archetype = "ARMOR",
        rarity = rarity,
        prefix = LS_Armor.Prefixes[math.random(#LS_Armor.Prefixes)],
        stats = {},
        talents = {}
    }

    local available = table.Copy(LS_Armor.StatNames)
    local count = math.min(LS_Items.RarityStatCount[rarity] or 1, #available)
    local range = LS_Items.RarityRanges[rarity] or {1, 5}

    for _ = 1, count do

        local stat = table.remove(available, math.random(#available))
        local scale = statScale[stat] or 1
        local value = math.max(1, math.random(math.floor(range[1] * scale), math.floor(range[2] * scale)))

        if stat == "Recharge Delay" then
            value = math.min(value, 50)
        elseif stat == "Resistance" then
            value = math.min(value, 20)
        end

        item.stats[stat] = value

    end

    -- Perks: armor-only talents, rolled the same way as weapon talents.
    local perks = {}

    for _, talent in pairs(LS_Talents.Registered) do
        if talent.Slot == "ARMOR" then
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

-- Called from LS_Items.GenerateItem: occasionally turns a loot roll into armor.
function LS_Armor.TryGenerate(rarityWeights, chance)

    if #LS_Armor.Order == 0 or math.random(100) > (chance or LS_Armor.DropChance) then
        return nil
    end

    return LS_Armor.GenerateItem(LS_Items.GetWeightedRarity(rarityWeights))

end

----------------------------------------------------------------------
-- Armor types
----------------------------------------------------------------------

LS_Armor.Register({

    ID = "light_vest",
    Name = "Light Vest",
    Description = "A small pool that recharges quickly and starts refilling soon after a hit.",
    Model = "models/items/battery.mdl",
    Capacity = 40,
    Recharge = 14,
    Delay = 3.5,
    Resistance = 0

})

LS_Armor.Register({

    ID = "tactical_vest",
    Name = "Tactical Vest",
    Description = "A balanced pool, recharge speed and delay.",
    Model = "models/items/battery.mdl",
    Capacity = 60,
    Recharge = 11,
    Delay = 4.5,
    Resistance = 0

})

LS_Armor.Register({

    ID = "heavy_plate",
    Name = "Heavy Plate Carrier",
    Description = "A large pool with built-in resistance, but it refills slowly and waits longer after a hit.",
    Model = "models/items/battery.mdl",
    Capacity = 90,
    Recharge = 8,
    Delay = 6,
    Resistance = 6

})

----------------------------------------------------------------------
-- Armor perks (talents that only roll on armor)
----------------------------------------------------------------------

LS_Talents.Register({

    ID = "thorns",
    Name = "Thorns",
    Slot = "ARMOR",
    Description = "Enemies that hit you up close take part of the damage back.",

    Rolls = {
        Reflect = {20, 60}
    },

    OnDamaged = function(context, instance)

        local attacker, player = context.Attacker, context.Player

        if not IsValid(attacker) or not attacker:IsNPC() or
            attacker:GetPos():DistToSqr(player:GetPos()) > 220 * 220 then
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

    ID = "second_wind",
    Name = "Second Wind",
    Slot = "ARMOR",
    Description = "When a hit would leave you at low health, you instantly heal. It needs time to recharge.",

    Rolls = {
        Heal = {25, 50},
        Cooldown = {45, 90}
    },

    OnDamaged = function(context, instance)

        local player = context.Player
        local now = CurTime()

        if now < (player.LS_SecondWindReadyAt or 0) then
            return
        end

        local maxHealth = player:GetMaxHealth()
        local remaining = context.DamageInfo and context.DamageInfo:GetDamage() or 0

        if player:Health() - remaining > maxHealth * 0.3 then
            return
        end

        player.LS_SecondWindReadyAt = now + instance.rolls.Cooldown

        player:SetHealth(math.min(maxHealth, player:Health() + math.floor(maxHealth * instance.rolls.Heal / 100)))
        player:EmitSound("items/medshot4.wav", 75, 90)
        LS_Combat.SetBuff(player, "secondwind", "SECOND WIND", 2)

    end

})

LS_Talents.Register({

    ID = "adrenaline",
    Name = "Adrenaline",
    Slot = "ARMOR",
    Description = "When your armor breaks, you move faster for a few seconds.",

    Rolls = {
        Speed = {15, 35},
        Duration = {3, 6}
    },

    OnArmorBreak = function(context, instance)

        local player = context.Player

        LS_Combat.SetMoveMod(player, "adrenaline", 1 + instance.rolls.Speed / 100)
        LS_Combat.SetBuff(player, "adrenaline", "ADRENALINE  +" .. instance.rolls.Speed .. "% speed", instance.rolls.Duration)

        timer.Create("LS_Adrenaline_" .. player:EntIndex(), instance.rolls.Duration, 1, function()
            if IsValid(player) then
                LS_Combat.SetMoveMod(player, "adrenaline", nil)
            end
        end)

    end

})

LS_Talents.Register({

    ID = "shock_plating",
    Name = "Shock Plating",
    Slot = "ARMOR",
    Description = "When your armor breaks, it discharges and shocks nearby enemies away.",

    Rolls = {
        Damage = {30, 80},
        Radius = {150, 260}
    },

    OnArmorBreak = function(context, instance)

        local player = context.Player
        local origin = player:GetPos()

        for _, entity in ipairs(ents.FindInSphere(origin, instance.rolls.Radius)) do

            if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 then

                LS_Combat.DealTalentDamage({Attacker = player, Weapon = player}, entity, instance.rolls.Damage, DMG_SHOCK)
                LS_Effects.TeslaBeam(player:WorldSpaceCenter(), entity:WorldSpaceCenter())

                local direction = entity:GetPos() - origin
                direction.z = 0
                direction:Normalize()

                entity:SetGroundEntity(NULL)
                entity:SetVelocity(direction * 400 + Vector(0, 0, 150))

            end

        end

        sound.Play("ambient/energy/zap" .. math.random(5, 9) .. ".wav", origin, 80, 100)

    end

})

LS_Talents.Register({

    ID = "reactive",
    Name = "Reactive",
    Slot = "ARMOR",
    Description = "After you are hit, you take reduced damage for a moment.",

    Rolls = {
        Reduction = {10, 30},
        Duration = {1, 3}
    },

    OnDamaged = function(context, instance)

        local player = context.Player

        player.LS_ReactiveUntil = CurTime() + instance.rolls.Duration
        player.LS_ReactiveReduction = instance.rolls.Reduction

        LS_Combat.SetBuff(player, "reactive", "REACTIVE  -" .. instance.rolls.Reduction .. "% damage", instance.rolls.Duration)

    end

})

if CLIENT then
    return
end

----------------------------------------------------------------------
-- Server: the pool, damage absorption, recharge
----------------------------------------------------------------------

local IGNORED_DAMAGE = bit.bor(DMG_FALL, DMG_DROWN, DMG_POISON, DMG_RADIATION)

function LS_Armor.GetEquipped(player)

    local itemID = LS_Equipment.Slots.ARMOR

    if not itemID then
        return nil
    end

    local item = LS_Inventory.GetItemByID(itemID)
    local definition = item and LS_Armor.Get(item.armor)

    if not definition then
        return nil
    end

    return item, definition

end

local function sync(player)

    local pool = math.floor(player.LS_ArmorPool or 0)
    local maximum = player.LS_ArmorMax or 0

    if player.LS_ArmorSyncedPool ~= pool then
        player.LS_ArmorSyncedPool = pool
        player:SetNW2Int("LS_ArmorPool", pool)
    end

    if player.LS_ArmorSyncedMax ~= maximum then
        player.LS_ArmorSyncedMax = maximum
        player:SetNW2Int("LS_ArmorMax", maximum)
    end

end

-- The equipment system calls this when armor is equipped or restored.
function LS_Armor.OnEquip(player, item)

    if not IsValid(player) then
        return
    end

    local definition = LS_Armor.Get(item.armor)

    player.LS_ArmorMax = definition and LS_Armor.GetCapacity(definition, item) or 0
    player.LS_ArmorPool = player.LS_ArmorMax
    player.LS_ArmorLastHit = 0

    sync(player)

end

hook.Add("EntityTakeDamage", "LS_ArmorAbsorb", function(target, dmginfo)

    if not IsValid(target) or not target:IsPlayer() then
        return
    end

    local item, definition = LS_Armor.GetEquipped(target)

    if not item then
        return
    end

    local incoming = dmginfo:GetDamage()

    if incoming <= 0 or bit.band(dmginfo:GetDamageType(), IGNORED_DAMAGE) ~= 0 then
        return
    end

    local now = CurTime()
    local reduction = LS_Armor.GetResistance(definition, item)

    if (target.LS_ReactiveUntil or 0) > now then
        reduction = reduction + (target.LS_ReactiveReduction or 0)
    end

    local damage = incoming * (1 - math.min(80, reduction) / 100)
    local pool = target.LS_ArmorPool or 0
    local absorbed = math.min(pool, damage)

    pool = pool - absorbed

    target.LS_ArmorPool = pool
    target.LS_ArmorLastHit = now

    dmginfo:SetDamage(damage - absorbed)

    if absorbed > 0 then
        target:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 65, 110, 0.6)
    end

    local context = {
        Player = target,
        Attacker = dmginfo:GetAttacker(),
        Damage = incoming,
        Absorbed = absorbed,
        Item = item,
        DamageInfo = dmginfo
    }

    LS_Talents.Trigger("OnDamaged", context, item)

    if absorbed > 0 and pool <= 0 then

        target:EmitSound("ambient/energy/zap9.wav", 75, 90)
        LS_Combat.SetBuff(target, "armorbreak", "ARMOR BROKEN", 1.5)
        LS_Talents.Trigger("OnArmorBreak", context, item)

    end

    sync(target)

end)

timer.Create("LS_ArmorRecharge", 0.1, 0, function()

    local now = CurTime()

    for _, player in ipairs(player.GetAll()) do

        if IsValid(player) and player:Alive() then

            local item, definition = LS_Armor.GetEquipped(player)

            if item then

                if player.LS_ArmorMax == nil then
                    LS_Armor.OnEquip(player, item)
                end

                local maximum, pool = player.LS_ArmorMax, player.LS_ArmorPool or 0

                if pool < maximum and now - (player.LS_ArmorLastHit or 0) >= LS_Armor.GetDelay(definition, item) then

                    local restored = math.min(maximum, pool + LS_Armor.GetRecharge(definition, item) * 0.1)

                    if restored >= maximum then
                        player:EmitSound("buttons/button17.wav", 60, 130, 0.5)
                    end

                    player.LS_ArmorPool = restored

                end

            elseif (player.LS_ArmorMax or 0) > 0 then

                player.LS_ArmorMax = 0
                player.LS_ArmorPool = 0

            end

            sync(player)

        end

    end

end)

hook.Add("PlayerDeath", "LS_ArmorDeath", function(player)

    player.LS_ArmorPool = 0
    player.LS_ReactiveUntil = nil

    timer.Remove("LS_Adrenaline_" .. player:EntIndex())
    LS_Combat.SetMoveMod(player, "adrenaline", nil)

    sync(player)

end)

-- Testing aid: ls_givearmor <light_vest|tactical_vest|heavy_plate> [rarity]
concommand.Add("ls_givearmor", function(player, _, args)

    if not IsValid(player) then
        return
    end

    local id = string.lower(args[1] or "")
    local rarity = args[2] and string.upper(string.sub(args[2], 1, 1)) .. string.lower(string.sub(args[2], 2)) or nil

    if not LS_Armor.Get(id) then
        print("Usage: ls_givearmor <" .. table.concat(LS_Armor.Order, "|") .. "> [rarity]")
        return
    end

    if rarity and not table.HasValue(LS_Items.Rarities, rarity) then
        rarity = nil
    end

    local item = LS_Armor.GenerateItem(rarity, id)

    LS_Inventory.AddItem(item)
    LS_Networking.SendInventory(player)

    print("[LS] Added armor: " .. item.rarity .. " " .. item.prefix .. " " .. item.weapon)

end)
