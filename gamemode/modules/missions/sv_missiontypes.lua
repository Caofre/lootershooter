-- Mission type behavior (server). Each handler has:
--   Prepare(mission)       optional; runs when the contract is accepted, so the
--                          site can be populated before the player gets there.
--                          Return false, reason to abort the contract.
--   OnArrive(mission)      the player reached the site; the objective begins
--   Think(mission, now)    called every 0.25s while Phase == "objective"
--   Cleanup(mission)       optional extra cleanup on top of the generic one
-- A handler finishes its contract with missions.BeginReturn(mission) (success)
-- or missions.Finish(false, reason). Anything it spawns is tagged with
-- LS_MissionID so the generic cleanup can remove it.

if not SERVER then
    return
end

local missions = LS_Missions

-- Enemies a contract places itself (sweeps, patrols, nests) spawn at this
-- level; wave-based contracts start one level above a freeplay wave 1.
local PLACED_LEVEL = 3
local WAVE_LEVEL_BONUS = 1

-- Everything below scales with the contract's difficulty tier.
local function tierOf(mission)
    return missions.Tiers[mission.Runtime.Tier or 1]
end

local function placedLevel(mission)
    return math.min(5, PLACED_LEVEL + tierOf(mission).LevelBonus)
end

local function waveBonus(mission)
    return WAVE_LEVEL_BONUS + tierOf(mission).LevelBonus
end

missions.Handlers = missions.Handlers or {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function tag(mission, entity)

    if IsValid(entity) then
        entity.LS_MissionID = mission.ID
    end

    return entity

end

local function groundAt(position)

    local trace = util.TraceLine({
        start = position + Vector(0, 0, 250),
        endpos = position - Vector(0, 0, 500),
        mask = MASK_SOLID_BRUSHONLY
    })

    if trace.Hit and not trace.StartSolid then
        return trace.HitPos + Vector(0, 0, 4)
    end

    return position + Vector(0, 0, 8)

end

-- A grounded, hull-clear position inside the site, away from `taken` positions.
local function randomSpot(runtime, minFraction, maxFraction, taken, gap, mins, maxs)

    mins = mins or Vector(-24, -24, 0)
    maxs = maxs or Vector(24, 24, 72)

    for _ = 1, 50 do

        local direction = Angle(0, math.Rand(0, 360), 0):Forward()
        local candidate = runtime.Zone + direction * runtime.Radius * math.Rand(minFraction, maxFraction)

        local trace = util.TraceLine({
            start = candidate + Vector(0, 0, 250),
            endpos = candidate - Vector(0, 0, 500),
            mask = MASK_SOLID_BRUSHONLY
        })

        if trace.Hit and not trace.StartSolid and trace.HitNormal.z > 0.8 and
            math.abs(trace.HitPos.z - runtime.Zone.z) < 250 and
            bit.band(util.PointContents(trace.HitPos + Vector(0, 0, 8)), CONTENTS_WATER) == 0 then

            local position = trace.HitPos + Vector(0, 0, 4)

            local hull = util.TraceHull({
                start = position,
                endpos = position,
                mins = mins,
                maxs = maxs,
                mask = MASK_NPCSOLID
            })

            local clear = not hull.Hit

            for _, other in ipairs(taken or {}) do
                if position:DistToSqr(other) < (gap or 150) ^ 2 then
                    clear = false
                    break
                end
            end

            if clear then
                return position
            end

        end

    end

    return nil

end

local function spawnEnemy(mission, entry, position)

    local npc = LS_NPCs.Spawn(entry.NPCID, position, entry.VariantID, entry.Level)

    if IsValid(npc) then
        tag(mission, npc)
        table.insert(mission.Runtime.Enemies, npc)
    end

    return npc

end

-- Placing a whole site at once would hitch the game, so enemies are queued and
-- spawned a couple at a time.
local function queueSpawn(mission, entry, position, onSpawn)

    local runtime = mission.Runtime

    runtime.SpawnQueue = runtime.SpawnQueue or {}
    table.insert(runtime.SpawnQueue, {Entry = entry, Position = position, OnSpawn = onSpawn})

end

timer.Create("LS_MissionSpawnQueue", 0.1, 0, function()

    local mission = missions.Active
    local queue = mission and mission.Runtime.SpawnQueue

    if not queue or #queue == 0 then
        return
    end

    for _ = 1, 2 do

        local job = table.remove(queue, 1)

        if not job then
            break
        end

        local npc = spawnEnemy(mission, job.Entry, job.Position)

        if IsValid(npc) and job.OnSpawn then
            job.OnSpawn(npc)
        end

    end

end)

local function aliveEnemies(runtime)

    local alive = {}

    for _, npc in ipairs(runtime.Enemies) do
        if IsValid(npc) and npc:Health() > 0 then
            table.insert(alive, npc)
        end
    end

    runtime.Enemies = alive

    return alive

end

local function nearestTo(position, entities)

    local best, bestDistance

    for _, entity in ipairs(entities) do
        if IsValid(entity) then
            local distance = entity:GetPos():DistToSqr(position)

            if not bestDistance or distance < bestDistance then
                best, bestDistance = entity, distance
            end
        end
    end

    return best

end

-- Scatters `groups` groups of `perGroup` enemies around the site.
local function scatterEnemies(mission, wave, groups, perGroup)

    local runtime = mission.Runtime
    local centers = {}

    for _ = 1, groups do

        local center = randomSpot(runtime, 0.25, 0.85, centers, 220)

        if center then

            table.insert(centers, center)

            for _, entry in ipairs(LS_Encounter.BuildEntries(runtime.Theme, wave, perGroup, placedLevel(mission))) do
                local position = LS_NPCs.FindReinforcementPosition(center) or (center + VectorRand() * 60 + Vector(0, 0, 8))
                queueSpawn(mission, entry, position)
            end

        end

    end

end

local function leftZone(runtime, player, multiplier)

    return player:GetPos():DistToSqr(runtime.Zone) > (runtime.Radius * multiplier) ^ 2

end

-- Fails the contract if the player stays outside the zone for `seconds`.
local function zoneLeash(mission, player, multiplier, seconds, message)

    local runtime = mission.Runtime

    if leftZone(runtime, player, multiplier) then
        runtime.LeftZoneAt = runtime.LeftZoneAt or CurTime()

        if CurTime() - runtime.LeftZoneAt >= seconds then
            missions.Finish(false, message)
        end
    else
        runtime.LeftZoneAt = nil
    end

end

local function createObjective(mission, kind, position)

    local objective = ents.Create("ls_objective")

    if not IsValid(objective) then
        return nil
    end

    objective:SetKind(kind)
    objective:SetPos(position)
    objective:SetAngles(Angle(0, math.random(0, 359), 0))
    objective:Spawn()
    objective:Activate()

    return tag(mission, objective)

end

local function countAlive(list)

    local count = 0

    for _, entity in ipairs(list) do
        if IsValid(entity) and not entity:GetDone() then
            count = count + 1
        end
    end

    return count

end

----------------------------------------------------------------------
-- Clear: a sweep. Enemy groups are placed around the site; kill them all.
----------------------------------------------------------------------

missions.Handlers.local_clear = {

    -- The site is already full of enemies when the player arrives.
    Prepare = function(mission)

        local runtime = mission.Runtime

        runtime.Enemies = {}
        runtime.SpawnQueue = {}

        scatterEnemies(mission, 4, 4 + tierOf(mission).Extra.Groups, math.ceil(5 * tierOf(mission).CountMult))

        if #runtime.SpawnQueue == 0 then
            return false, "Unable to deploy the hostile force."
        end

    end,

    OnArrive = function(mission)
        mission.Runtime.Phase = "objective"
    end,

    Think = function(mission)

        local runtime = mission.Runtime
        local alive = aliveEnemies(runtime)
        local pending = #(runtime.SpawnQueue or {})

        if #alive == 0 and pending == 0 then
            missions.BeginReturn(mission)
            return
        end

        local nearest = nearestTo(runtime.Player:GetPos(), alive)

        missions.SetObjective(missions.Factions[runtime.Theme].Objective .. " (" .. (#alive + pending) .. " left)",
            IsValid(nearest) and nearest:GetPos() or runtime.Zone, 0)

    end

}

----------------------------------------------------------------------
-- Defend: protect a generator through waves. It cannot be repaired; if it is
-- destroyed the contract fails.
----------------------------------------------------------------------

local GENERATOR_HEALTH = 1500
local GENERATOR_WAVES = 4
local SIEGE_RADIUS = 170
local SIEGE_DPS_PER_ENEMY = 3.5
local SIEGE_MAX_ATTACKERS = 6
-- Enemies this close to the player fight the player instead of marching.
local SIEGE_BREAKOFF = 450

-- Enemy attacks aimed at the invisible target are passed to the generator.
hook.Add("EntityTakeDamage", "LS_GeneratorProxy", function(target, dmginfo)

    if IsValid(target) and target.LS_ProxyFor and IsValid(target.LS_ProxyFor) then

        local attacker = dmginfo:GetAttacker()

        if IsValid(attacker) and attacker:IsNPC() then
            target.LS_ProxyFor:DamageObjective(dmginfo:GetDamage(), attacker)
        end

        dmginfo:SetDamage(0)

        return true

    end

end)

missions.Handlers.local_defend = {

    OnArrive = function(mission)

        local runtime = mission.Runtime
        local generator = createObjective(mission, "generator", groundAt(runtime.Zone))

        if not IsValid(generator) then
            missions.Finish(false, "Unable to deploy the generator.")
            return
        end

        generator:SetupHealth(GENERATOR_HEALTH)
        generator.LS_OnDestroyed = function()
            if missions.Active == mission then
                missions.Finish(false, "The generator was destroyed.")
            end
        end

        runtime.Phase = "objective"
        runtime.Objective = generator
        runtime.TotalWaves = GENERATOR_WAVES + tierOf(mission).Extra.Waves

        -- An invisible target the enemies are told to hate, standing on the generator.
        local bullseye = ents.Create("npc_bullseye")

        if IsValid(bullseye) then
            bullseye:SetPos(generator:WorldSpaceCenter() + Vector(0, 0, 10))
            bullseye:SetKeyValue("health", "1000000")
            bullseye:Spawn()
            bullseye:Activate()
            bullseye.LS_ProxyFor = generator
            runtime.Bullseye = tag(mission, bullseye)
        end

        local target = generator:GetPos()

        LS_Encounter.Start(runtime.Player, runtime.Theme, {
            MaxWaves = runtime.TotalWaves,
            LevelBonus = waveBonus(mission),
            CountMultiplier = tierOf(mission).CountMult,
            Anchor = runtime.Zone,
            AnchorRadius = runtime.Radius,
            OnSpawn = function(npc)
                if IsValid(runtime.Bullseye) then
                    npc:AddEntityRelationship(runtime.Bullseye, D_HT, 99)
                end

                npc:SetLastPosition(target)
                npc:SetSchedule(SCHED_FORCED_GO_RUN)
            end,
            OnComplete = function() missions.BeginReturn(mission) end
        })

    end,

    Think = function(mission)

        local runtime = mission.Runtime
        local generator = runtime.Objective

        if not IsValid(generator) then
            return
        end

        -- Siege: enemies standing at the generator wear it down, whether or
        -- not their AI chose to attack it directly.
        local attackers = 0

        for _, entity in ipairs(ents.FindInSphere(generator:GetPos(), SIEGE_RADIUS)) do
            if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 and
                entity:GetNW2Bool("LS_IsFrameworkNPC", false) then
                attackers = attackers + 1
            end
        end

        if attackers > 0 then
            generator:DamageObjective(math.min(attackers, SIEGE_MAX_ATTACKERS) * SIEGE_DPS_PER_ENEMY * 0.25)
        end

        -- Direct the wave toward the generator.
        local now = CurTime()
        local generatorPosition = generator:GetPos()
        local playerPosition = runtime.Player:GetPos()

        for _, npc in pairs(LS_Encounter.Live) do

            if IsValid(npc) and npc:Health() > 0 and not npc.LS_Frozen and npc.LS_Variant ~= "looter" and
                now >= (npc.LS_NextSiegeOrder or 0) and
                npc:GetPos():DistToSqr(generatorPosition) > SIEGE_RADIUS * SIEGE_RADIUS and
                npc:GetPos():DistToSqr(playerPosition) > SIEGE_BREAKOFF * SIEGE_BREAKOFF then

                npc.LS_NextSiegeOrder = now + 2.5

                npc:SetLastPosition(generatorPosition + Angle(0, math.random(0, 359), 0):Forward() * math.random(60, 110))
                npc:SetSchedule(SCHED_FORCED_GO_RUN)

            end

        end

        zoneLeash(mission, runtime.Player, 1.5, 10, "You abandoned the generator.")

        local wave = math.max(1, LS_Encounter.Wave or 1)

        missions.SetObjective("Defend the generator (wave " .. math.min(wave, runtime.TotalWaves) .. "/" .. runtime.TotalWaves .. ")",
            generator:GetPos(), 0)
        missions.SetBar("GENERATOR", generator:GetObjHealth(), generator:GetObjMaxHealth())

    end,

    Cleanup = function(mission)

        if LS_Encounter.Active then
            LS_Encounter.Stop(true)
        end

    end

}

----------------------------------------------------------------------
-- Retrieve: find supply crates scattered around the site while enemies
-- patrol it and more trickle in.
----------------------------------------------------------------------

local CRATE_COUNT = 4
local TRICKLE_INTERVAL = 28
local TRICKLE_CAP = 10

missions.Handlers.retrieve = {

    -- The crates and the patrols guarding them are placed before the player arrives.
    Prepare = function(mission)

        local runtime = mission.Runtime
        local taken = {}

        runtime.Enemies = {}
        runtime.SpawnQueue = {}
        runtime.Crates = {}
        runtime.Collected = 0

        for _ = 1, CRATE_COUNT + tierOf(mission).Extra.Crates do

            local spot = randomSpot(runtime, 0.2, 0.85, taken, 160, Vector(-20, -20, 0), Vector(20, 20, 40))

            if spot then

                table.insert(taken, spot)

                local crate = createObjective(mission, "crate", spot)

                if IsValid(crate) then
                    crate.LS_OnUse = function(_, player)
                        runtime.Collected = runtime.Collected + 1
                        crate:Remove()
                        runtime.Player:EmitSound("items/ammo_pickup.wav", 70, 100)
                    end

                    table.insert(runtime.Crates, crate)
                end

            end

        end

        runtime.CrateTotal = #runtime.Crates

        if runtime.CrateTotal == 0 then
            return false, "Unable to place the supply crates."
        end

        scatterEnemies(mission, 3, 3, math.ceil(4 * tierOf(mission).CountMult))

    end,

    OnArrive = function(mission)
        mission.Runtime.Phase = "objective"
        mission.Runtime.NextTrickle = CurTime() + TRICKLE_INTERVAL
    end,

    Think = function(mission, now)

        local runtime = mission.Runtime
        local remaining = {}

        for _, crate in ipairs(runtime.Crates) do
            if IsValid(crate) and not crate:GetDone() then
                table.insert(remaining, crate)
            end
        end

        if #remaining == 0 then
            missions.BeginReturn(mission)
            return
        end

        local alive = aliveEnemies(runtime)

        if now >= runtime.NextTrickle and #alive < TRICKLE_CAP then

            runtime.NextTrickle = now + TRICKLE_INTERVAL

            local entries = LS_Encounter.BuildEntries(runtime.Theme, 3, math.ceil(2 * tierOf(mission).CountMult), placedLevel(mission))

            for _, entry in ipairs(entries) do
                local spot = randomSpot(runtime, 0.5, 0.95, {}, 100)

                if spot and spot:DistToSqr(runtime.Player:GetPos()) > 400 * 400 then
                    spawnEnemy(mission, entry, spot)
                end
            end

        end

        local nearest = nearestTo(runtime.Player:GetPos(), remaining)

        missions.SetObjective("Recover the supply crates (" .. runtime.Collected .. "/" .. runtime.CrateTotal .. ")",
            nearest:GetPos(), 0)

    end

}

----------------------------------------------------------------------
-- Destroy: nests keep producing enemies until they are destroyed.
----------------------------------------------------------------------

local NEST_COUNT = 3
local NEST_HEALTH = 450
local NEST_SPAWN_INTERVAL = 14
local NEST_ENEMY_CAP = 4

missions.Handlers.destroy = {

    Prepare = function(mission)

        local runtime = mission.Runtime
        local taken = {}

        runtime.Enemies = {}
        runtime.SpawnQueue = {}
        runtime.Nests = {}

        for _ = 1, NEST_COUNT + tierOf(mission).Extra.Nests do

            local spot = randomSpot(runtime, 0.3, 0.85, taken, 250, Vector(-40, -40, 0), Vector(40, 40, 70))

            if spot then

                table.insert(taken, spot)

                local nest = createObjective(mission, "nest", spot)

                if IsValid(nest) then
                    nest:SetupHealth(math.floor(NEST_HEALTH * tierOf(mission).Extra.Health))
                    nest.LS_Spawned = {}
                    nest.LS_NextSpawn = math.huge -- starts producing once the player arrives
                    table.insert(runtime.Nests, nest)

                    -- A small garrison guards each nest from the start.
                    for _, entry in ipairs(LS_Encounter.BuildEntries(runtime.Theme, 3, math.ceil(2 * tierOf(mission).CountMult), placedLevel(mission))) do
                        local position = LS_NPCs.FindReinforcementPosition(nest:GetPos())

                        if position then
                            queueSpawn(mission, entry, position, function(npc)
                                table.insert(nest.LS_Spawned, npc)
                            end)
                        end
                    end
                end

            end

        end

        runtime.NestTotal = #runtime.Nests

        if runtime.NestTotal == 0 then
            return false, "Unable to place the nests."
        end

    end,

    OnArrive = function(mission)

        mission.Runtime.Phase = "objective"

        for _, nest in ipairs(mission.Runtime.Nests) do
            if IsValid(nest) then
                nest.LS_NextSpawn = CurTime() + 6
            end
        end

    end,

    Think = function(mission, now)

        local runtime = mission.Runtime
        local standing = {}

        for _, nest in ipairs(runtime.Nests) do
            if IsValid(nest) and not nest:GetDone() then
                table.insert(standing, nest)
            end
        end

        if #standing == 0 then
            missions.BeginReturn(mission)
            return
        end

        for _, nest in ipairs(standing) do

            if now >= nest.LS_NextSpawn then

                local alive = {}

                for _, npc in ipairs(nest.LS_Spawned) do
                    if IsValid(npc) and npc:Health() > 0 then
                        table.insert(alive, npc)
                    end
                end

                nest.LS_Spawned = alive
                nest.LS_NextSpawn = now + NEST_SPAWN_INTERVAL

                if #alive < NEST_ENEMY_CAP then

                    for _, entry in ipairs(LS_Encounter.BuildEntries(runtime.Theme, 3, math.ceil(2 * tierOf(mission).CountMult), placedLevel(mission))) do
                        local position = LS_NPCs.FindReinforcementPosition(nest:GetPos())

                        if position then
                            local npc = spawnEnemy(mission, entry, position)

                            if IsValid(npc) then
                                table.insert(nest.LS_Spawned, npc)
                            end
                        end
                    end

                    nest:EmitSound("npc/antlion/digdown1.wav", 75, 100)

                end

            end

        end

        local nearest = nearestTo(runtime.Player:GetPos(), standing)

        missions.SetObjective("Destroy the nests (" .. #standing .. " left)", nearest:GetPos(), 0)

        local total, current = 0, 0

        for _, nest in ipairs(standing) do
            total = total + nest:GetObjMaxHealth()
            current = current + nest:GetObjHealth()
        end

        missions.SetBar("NESTS", current, total)

    end

}

----------------------------------------------------------------------
-- Hack: hold E at each terminal while waves attack.
----------------------------------------------------------------------

local TERMINAL_COUNT = 3

missions.Handlers.hack = {

    OnArrive = function(mission)

        local runtime = mission.Runtime
        local taken = {}

        runtime.Phase = "objective"
        runtime.Terminals = {}

        for _ = 1, TERMINAL_COUNT + tierOf(mission).Extra.Terminals do

            local spot = randomSpot(runtime, 0.2, 0.7, taken, 260, Vector(-24, -24, 0), Vector(24, 24, 60))

            if spot then

                table.insert(taken, spot)

                local terminal = createObjective(mission, "terminal", spot)

                if IsValid(terminal) then
                    terminal.LS_OnUse = function() end
                    table.insert(runtime.Terminals, terminal)
                end

            end

        end

        if #runtime.Terminals == 0 then
            missions.Finish(false, "Unable to place the terminals.")
            return
        end

        runtime.TerminalTotal = #runtime.Terminals

        -- Waves keep coming until every terminal is hacked.
        LS_Encounter.Start(runtime.Player, runtime.Theme, {
            LevelBonus = waveBonus(mission),
            CountMultiplier = tierOf(mission).CountMult,
            Anchor = runtime.Zone,
            AnchorRadius = runtime.Radius
        })

    end,

    Think = function(mission)

        local runtime = mission.Runtime
        local remaining = {}

        for _, terminal in ipairs(runtime.Terminals) do
            if IsValid(terminal) and not terminal:GetDone() then
                table.insert(remaining, terminal)
            end
        end

        if #remaining == 0 then
            LS_Encounter.Stop(true)
            missions.BeginReturn(mission)
            return
        end

        zoneLeash(mission, runtime.Player, 1.6, 12, "You abandoned the terminals.")

        local nearest = nearestTo(runtime.Player:GetPos(), remaining)

        missions.SetObjective("Hack the terminals (" .. (runtime.TerminalTotal - #remaining) .. "/" .. runtime.TerminalTotal ..
            ") - hold E", nearest:GetPos(), 0)

    end,

    Cleanup = function(mission)

        if LS_Encounter.Active then
            LS_Encounter.Stop(true)
        end

    end

}

----------------------------------------------------------------------
-- Survival: last a fixed time against escalating waves.
----------------------------------------------------------------------

local SURVIVAL_SECONDS = 210

missions.Handlers.survival = {

    OnArrive = function(mission)

        local runtime = mission.Runtime

        runtime.Phase = "objective"
        runtime.EndsAt = CurTime() + SURVIVAL_SECONDS + tierOf(mission).Extra.Survival

        LS_Encounter.Start(runtime.Player, runtime.Theme, {
            LevelBonus = waveBonus(mission),
            CountMultiplier = tierOf(mission).CountMult,
            Anchor = runtime.Zone,
            AnchorRadius = runtime.Radius
        })

    end,

    Think = function(mission, now)

        local runtime = mission.Runtime
        local remaining = math.max(0, runtime.EndsAt - now)

        if remaining <= 0 then
            LS_Encounter.Stop(true)
            missions.BeginReturn(mission)
            return
        end

        zoneLeash(mission, runtime.Player, 1.6, 10, "You abandoned the site.")

        missions.SetObjective(string.format("Survive %d:%02d (wave %d)", math.floor(remaining / 60), math.floor(remaining % 60), LS_Encounter.Wave or 0),
            runtime.Zone, runtime.Radius)

    end,

    Cleanup = function(mission)

        if LS_Encounter.Active then
            LS_Encounter.Stop(true)
        end

    end

}

----------------------------------------------------------------------
-- Alpha hunt: a single faction Alpha somewhere in the site.
----------------------------------------------------------------------

missions.Handlers.alpha_hunt = {

    -- The Alpha is already waiting at the site when the player arrives.
    Prepare = function(mission)

        local runtime = mission.Runtime
        local target = missions.Factions[runtime.Theme].Target

        runtime.Target = LS_NPCs.Spawn(target.NPC, missions.FindAlphaSpawn(runtime.Zone, runtime.Radius), "alpha", math.min(6, 4 + tierOf(mission).LevelBonus))

        if not IsValid(runtime.Target) then
            return false, "Unable to deploy the Alpha target."
        end

        tag(mission, runtime.Target)
        runtime.TargetName = target.Name

    end,

    OnArrive = function(mission)
        mission.Runtime.Phase = "objective"
        missions.SetMusic("boss")
    end,

    Think = function(mission)

        local runtime = mission.Runtime

        if not IsValid(runtime.Target) or runtime.Target:Health() <= 0 then
            missions.BeginReturn(mission)
            return
        end

        missions.SetObjective("Eliminate the " .. runtime.TargetName, runtime.Target:GetPos(), runtime.Radius)

    end

}
