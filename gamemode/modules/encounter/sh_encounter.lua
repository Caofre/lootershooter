LS_Encounter = LS_Encounter or {}

local encounter = LS_Encounter
encounter.ID = encounter.ID or 0
encounter.Active = false
encounter.Wave = 0
encounter.Queue = {}
encounter.NextSpawn = 0
encounter.BreakEndsAt = 0
encounter.Player = nil
encounter.ThemeID = "undead"
encounter.Live = {}
encounter.Options = {}

-- Enemies are chosen by level. Each tier is {npcID, minLevel, maxLevel, weight};
-- an enemy can be picked while the spawn level falls inside its range.
encounter.Themes = {
    undead = {
        Name = "UNDEAD",
        Tiers = {
            {"zombie", 1, 5, 5},
            {"fast_zombie", 1, 2, 1},
            {"fast_zombie", 3, 5, 2},
            {"zombine", 3, 5, 1},
            {"poison_zombie", 3, 5, 1}
        }
    },
    antlion = {
        Name = "ANTLION HIVE",
        Tiers = {
            {"antlion", 1, 5, 1}
        },
        Boss = "antlion_guard"
    },
    combine = {
        Name = "COMBINE PATROL",
        Tiers = {
            {"metropolice", 1, 2, 5},
            {"combine_soldier", 2, 4, 4},
            {"combine_shotgunner", 2, 5, 3},
            {"combine_elite_soldier", 3, 3, 2},
            {"combine_elite_soldier", 4, 5, 4}
        }
    },
    resistance = {
        Name = "RESISTANCE CELL",
        Tiers = {
            {"rebel", 1, 3, 5},
            {"rebel_shotgunner", 2, 5, 3},
            {"rebel_veteran", 3, 3, 2},
            {"rebel_veteran", 4, 5, 4}
        }
    }
}

local trackedEnemies

local function syncState(status)
    SetGlobalBool("LS_EncounterActive", encounter.Active)
    SetGlobalInt("LS_EncounterWave", encounter.Wave)
    SetGlobalInt("LS_EncounterQueued", #encounter.Queue)
    SetGlobalInt("LS_EncounterAlive", #trackedEnemies())
    SetGlobalString("LS_EncounterTheme", (encounter.Themes[encounter.ThemeID] or {}).Name or "ENCOUNTER")
    SetGlobalString("LS_EncounterStatus", status or "")
    SetGlobalFloat("LS_EncounterBreakEndsAt", encounter.BreakEndsAt or 0)
end

trackedEnemies = function()
    local enemies = {}
    for index, entity in pairs(encounter.Live) do
        if not IsValid(entity) or entity.LS_EncounterDead or entity:Health() <= 0 then
            encounter.Live[index] = nil
        else
            table.insert(enemies, entity)
        end
    end
    return enemies
end

function encounter.RegisterNPC(npc)
    if not IsValid(npc) then
        return
    end

    npc.LS_EncounterID = encounter.ID
    npc.LS_EncounterDead = nil
    encounter.Live[npc:EntIndex()] = npc
end

-- Enemy level rises every three waves. A mission can add a flat bonus through
-- its encounter options (LevelBonus), so contracts start tougher than a freeplay wave 1.
local function waveLevel(wave, bonus)
    return math.min(5, 1 + math.floor((wave - 1) / 3) + (bonus or 0))
end

function encounter.PickNPC(themeID, level)
    local theme = encounter.Themes[themeID] or encounter.Themes.undead
    local candidates, total = {}, 0

    for _, tier in ipairs(theme.Tiers) do
        if level >= tier[2] and level <= tier[3] then
            table.insert(candidates, tier)
            total = total + tier[4]
        end
    end

    if total <= 0 then
        return theme.Tiers[1][1]
    end

    local roll = math.Rand(0, total)

    for _, tier in ipairs(candidates) do
        roll = roll - tier[4]
        if roll <= 0 then return tier[1] end
    end

    return candidates[#candidates][1]
end

-- Chance of each special variant at a given wave. The classic variants keep
-- their original curves; newer ones are data-driven (SpawnWave / SpawnMax on
-- the variant, ramping up over three waves). If the total passes the cap, all
-- chances are scaled down together so waves are never wall-to-wall specials.
local VARIANT_CHANCE_CAP = 55

local function variantMultiplier()
    return LS_Missions and LS_Missions.ActiveTier and LS_Missions.ActiveTier().VariantMult or 1
end

local function variantChances(wave)
    local chances = {
        elite = math.min(35, math.max(0, (wave - 2) * 5)),
        armored = wave >= 4 and math.min(16, 4 + wave) or 0,
        volatile = wave >= 3 and math.min(12, 3 + wave) or 0,
        toxic = wave >= 2 and math.min(9, 2 + wave) or 0,
        shielded = wave >= 4 and math.min(10, 2 + wave) or 0
    }

    for id, variant in pairs(LS_NPCs.Variants or {}) do
        if variant.SpawnWave and wave >= variant.SpawnWave then
            local ramp = math.min(1, (wave - variant.SpawnWave + 1) / 3)
            chances[id] = (variant.SpawnMax or 4) * ramp
        end
    end

    local multiplier = variantMultiplier()

    if multiplier ~= 1 then
        for id, chance in pairs(chances) do
            chances[id] = chance * multiplier
        end
    end

    return chances
end

local function rollVariant(wave, npcID)
    local chances = variantChances(wave)
    local ids, total = {}, 0

    for id, chance in pairs(chances) do
        if chance > 0 and LS_NPCs.CanHaveVariant(id, npcID) then
            table.insert(ids, id)
            total = total + chance
        end
    end

    table.sort(ids)

    -- Harder contracts also allow a higher overall share of variants.
    local cap = VARIANT_CHANCE_CAP * (1 + (variantMultiplier() - 1) * 0.35)
    local scale = total > cap and cap / total or 1
    local roll = math.Rand(0, 100)
    local cumulative = 0

    for _, id in ipairs(ids) do
        cumulative = cumulative + chances[id] * scale
        if roll <= cumulative then return id end
    end

    return "normal"
end

function encounter.BuildWave(wave)
    local queue = {}
    local level = waveLevel(wave, encounter.Options.LevelBonus)
    for _ = 1, math.min(40, math.floor((4 + wave * 2) * (encounter.Options.CountMultiplier or 1))) do
        local npcID = encounter.PickNPC(encounter.ThemeID, level)
        table.insert(queue, {NPCID = npcID, VariantID = rollVariant(wave, npcID), Level = level})
    end
    -- The Guard is currently the only faction-aware Alpha boss. Other themes
    -- will gain bespoke bosses when their matching reinforcement behaviors
    -- are implemented rather than reusing an unrelated Antlion boss.
    local theme = encounter.Themes[encounter.ThemeID]
    if wave % 5 == 0 and theme and theme.Boss then
        table.insert(queue, 1, {NPCID = theme.Boss, VariantID = "alpha", Level = math.max(3, level)})
    end
    return queue
end

-- A batch of wave-style enemy entries (without queueing them) for missions that
-- place enemies themselves.
function encounter.BuildEntries(themeID, wave, count, level)
    local entries = {}
    level = level or waveLevel(wave)

    for _ = 1, count do
        local npcID = encounter.PickNPC(themeID, level)
        table.insert(entries, {NPCID = npcID, VariantID = rollVariant(wave, npcID), Level = level})
    end

    return entries
end

-- Mission encounters spawn around the objective site instead of the player.
-- Positions are grounded, hull-clear, and kept away from the player; the first
-- attempts also prefer spots the player cannot see.
local function findAnchoredSpawn(player, anchor, radius)
    local playerPos, eyePos = player:GetPos(), player:EyePos()
    -- Keep spawns away from the player, but never demand more room than a
    -- small site actually has.
    local minimumDistance = math.min(350, radius * 0.45)
    for attempt = 1, 30 do
        local angle = math.Rand(0, 360)
        local distance = radius * math.Rand(0.3, 0.95)
        local candidate = anchor + Angle(0, angle, 0):Forward() * distance + Vector(0, 0, 320)
        local ground = util.TraceHull({
            start = candidate,
            endpos = candidate - Vector(0, 0, 700),
            mins = Vector(-18, -18, 0),
            maxs = Vector(18, 18, 72),
            mask = MASK_NPCSOLID
        })
        if not ground.Hit or ground.StartSolid or ground.HitNormal.z < 0.7 then continue end

        local position = ground.HitPos + Vector(0, 0, 6)
        if bit.band(util.PointContents(position), CONTENTS_WATER) ~= 0 then continue end
        if position:DistToSqr(playerPos) < minimumDistance * minimumDistance then continue end

        if attempt <= 18 then
            local sight = util.TraceLine({start = eyePos, endpos = position + Vector(0, 0, 40), mask = MASK_SOLID_BRUSHONLY})
            if sight.Fraction >= 0.98 then continue end
        end
        return position
    end
    return nil
end

function encounter.FindSpawnPosition(player)
    if not IsValid(player) then return nil end

    if encounter.Options.Anchor then
        return findAnchoredSpawn(player, encounter.Options.Anchor, encounter.Options.AnchorRadius or 500)
    end

    local origin = player:GetPos()
    local facing = player:EyeAngles():Forward()
    facing.z = 0
    facing:Normalize()

    -- A survival encounter should be readable. Spawn in a nearby ring outside
    -- the player's view, with a clear ground-level route back to the player.
    -- This deliberately does not rely on incomplete sandbox navmeshes.
    for _ = 1, 24 do
        local side = math.random(0, 1) == 0 and -1 or 1
        local yaw = facing:Angle().y + math.Rand(95, 165) * side
        local direction = Angle(0, yaw, 0):Forward()
        local candidate = origin + direction * math.random(300, 500) + Vector(0, 0, 320)
        local ground = util.TraceHull({
            start = candidate,
            endpos = candidate - Vector(0, 0, 560),
            mins = Vector(-18, -18, 0),
            maxs = Vector(18, 18, 72),
            mask = MASK_NPCSOLID
        })
        if not ground.Hit or ground.StartSolid then continue end

        local position = ground.HitPos + Vector(0, 0, 6)
        local toSpawn = position - player:EyePos()
        toSpawn.z = 0
        toSpawn:Normalize()
        local outsideView = facing:Dot(toSpawn) < 0.25
        local route = util.TraceHull({
            start = origin + Vector(0, 0, 18),
            endpos = position + Vector(0, 0, 18),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 48),
            mask = MASK_NPCSOLID,
            filter = player
        })
        local inWater = bit.band(util.PointContents(position), CONTENTS_WATER) ~= 0

        if outsideView and not inWater and route.Fraction >= 0.98 and not route.StartSolid then
            return position
        end
    end

    return nil
end

-- Lets a variant (Infectious) keep the wave open while something is about to
-- rise, so the encounter cannot complete in that gap.
function encounter.Hold(seconds)
    encounter.HoldUntil = math.max(encounter.HoldUntil or 0, CurTime() + seconds)
end

function encounter.BeginWave()
    if not encounter.Active or not IsValid(encounter.Player) then encounter.Stop(false) return end
    encounter.Wave = encounter.Wave + 1
    encounter.Queue = encounter.BuildWave(encounter.Wave)
    encounter.BreakEndsAt = 0
    encounter.NextSpawn = CurTime() + 1.25
    syncState("WAVE " .. encounter.Wave)
end

function encounter.BeginBreak()
    if encounter.Options.MaxWaves and encounter.Wave >= encounter.Options.MaxWaves then
        local completedID = encounter.ID
        local callback = encounter.Options.OnComplete
        syncState("ENCOUNTER COMPLETE")
        timer.Simple(2, function()
            if encounter.Active and encounter.ID == completedID then
                encounter.Stop(false)
                if callback then callback() end
            end
        end)
        return
    end

    encounter.BreakEndsAt = CurTime() + 8
    syncState("WAVE CLEAR")
end

function encounter.Start(player, themeID, options)
    if not IsValid(player) then return false end
    if themeID and not encounter.Themes[themeID] then return false end
    encounter.Stop(true)
    encounter.ID = encounter.ID + 1
    encounter.Active = true
    encounter.Player = player
    encounter.ThemeID = themeID or "undead"
    encounter.Options = options or {}
    encounter.Wave = 0
    encounter.Queue = {}
    encounter.Live = {}
    encounter.HoldUntil = 0
    encounter.BreakEndsAt = CurTime() + 3
    syncState("ENCOUNTER STARTING")
    return true
end

function encounter.Stop(removeEnemies)
    if removeEnemies then
        for _, enemy in ipairs(trackedEnemies()) do enemy:Remove() end
    end
    encounter.Active = false
    encounter.Queue = {}
    encounter.Live = {}
    encounter.Options = {}
    encounter.BreakEndsAt = 0
    encounter.Player = nil
    syncState("")
end

if SERVER then
    hook.Add("OnNPCKilled", "LS_EncounterMarkDead", function(npc)
        if IsValid(npc) and npc.LS_EncounterID then
            npc.LS_EncounterDead = true
            encounter.Live[npc:EntIndex()] = nil
        end
    end)

    hook.Add("EntityRemoved", "LS_EncounterRemoveDeadEntity", function(entity)
        if entity.LS_EncounterID then
            encounter.Live[entity:EntIndex()] = nil
        end
    end)

    timer.Remove("LS_EncounterDirector")
    timer.Create("LS_EncounterDirector", 0.35, 0, function()
        if not encounter.Active then return end
        if not IsValid(encounter.Player) or not encounter.Player:Alive() then encounter.Stop(false) return end
        local enemies = trackedEnemies()
        if encounter.BreakEndsAt > 0 then
            if CurTime() >= encounter.BreakEndsAt then encounter.BeginWave() else syncState("NEXT WAVE") end
            return
        end
        local cap = math.min(10, 4 + math.floor(encounter.Wave * 1.2))
        if #encounter.Queue > 0 and #enemies < cap and CurTime() >= encounter.NextSpawn then
            local entry = table.remove(encounter.Queue, 1)
            local position = encounter.FindSpawnPosition(encounter.Player)
            if position then
                local npc = LS_NPCs.Spawn(entry.NPCID, position, entry.VariantID, entry.Level)
                if IsValid(npc) then
                    encounter.RegisterNPC(npc)

                    if encounter.Options.OnSpawn then
                        encounter.Options.OnSpawn(npc)
                    end
                end
            else
                -- Keep the entry queued until a valid, reachable position is
                -- found; never substitute a questionable spawn location.
                table.insert(encounter.Queue, 1, entry)
            end
            encounter.NextSpawn = CurTime() + 0.8
            enemies = trackedEnemies()
        end
        local theme = encounter.Themes[encounter.ThemeID]
        if #encounter.Queue == 0 and #enemies == 0 and CurTime() >= (encounter.HoldUntil or 0) then encounter.BeginBreak() else syncState((theme and theme.Name or "ENCOUNTER") .. " • WAVE " .. encounter.Wave) end
    end)

    concommand.Add("ls_startencounter", function(player, command, arguments)
        local themeID = string.lower(arguments[1] or "undead")
        if encounter.Start(player, themeID) then
            print("[LS] " .. encounter.Themes[themeID].Name .. " encounter started.")
        else
            print("Usage: ls_startencounter <undead|antlion|combine|resistance>")
        end
    end)
    concommand.Add("ls_stopencounter", function()
        encounter.Stop(true)
        print("[LS] Encounter stopped and its remaining enemies were removed.")
    end)
    concommand.Add("ls_encounterstatus", function()
        print("[LS] Encounter active:", encounter.Active, "wave:", encounter.Wave, "queued:", #encounter.Queue, "alive:", #trackedEnemies())
    end)
end

if CLIENT then
    surface.CreateFont("LS_EncounterTitle", {font = "Trebuchet24", size = 22, weight = 800})
    surface.CreateFont("LS_EncounterBody", {font = "Trebuchet18", size = 15, weight = 700})
    hook.Add("HUDPaint", "LS_EncounterHUD", function()
        if not GetGlobalBool("LS_EncounterActive", false) then return end
        local wave = GetGlobalInt("LS_EncounterWave", 0)
        local queued = GetGlobalInt("LS_EncounterQueued", 0)
        local alive = GetGlobalInt("LS_EncounterAlive", 0)
        local theme = GetGlobalString("LS_EncounterTheme", "ENCOUNTER")
        local status = GetGlobalString("LS_EncounterStatus", "")
        local breakEndsAt = GetGlobalFloat("LS_EncounterBreakEndsAt", 0)
        local width, height = 250, 66
        local x, y = math.floor((ScrW() - width) / 2), 24
        draw.RoundedBox(4, x, y, width, height, Color(16, 19, 25, 225))
        surface.SetDrawColor(255, 155, 45, 210)
        surface.DrawRect(x, y, 4, height)
        draw.SimpleText(theme .. "  •  " .. status, "LS_EncounterTitle", x + 15, y + 9, Color(245, 245, 248), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local body = "Wave " .. wave .. "  •  " .. alive .. " alive  •  " .. queued .. " incoming"
        if breakEndsAt > CurTime() then body = "Next wave in " .. math.ceil(breakEndsAt - CurTime()) .. "s" end
        draw.SimpleText(body, "LS_EncounterBody", x + 15, y + 39, Color(185, 195, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)
end
