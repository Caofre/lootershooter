-- Behavior framework and data-driven variants.
--
-- A variant can carry a behavior (LS_NPCs.RegisterBehavior) with any of:
--   OnSpawn(npc, variant)            once, right after the NPC is initialized
--   OnThink(npc, now)                every 0.2 seconds while the NPC is alive
--   OnDamaged(npc, dmginfo)          when the NPC takes damage
--   OnDealDamage(npc, victim, dmg)   when the NPC is the attacker
--   OnKilled(npc, attacker, inflictor)
--
-- Variant data can also set SpawnWave / SpawnMax (wave rolls), AllowedNPCs,
-- Factions and RequiresEquipment (which NPC types may roll the variant).

LS_NPCs.Behaviors = LS_NPCs.Behaviors or {}
LS_NPCs.Behaving = LS_NPCs.Behaving or {}

function LS_NPCs.RegisterBehavior(id, behavior)
    LS_NPCs.Behaviors[id] = behavior
end

function LS_NPCs.CanHaveVariant(variantID, npcID)

    local variant = LS_NPCs.GetVariant(variantID)
    local definition = LS_NPCs.Get(npcID)

    if not variant then
        return false
    end

    if not definition then
        return true
    end

    if variant.AllowedNPCs and not table.HasValue(variant.AllowedNPCs, npcID) then
        return false
    end

    if variant.Factions and not table.HasValue(variant.Factions, definition.Faction) then
        return false
    end

    if variant.MaxBaseHealth and (definition.BaseHealth or 0) > variant.MaxBaseHealth then
        return false
    end

    if variant.RequiresEquipment and #(definition.Equipment or {}) == 0 then
        return false
    end

    return true

end

if not SERVER then
    return
end

local function nearestPlayer(npc)

    local best, bestDistance

    for _, player in ipairs(player.GetAll()) do

        if IsValid(player) and player:Alive() then
            local distance = player:GetPos():DistToSqr(npc:GetPos())

            if not bestDistance or distance < bestDistance then
                best, bestDistance = player, distance
            end
        end

    end

    return best, bestDistance and math.sqrt(bestDistance) or math.huge

end

LS_NPCs.NearestPlayer = nearestPlayer

-- Final animation speed = the variant's own rate times any Frost slow.
function LS_NPCs.ApplySpeed(npc)

    if IsValid(npc) then
        npc:SetPlaybackRate((npc.LS_BaseRate or 1) * (npc.LS_FrostFactor or 1))
    end

end

function LS_NPCs.StartBehavior(npc, variant)

    local behavior = LS_NPCs.Behaviors[variant.ID]

    if not behavior then
        return
    end

    npc.LS_Behavior = behavior

    if behavior.OnSpawn then
        behavior.OnSpawn(npc, variant)
    end

    if behavior.OnThink then
        table.insert(LS_NPCs.Behaving, npc)
    end

end

timer.Create("LS_NPCBehaviorThink", 0.2, 0, function()

    local now = CurTime()

    for index = #LS_NPCs.Behaving, 1, -1 do

        local npc = LS_NPCs.Behaving[index]

        if not IsValid(npc) or npc:Health() <= 0 then
            table.remove(LS_NPCs.Behaving, index)
        else
            npc.LS_Behavior.OnThink(npc, now)
        end

    end

end)

hook.Add("EntityTakeDamage", "LS_NPCBehaviorDamage", function(target, dmginfo)

    if IsValid(target) and target.LS_Behavior and target.LS_Behavior.OnDamaged then
        target.LS_Behavior.OnDamaged(target, dmginfo)
    end

    local attacker = dmginfo:GetAttacker()

    if IsValid(attacker) and attacker.LS_Behavior and attacker.LS_Behavior.OnDealDamage then
        attacker.LS_Behavior.OnDealDamage(attacker, target, dmginfo)
    end

end)

hook.Add("OnNPCKilled", "LS_NPCBehaviorKilled", function(npc, attacker, inflictor)

    if IsValid(npc) and npc.LS_Behavior and npc.LS_Behavior.OnKilled then
        npc.LS_Behavior.OnKilled(npc, attacker, inflictor)
    end

end)

local function dropLoot(npc, count)

    for _ = 1, count do

        local loot = ents.Create("ls_loot")

        if IsValid(loot) then
            loot:SetPos(npc:GetPos() + Vector(math.Rand(-24, 24), math.Rand(-24, 24), 20))
            loot:SetItem(LS_Items.GenerateItem(npc.LS_RarityWeights))
            loot:Spawn()
        end

    end

end

----------------------------------------------------------------------
-- Frenzied: gets faster, hits harder and glows redder as it is hurt.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "frenzied",
    LootChanceMultiplier = 1.3,
    Name = "Frenzied",
    Badge = "FRENZIED  ◆",
    Color = Color(230, 50, 50),

    HealthMultiplier = 1.1,
    XPMultiplier = 1.3,

    SpawnWave = 3,
    SpawnMax = 6

})

LS_NPCs.RegisterBehavior("frenzied", {

    OnSpawn = function(npc)
        npc.LS_Rage = 0
        npc.LS_BaseColor = npc:GetColor()
    end,

    OnThink = function(npc)

        local fraction = math.Clamp(npc:Health() / math.max(1, npc.LS_MaxHealth), 0, 1)

        -- Nothing happens above 60% health; the rage ramps up below that.
        local rage = 1 - math.Clamp(fraction / 0.6, 0, 1)

        npc.LS_Rage = rage
        npc.LS_BaseRate = 1 + rage * 0.6
        LS_NPCs.ApplySpeed(npc)

        -- Frost owns the tint while it is active.
        if npc.LS_FrostFactor then
            return
        end

        local base = npc.LS_BaseColor or color_white

        npc:SetColor(Color(
            Lerp(rage, base.r, 255),
            Lerp(rage, base.g, 40),
            Lerp(rage, base.b, 40)
        ))

    end,

    OnDealDamage = function(npc, victim, dmginfo)
        dmginfo:ScaleDamage(1 + (npc.LS_Rage or 0) * 0.75)
    end

})

----------------------------------------------------------------------
-- Glass Cannon: very low health, double damage.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "glass_cannon",
    LootChanceMultiplier = 1.2,
    Name = "Glass Cannon",
    Badge = "GLASS CANNON  ◆",
    Color = Color(200, 220, 255),

    HealthMultiplier = 0.45,
    XPMultiplier = 1.4,

    SpawnWave = 2,
    SpawnMax = 5

})

LS_NPCs.RegisterBehavior("glass_cannon", {

    OnDealDamage = function(npc, victim, dmginfo)
        dmginfo:ScaleDamage(2)
    end

})

----------------------------------------------------------------------
-- Hunter: always knows where the player is, and goes straight for them.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "hunter",
    LootChanceMultiplier = 1.3,
    Name = "Hunter",
    Badge = "HUNTER  ◆",
    Color = Color(130, 70, 210),

    XPMultiplier = 1.2,

    SpawnWave = 3,
    SpawnMax = 5

})

LS_NPCs.RegisterBehavior("hunter", {

    OnSpawn = function(npc)
        npc.LS_BaseRate = 1.1
        LS_NPCs.ApplySpeed(npc)
        npc.LS_NextHunt = 0
    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextHunt then
            return
        end

        npc.LS_NextHunt = now + 1.2

        local player, distance = nearestPlayer(npc)

        if not IsValid(player) or distance > 3000 then
            return
        end

        -- Refresh what the NPC remembers about the player so it never loses
        -- track of them behind cover or at long range.
        npc:SetEnemy(player)
        npc:UpdateEnemyMemory(player, player:GetPos())

        if not npc:Visible(player) and not npc:IsCurrentSchedule(SCHED_CHASE_ENEMY) then
            npc:SetSchedule(SCHED_CHASE_ENEMY)
        end

    end

})

----------------------------------------------------------------------
-- Marked: while one is alive, every enemy deals +25% damage to the player.
-- It is fragile and shows through walls, so it is a priority target.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "marked",
    LootChanceMultiplier = 2,
    Name = "Marked",
    Badge = "MARKED  ◆",
    Color = Color(255, 60, 160),

    HealthMultiplier = 0.85,
    XPMultiplier = 1.5,

    SpawnWave = 4,
    SpawnMax = 4

})

LS_NPCs.Marked = LS_NPCs.Marked or {}

local MARKED_DAMAGE_BONUS = 1.25

LS_NPCs.RegisterBehavior("marked", {

    OnSpawn = function(npc)
        npc.LS_Marked = true
        npc:SetNW2Bool("LS_MarkedTarget", true)
        table.insert(LS_NPCs.Marked, npc)
    end

})

timer.Create("LS_MarkedState", 0.5, 0, function()

    local alive = false

    for index = #LS_NPCs.Marked, 1, -1 do

        local npc = LS_NPCs.Marked[index]

        if not IsValid(npc) or npc:Health() <= 0 then
            table.remove(LS_NPCs.Marked, index)
        else
            local _, distance = LS_NPCs.NearestPlayer(npc)

            if distance < 2200 then
                alive = true
            end
        end

    end

    if GetGlobalBool("LS_Marked", false) ~= alive then
        SetGlobalBool("LS_Marked", alive)
    end

end)

hook.Add("EntityTakeDamage", "LS_MarkedBonusDamage", function(target, dmginfo)

    if not GetGlobalBool("LS_Marked", false) or not IsValid(target) or not target:IsPlayer() then
        return
    end

    local attacker = dmginfo:GetAttacker()

    if IsValid(attacker) and attacker:IsNPC() and attacker:GetNW2Bool("LS_IsFrameworkNPC", false) then
        dmginfo:ScaleDamage(MARKED_DAMAGE_BONUS)
    end

end)

----------------------------------------------------------------------
-- Looter: carries extra, better loot, runs from the player, and escapes
-- after 35 seconds. Kill it before it gets away.
----------------------------------------------------------------------

local LOOTER_ESCAPE_TIME = 35

LS_NPCs.RegisterVariant({

    ID = "looter",
    LootChanceMultiplier = 10,
    Name = "Looter",
    Badge = "LOOTER  ◆",
    Color = Color(255, 190, 30),

    HealthMultiplier = 0.8,
    XPMultiplier = 1.5,

    RarityWeights = {
        Common = 10,
        Uncommon = 25,
        Rare = 30,
        Epic = 25,
        Legendary = 10
    },

    SpawnWave = 2,
    SpawnMax = 4

})

LS_NPCs.RegisterBehavior("looter", {

    OnSpawn = function(npc)
        npc.LS_NextFlee = 0
    end,

    OnThink = function(npc, now)

        -- Placed ahead of the player: the escape clock only starts once they are near.
        if not npc.LS_EscapesAt then

            local nearby, nearbyDistance = nearestPlayer(npc)

            if IsValid(nearby) and nearbyDistance < 1200 then
                npc.LS_EscapesAt = now + LOOTER_ESCAPE_TIME
            end

            return

        end

        if now >= npc.LS_EscapesAt then

            local effect = EffectData()
            effect:SetOrigin(npc:WorldSpaceCenter())
            util.Effect("ManhackSparks", effect)
            sound.Play("ambient/energy/zap1.wav", npc:GetPos(), 75, 120)

            PrintMessage(HUD_PRINTCENTER, "The Looter got away!")

            npc.LS_Escaped = true
            npc:Remove()

            return

        end

        if now < npc.LS_NextFlee then
            return
        end

        npc.LS_NextFlee = now + 1.5

        local player, distance = nearestPlayer(npc)

        if not IsValid(player) or distance > 900 then
            return
        end

        local away = npc:GetPos() - player:GetPos()
        away.z = 0

        if away:LengthSqr() < 1 then
            away = VectorRand()
            away.z = 0
        end

        away:Normalize()

        npc:SetLastPosition(npc:GetPos() + away * 500)
        npc:SetSchedule(SCHED_FORCED_GO_RUN)

    end,

    OnKilled = function(npc)

        if npc.LS_Escaped then
            return
        end

        dropLoot(npc, 2)
        sound.Play("ambient/levels/labs/coinslot1.wav", npc:GetPos(), 80, 100)

    end

})
