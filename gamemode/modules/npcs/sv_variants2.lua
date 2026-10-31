-- Batch 2 variants: support, summoning, split / revive and death-field.
-- Uses the behavior framework from sv_variants.lua.

if not SERVER then
    return
end

local nearestPlayer = LS_NPCs.NearestPlayer

util.AddNetworkString("LS_Beam")
util.AddNetworkString("LS_FieldFX")

local function sendBeam(from, to, color, duration)

    net.Start("LS_Beam")
        net.WriteVector(from)
        net.WriteVector(to)
        net.WriteColor(color)
        net.WriteFloat(duration or 0.5)
    net.Broadcast()

end

local function sendField(position, radius, duration, color)

    net.Start("LS_FieldFX")
        net.WriteVector(position)
        net.WriteFloat(radius)
        net.WriteFloat(duration)
        net.WriteColor(color)
    net.Broadcast()

end

local function frameworkAllies(npc, radius)

    local allies = {}

    for _, other in ipairs(ents.FindInSphere(npc:GetPos(), radius)) do

        if other ~= npc and IsValid(other) and other:IsNPC() and other:Health() > 0 and
            other:GetNW2Bool("LS_IsFrameworkNPC", false) then
            table.insert(allies, other)
        end

    end

    return allies

end

-- Anything an NPC creates during a wave must also join the wave, otherwise the
-- encounter could end while the extra enemies are still alive.
local function joinEncounter(parent, child)

    if IsValid(child) and parent.LS_EncounterID and LS_Encounter and LS_Encounter.Active and
        LS_Encounter.RegisterNPC then
        LS_Encounter.RegisterNPC(child)
    end

end

local function setNPCHealth(npc, maxHealth, health)

    npc.LS_MaxHealth = maxHealth
    npc:SetNW2Int("LS_MaxHealth", maxHealth)
    npc:SetMaxHealth(maxHealth)
    npc:SetHealth(health or maxHealth)

end

----------------------------------------------------------------------
-- Healer: periodically heals the most injured nearby ally. Kill it first.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "healer",
    LootChanceMultiplier = 1.8,
    Name = "Healer",
    Badge = "HEALER  ◆",
    Color = Color(80, 230, 150),

    HealthMultiplier = 0.8,
    XPMultiplier = 1.4,

    SpawnWave = 4,
    SpawnMax = 5,
    MaxBaseHealth = 200

})

LS_NPCs.RegisterBehavior("healer", {

    OnSpawn = function(npc)
        npc.LS_NextHeal = CurTime() + 3
    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextHeal then
            return
        end

        local target, lowest = nil, 0.85

        for _, ally in ipairs(frameworkAllies(npc, 550)) do

            local fraction = ally:Health() / math.max(1, ally.LS_MaxHealth or ally:GetMaxHealth())

            if fraction < lowest then
                target, lowest = ally, fraction
            end

        end

        if not target then
            npc.LS_NextHeal = now + 0.6
            return
        end

        npc.LS_NextHeal = now + 2

        local amount = math.min((target.LS_MaxHealth or 100) * 0.08, 60)

        target:SetHealth(math.min(target.LS_MaxHealth or target:GetMaxHealth(), target:Health() + amount))
        sendBeam(npc:WorldSpaceCenter(), target:WorldSpaceCenter(), Color(80, 255, 160), 0.6)
        target:EmitSound("items/medshot4.wav", 65, 110, 0.7)

    end

})

----------------------------------------------------------------------
-- Commander: allies near it deal +25% damage while it lives.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "commander",
    LootChanceMultiplier = 2,
    Name = "Commander",
    Badge = "COMMANDER  ◆",
    Color = Color(255, 110, 40),

    HealthMultiplier = 1.3,
    XPMultiplier = 1.6,

    SpawnWave = 5,
    SpawnMax = 4,
    MaxBaseHealth = 200

})

LS_NPCs.RegisterBehavior("commander", {

    OnSpawn = function(npc)
        npc.LS_NextBuff = 0
        npc.LS_NextBeam = 0
    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextBuff then
            return
        end

        npc.LS_NextBuff = now + 1

        local showBeams = now >= npc.LS_NextBeam

        if showBeams then
            npc.LS_NextBeam = now + 3
        end

        local beams = 0

        for _, ally in ipairs(frameworkAllies(npc, 600)) do

            ally.LS_CommanderBuffUntil = now + 2.2

            if showBeams and beams < 4 then
                beams = beams + 1
                sendBeam(npc:WorldSpaceCenter(), ally:WorldSpaceCenter(), Color(255, 130, 40), 0.5)
            end

        end

    end

})

hook.Add("EntityTakeDamage", "LS_CommanderBuffDamage", function(target, dmginfo)

    local attacker = dmginfo:GetAttacker()

    if IsValid(attacker) and attacker.LS_CommanderBuffUntil and attacker.LS_CommanderBuffUntil > CurTime() then
        dmginfo:ScaleDamage(1.25)
    end

end)

----------------------------------------------------------------------
-- Summoner: periodically calls minions, up to a cap. The minion type
-- follows the summoner's faction.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "summoner",
    LootChanceMultiplier = 1.8,
    Name = "Summoner",
    Badge = "SUMMONER  ◆",
    Color = Color(210, 110, 255),

    HealthMultiplier = 1.2,
    XPMultiplier = 1.5,

    SpawnWave = 5,
    SpawnMax = 4,
    MaxBaseHealth = 200

})

local SUMMON_INTERVAL = 9
local SUMMON_CAP = 4

local summonByFaction = {
    Undead = "npc_headcrab",
    Antlion = "antlion",
    Combine = "npc_manhack",
    Resistance = "rebel"
}

local function spawnMinion(summoner, position)

    local choice = summonByFaction[summoner.LS_Faction] or "npc_headcrab"
    local minion

    if LS_NPCs.Get(choice) then
        minion = LS_NPCs.Spawn(choice, position, "normal", math.max(1, (summoner.LS_Level or 1) - 1))

        if IsValid(minion) then
            minion.LS_LootChance = 8
        end
    else
        minion = ents.Create(choice)

        if IsValid(minion) then
            minion:SetPos(position + Vector(0, 0, choice == "npc_manhack" and 60 or 0))
            minion:Spawn()
            minion:Activate()
            LS_NPCs.ApplyNPCRelationships(minion)
        end
    end

    if IsValid(minion) then
        minion.LS_SummonedBy = summoner
        joinEncounter(summoner, minion)
        table.insert(summoner.LS_Minions, minion)

        local effect = EffectData()
        effect:SetOrigin(position + Vector(0, 0, 20))
        util.Effect("ManhackSparks", effect)
    end

end

LS_NPCs.RegisterBehavior("summoner", {

    OnSpawn = function(npc)
        npc.LS_Minions = {}
        npc.LS_NextSummon = CurTime() + 4
    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextSummon then
            return
        end

        local player, distance = nearestPlayer(npc)

        if not IsValid(player) or distance > 1400 then
            return
        end

        local alive = {}

        for _, minion in ipairs(npc.LS_Minions) do
            if IsValid(minion) and minion:Health() > 0 then
                table.insert(alive, minion)
            end
        end

        npc.LS_Minions = alive
        npc.LS_NextSummon = now + SUMMON_INTERVAL

        if #alive >= SUMMON_CAP then
            return
        end

        npc:EmitSound("ambient/energy/zap2.wav", 70, 80)

        for _ = 1, math.min(2, SUMMON_CAP - #alive) do
            local position = LS_NPCs.FindReinforcementPosition(npc:GetPos())

            if position then
                spawnMinion(npc, position)
            end
        end

    end

})

----------------------------------------------------------------------
-- Splitter: bursts into two smaller, weaker copies when killed.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "splitter",
    LootChanceMultiplier = 1.2,
    Name = "Splitter",
    Badge = "SPLITTER  ◆",
    Color = Color(190, 220, 60),

    XPMultiplier = 1.3,

    SpawnWave = 3,
    SpawnMax = 5,
    MaxBaseHealth = 200

})

LS_NPCs.RegisterBehavior("splitter", {

    OnKilled = function(npc)

        local definition = npc.LS_Definition

        if not definition then
            return
        end

        local origin = npc:GetPos()
        local level = math.max(1, (npc.LS_Level or 1) - 1)

        sound.Play("physics/flesh/flesh_bloody_break.wav", origin, 75, 110)

        for _ = 1, 2 do

            local position = LS_NPCs.FindReinforcementPosition(origin) or
                (origin + Vector(math.Rand(-40, 40), math.Rand(-40, 40), 8))

            local copy = LS_NPCs.Spawn(definition.ID, position, "normal", level)

            if IsValid(copy) then
                copy.LS_LootChance = 8
                copy.LS_SummonedBy = npc
                copy:SetModelScale(0.75, 0)
                setNPCHealth(copy, math.max(1, math.floor(copy.LS_MaxHealth * 0.45)))
                joinEncounter(npc, copy)

                local effect = EffectData()
                effect:SetOrigin(position + Vector(0, 0, 20))
                util.Effect("BloodImpact", effect)
            end

        end

    end

})

----------------------------------------------------------------------
-- Infectious (undead only): rises once, three seconds after dying, at half
-- health. Shooting the corpse in that window stops it. Only the second
-- death drops loot.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "infectious",
    LootChanceMultiplier = 1.2,
    Name = "Infectious",
    Badge = "INFECTIOUS  ◆",
    Color = Color(150, 170, 110),

    XPMultiplier = 1.4,

    SpawnWave = 4,
    SpawnMax = 5,
    Factions = {"Undead"},
    MaxBaseHealth = 400

})

local REVIVE_DELAY = 3

LS_NPCs.RegisterBehavior("infectious", {

    OnSpawn = function(npc)
        npc.LS_RealLootChance = npc.LS_LootChance
        npc.LS_LootChance = 0
    end,

    OnKilled = function(npc)

        local definition = npc.LS_Definition

        if not definition then
            return
        end

        local origin = npc:GetPos()
        local level = npc.LS_Level or 1
        local realLoot = npc.LS_RealLootChance or 100
        local parent = npc

        -- Keep the wave open while the corpse might rise.
        if parent.LS_EncounterID and LS_Encounter and LS_Encounter.Hold then
            LS_Encounter.Hold(REVIVE_DELAY + 1)
        end

        timer.Simple(0.4, function()

            local corpse, best = nil, 22500

            for _, entity in ipairs(ents.FindInSphere(origin, 150)) do
                if IsValid(entity) and entity:GetClass() == "prop_ragdoll" and not entity.LS_ReviveCorpse then
                    local distance = entity:GetPos():DistToSqr(origin)

                    if distance < best then
                        corpse, best = entity, distance
                    end
                end
            end

            if IsValid(corpse) then
                corpse.LS_ReviveCorpse = true
                corpse.LS_ReviveArmedAt = CurTime() + 0.3
                corpse:SetRenderMode(RENDERMODE_TRANSCOLOR)
                corpse:SetColor(Color(130, 255, 130))
            end

            timer.Simple(REVIVE_DELAY - 0.4, function()

                if IsValid(corpse) and corpse.LS_ReviveCancelled then
                    return
                end

                local position = IsValid(corpse) and corpse:GetPos() or origin

                if IsValid(corpse) then
                    corpse:Remove()
                end

                local revived = LS_NPCs.Spawn(definition.ID, position + Vector(0, 0, 8), "normal", level)

                if IsValid(revived) then
                    revived.LS_LootChance = realLoot
                    revived.LS_Revived = true
                    revived:SetColor(Color(170, 220, 140))
                    setNPCHealth(revived, revived.LS_MaxHealth, math.max(1, math.floor(revived.LS_MaxHealth * 0.5)))
                    joinEncounter(parent, revived)

                    sound.Play("npc/zombie/zombie_voice_idle" .. math.random(1, 6) .. ".wav", position, 75, 90)

                    local effect = EffectData()
                    effect:SetOrigin(position + Vector(0, 0, 20))
                    util.Effect("BloodImpact", effect)
                end

            end)

        end)

    end

})

hook.Add("EntityTakeDamage", "LS_InfectiousCorpseHit", function(target, dmginfo)

    if not IsValid(target) or not target.LS_ReviveCorpse or target.LS_ReviveCancelled or
        CurTime() < (target.LS_ReviveArmedAt or 0) or dmginfo:GetDamage() <= 0 then
        return
    end

    target.LS_ReviveCancelled = true
    target:SetColor(Color(110, 110, 110))
    target:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 70, 90)

end)

----------------------------------------------------------------------
-- Cryo: leaves a slowing field where it dies. No damage, just a cold zone.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "cryo",
    LootChanceMultiplier = 1.3,
    Name = "Cryo",
    Badge = "CRYO  ◆",
    Color = Color(150, 225, 255),

    HealthMultiplier = 1.1,
    XPMultiplier = 1.3,

    SpawnWave = 3,
    SpawnMax = 5

})

local CRYO_RADIUS = 150
local CRYO_DURATION = 6
local CRYO_SLOW = 0.5

LS_NPCs.RegisterBehavior("cryo", {

    OnKilled = function(npc)

        local position = npc:WorldSpaceCenter()

        sendField(position, CRYO_RADIUS, CRYO_DURATION, Color(190, 235, 255))
        sound.Play("ambient/levels/canals/windchime2.wav", position, 70, 130)

        local endsAt = CurTime() + CRYO_DURATION
        local timerName = "LS_CryoField_" .. tostring(SysTime()) .. math.random(1000)

        timer.Create(timerName, 0.25, 0, function()

            if CurTime() >= endsAt then
                timer.Remove(timerName)
                return
            end

            for _, player in ipairs(player.GetAll()) do

                if IsValid(player) and player:Alive() and player:GetPos():Distance(position) <= CRYO_RADIUS then
                    player.LS_ColdUntil = CurTime() + 0.6
                end

            end

        end)

    end

})

timer.Create("LS_CryoSlow", 0.2, 0, function()

    for _, player in ipairs(player.GetAll()) do

        local cold = player.LS_ColdUntil and player.LS_ColdUntil > CurTime()

        if cold and not player.LS_Chilled then
            player.LS_Chilled = true
            LS_Combat.SetMoveMod(player, "cryo", CRYO_SLOW)
            player:SetNW2Bool("LS_Chilled", true)
        elseif not cold and player.LS_Chilled then
            player.LS_Chilled = nil
            LS_Combat.SetMoveMod(player, "cryo", nil)
            player:SetNW2Bool("LS_Chilled", false)
        end

    end

end)
