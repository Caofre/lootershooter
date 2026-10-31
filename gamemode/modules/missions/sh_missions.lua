LS_Missions = LS_Missions or {}

local missions = LS_Missions
missions.MapProfiles = missions.MapProfiles or {}
missions.Types = missions.Types or {}
missions.Active = nil
missions.NextID = missions.NextID or 1

local legacyAnchorFile = "lootershooter_mission_anchors.txt"
local siteAnchorFile = "lootershooter_mission_sites.txt"

missions.States = {
    Idle = "idle", Starting = "starting", Active = "active", Succeeded = "succeeded",
    Failed = "failed", CleaningUp = "cleaning_up"
}

local function readAnchorFile(path)
    if not file.Exists(path, "DATA") then return {} end
    return util.JSONToTable(file.Read(path, "DATA")) or {}
end

local function vectorFromData(data)
    if not data or not data.Position then return nil end
    return Vector(data.Position.x, data.Position.y, data.Position.z)
end

function missions.RegisterMapProfile(data)
    if not data or not data.Map or data.Map == "" then error("LS mission map profiles require a Map name.") end
    data.Name = data.Name or data.Map
    data.SpawnZones = data.SpawnZones or {}
    data.ObjectiveZones = data.ObjectiveZones or {}
    data.SupportedMissionTypes = data.SupportedMissionTypes or {}
    data.DevelopmentOnly = data.DevelopmentOnly or false
    missions.MapProfiles[data.Map] = data
end

function missions.GetMapProfile(mapName)
    return missions.MapProfiles[mapName or game.GetMap()]
end

function missions.GetBountyZone(mapName)
    return readAnchorFile(legacyAnchorFile)[mapName or game.GetMap()]
end

function missions.SetBountyZone(mapName, position, radius)
    local data = readAnchorFile(legacyAnchorFile)
    data[mapName] = {Position = {x = position.x, y = position.y, z = position.z}, Radius = radius}
    file.Write(legacyAnchorFile, util.TableToJSON(data, true))
end

function missions.GetSites(mapName)
    local sites = readAnchorFile(siteAnchorFile)[mapName or game.GetMap()] or {}
    local legacy = missions.GetBountyZone(mapName)
    if legacy then
        local hasOutskirts = false
        for _, site in ipairs(sites) do
            if site.ID == "outskirts" then
                hasOutskirts = true
                break
            end
        end
        if not hasOutskirts then
            table.insert(sites, 1, {ID = "outskirts", Name = "Outskirts", Position = legacy.Position, Radius = legacy.Radius})
        end
    end
    return sites
end

function missions.SetSite(mapName, id, name, position, radius)
    local data = readAnchorFile(siteAnchorFile)
    local mapSites = data[mapName] or {}
    local site = {ID = id, Name = name, Position = {x = position.x, y = position.y, z = position.z}, Radius = radius}
    for index, existing in ipairs(mapSites) do
        if existing.ID == id then
            mapSites[index] = site
            data[mapName] = mapSites
            file.Write(siteAnchorFile, util.TableToJSON(data, true))
            return
        end
    end
    table.insert(mapSites, site)
    data[mapName] = mapSites
    file.Write(siteAnchorFile, util.TableToJSON(data, true))
end

function missions.RemoveSite(mapName, id)
    -- The automatic "outskirts" site comes from the old bounty zone.
    if id == "outskirts" then
        local legacy = readAnchorFile(legacyAnchorFile)
        if not legacy[mapName] then return false end
        legacy[mapName] = nil
        file.Write(legacyAnchorFile, util.TableToJSON(legacy, true))
        return true
    end

    local data = readAnchorFile(siteAnchorFile)
    local mapSites = data[mapName] or {}

    for index, existing in ipairs(mapSites) do
        if existing.ID == id then
            table.remove(mapSites, index)
            data[mapName] = mapSites
            file.Write(siteAnchorFile, util.TableToJSON(data, true))
            return true
        end
    end

    return false
end

function missions.RegisterType(data)
    if not data or not data.ID or data.ID == "" then error("LS mission types require an ID.") end
    data.Name = data.Name or data.ID
    data.Description = data.Description or ""
    data.Validate = data.Validate or function() return true end
    data.OnStart = data.OnStart or function() end
    data.OnComplete = data.OnComplete or function() end
    data.OnFail = data.OnFail or function() end
    data.OnCleanup = data.OnCleanup or function() end
    missions.Types[data.ID] = data
end

function missions.GetType(id) return missions.Types[id] end

function missions.IsTypeSupported(profile, typeID)
    if not profile then return false end
    for _, supportedID in ipairs(profile.SupportedMissionTypes) do
        if supportedID == typeID then return true end
    end
    return false
end

local function syncState()
    local active = missions.Active
    SetGlobalBool("LS_MissionActive", active ~= nil)
    SetGlobalString("LS_MissionState", active and active.State or missions.States.Idle)
    SetGlobalString("LS_MissionType", active and active.TypeID or "")
    SetGlobalString("LS_MissionName", active and active.Name or "")
end

-- The client soundtrack follows this global (see cl_music.lua). Victory and
-- failure are short stings, so the state falls back to "hub" afterwards.
function missions.SetMusic(state)
    if not SERVER then return end

    timer.Remove("LS_MusicRevert")
    SetGlobalString("LS_MusicState", state)

    if state == "victory" or state == "fail" then
        timer.Create("LS_MusicRevert", 12, 1, function()
            SetGlobalString("LS_MusicState", "hub")
        end)
    end
end

function missions.SetObjective(text, position, radius)
    SetGlobalString("LS_MissionObjective", text or "")
    SetGlobalVector("LS_MissionTarget", position or vector_origin)
    SetGlobalInt("LS_MissionTargetRadius", radius or 0)
end

-- A progress bar under the objective box (generator / nest health).
function missions.SetBar(label, value, maximum)
    SetGlobalString("LS_BarLabel", label or "")
    SetGlobalInt("LS_BarValue", math.floor(value or 0))
    SetGlobalInt("LS_BarMax", math.floor(maximum or 0))
end

function missions.Start(typeID, parameters)
    if not SERVER then return false, "Missions can only be started on the server." end
    if missions.Active then return false, "A mission is already active." end
    local profile, missionType = missions.GetMapProfile(), missions.GetType(typeID)
    if not profile then return false, "This map has no Looter Shooter mission profile." end
    if not missionType then return false, "Unknown mission type: " .. tostring(typeID) end
    if not missions.IsTypeSupported(profile, typeID) then return false, missionType.Name .. " is not supported on " .. profile.Name .. "." end
    local mission = {ID = missions.NextID, TypeID = typeID, Name = missionType.Name, Profile = profile, Parameters = parameters or {}, State = missions.States.Starting, StartedAt = CurTime(), Runtime = {}}
    local valid, reason = missionType.Validate(mission)
    if valid == false then return false, reason or "Mission validation failed." end
    missions.NextID = missions.NextID + 1
    missions.Active = mission
    syncState()
    missionType.OnStart(mission)
    missions.SetMusic("travel")
    if missions.Active == mission and mission.State == missions.States.Starting then
        mission.State = missions.States.Active
        syncState()
    end
    return true, mission
end

function missions.Finish(success, reason)
    if not SERVER or not missions.Active then return false end
    local mission = missions.Active
    local missionType = missions.GetType(mission.TypeID)
    mission.State = success and missions.States.Succeeded or missions.States.Failed
    mission.Success = success and true or false
    mission.EndReason = reason
    syncState()
    if success then missionType.OnComplete(mission) else missionType.OnFail(mission) end

    if success then
        missions.SetMusic("victory")
    elseif reason == "Contract abandoned." then
        missions.SetMusic("hub")
    else
        missions.SetMusic("fail")
    end
    mission.State = missions.States.CleaningUp
    syncState()
    missionType.OnCleanup(mission)
    if LS_NPCs then LS_NPCs.MissionLootMult = 1 end
    if missions.Active == mission then
        missions.Active = nil
        syncState()
        missions.SetObjective()
        missions.SetBar()
    end
    return true
end

function missions.Cancel(reason) return missions.Finish(false, reason or "Cancelled") end

missions.Rewards = {
    local_clear = 150,
    retrieve = 170,
    survival = 200,
    hack = 230,
    destroy = 240,
    local_defend = 300,
    alpha_hunt = 350
}

missions.TypeOrder = {"local_clear", "local_defend", "retrieve", "destroy", "hack", "survival", "alpha_hunt"}

missions.TypeInfo = {
    local_clear = {Name = "Sweep and Clear", Label = "CLEAR", Detail = "Sweep the site and eliminate every hostile",
        Description = "Enemy groups are scattered across the site. Eliminate them all, then return to the Broker."},
    local_defend = {Name = "Hold the Generator", Label = "DEFEND", Detail = "Protect the generator through 4 waves",
        Description = "Protect a generator from waves. If it is destroyed, the contract fails."},
    retrieve = {Name = "Supply Run", Label = "RETRIEVE", Detail = "Recover 4 supply crates",
        Description = "Find the supply crates hidden around the site while hostiles patrol it."},
    destroy = {Name = "Nest Purge", Label = "DESTROY", Detail = "Destroy the 3 enemy nests",
        Description = "Nests keep producing enemies until they are destroyed."},
    hack = {Name = "Systems Breach", Label = "HACK", Detail = "Hack 3 terminals while under attack",
        Description = "Hold E at each terminal while waves attack you."},
    survival = {Name = "Siege", Label = "SURVIVE", Detail = "Hold out for 3:30 against escalating waves",
        Description = "Survive escalating waves until the clock runs out."},
    alpha_hunt = {Name = "Hunt the Alpha", Label = "ALPHA HUNT", Detail = "",
        Description = "Track down and eliminate a faction Alpha."}
}

-- Each contract is run against one enemy faction. Tougher factions pay more,
-- and Alpha Hunt targets the faction's own Alpha.
missions.Factions = {
    undead = {Name = "Undead", RewardMult = 1.0, Objective = "Clear the undead",
        Target = {NPC = "poison_zombie", Name = "Alpha Poison Zombie"}},
    antlion = {Name = "Antlion Hive", RewardMult = 1.15, Objective = "Destroy the hive",
        Target = {NPC = "antlion_guard", Name = "Alpha Antlion Guard"}},
    combine = {Name = "Combine Patrol", RewardMult = 1.3, Objective = "Eliminate the Combine patrol",
        Target = {NPC = "combine_elite", Name = "Alpha Combine Elite"}},
    resistance = {Name = "Resistance Cell", RewardMult = 1.3, Objective = "Eliminate the resistance cell",
        Target = {NPC = "rebel_commander", Name = "Alpha Rebel Commander"}}
}
missions.FactionOrder = {"undead", "antlion", "combine", "resistance"}

function missions.GetFaction(id)
    return missions.Factions[id] and id or "undead"
end

-- Contract difficulty tiers. Higher tiers raise enemy level, enemy numbers and
-- variant frequency; in return they pay more, improve loot odds, and give
-- bonus loot caches when the contract is completed.
missions.Tiers = {
    {
        Name = "STANDARD", Color = Color(190, 200, 215),
        LevelBonus = 0, CountMult = 1, VariantMult = 1, RewardMult = 1, LootMult = 1,
        Rarity = {Rare = 1, Epic = 1, Legendary = 1},
        Caches = 0, Components = {scrap = 10, parts = 2},
        Extra = {Waves = 0, Survival = 0, Nests = 0, Crates = 0, Terminals = 0, Groups = 0, Health = 1},
        Description = "The baseline contract."
    },
    {
        Name = "HARD", Color = Color(255, 150, 50),
        LevelBonus = 1, CountMult = 1.25, VariantMult = 1.4, RewardMult = 1.6, LootMult = 1.5,
        Rarity = {Rare = 1.3, Epic = 1.6, Legendary = 2},
        Caches = 1, CacheWeights = {Rare = 70, Epic = 25, Legendary = 5}, Components = {scrap = 14, parts = 5, cores = 1},
        Extra = {Waves = 1, Survival = 30, Nests = 0, Crates = 0, Terminals = 0, Groups = 1, Health = 1.25},
        Description = "Enemies +1 level and 25% more numerous, more variants. 1.6x credits, 1.5x loot chance, better rarity, more components, 1 bonus cache (Rare or better)."
    },
    {
        Name = "EXTREME", Color = Color(235, 70, 60),
        LevelBonus = 2, CountMult = 1.5, VariantMult = 1.9, RewardMult = 2.4, LootMult = 2.5,
        Rarity = {Rare = 1.6, Epic = 2.5, Legendary = 4},
        Caches = 2, CacheWeights = {Rare = 50, Epic = 38, Legendary = 12}, Components = {scrap = 18, parts = 8, cores = 3},
        Extra = {Waves = 2, Survival = 60, Nests = 1, Crates = 1, Terminals = 1, Groups = 2, Health = 1.6},
        Description = "Enemies +2 levels and 50% more numerous, many more variants, bigger objectives. 2.4x credits, 2.5x loot chance, much better rarity, many more components, 2 bonus caches (Rare or better)."
    }
}

-- A later progression system can gate tiers here.
function missions.IsTierUnlocked(tierIndex)
    return true
end

-- The tier of the active mission (STANDARD when none is running).
function missions.ActiveTier()
    local active = missions.Active
    return missions.Tiers[active and active.Runtime and active.Runtime.Tier or 1] or missions.Tiers[1]
end

-- Shifts a rarity weight table toward better loot at higher tiers.
function missions.AdjustLootWeights(weights)

    local tier = missions.ActiveTier()

    if tier == missions.Tiers[1] then
        return weights
    end

    weights = weights or LS_Items.RarityWeights

    local adjusted = {}

    for rarity, weight in pairs(weights) do
        adjusted[rarity] = math.floor(weight * (tier.Rarity[rarity] or 1) * 10 + 0.5)
    end

    return adjusted

end

function missions.GetReward(typeID, factionID, tierIndex)
    local faction = missions.Factions[missions.GetFaction(factionID)]
    local tier = missions.Tiers[tierIndex or 1] or missions.Tiers[1]
    return math.floor((missions.Rewards[typeID] or 0) * faction.RewardMult * tier.RewardMult / 5 + 0.5) * 5
end

function missions.GetBoard()
    local sites = missions.GetSites()
    if #sites == 0 then return {} end

    -- Three different contract types, each against a different faction.
    local types = table.Copy(missions.TypeOrder)
    local factions = table.Copy(missions.FactionOrder)
    table.Shuffle(types)
    table.Shuffle(factions)

    local board = {}

    for index = 1, 3 do
        local typeID, factionID = types[index], factions[index]
        local info = missions.TypeInfo[typeID]
        local site = sites[math.random(#sites)]
        local detail = info.Detail

        if typeID == "alpha_hunt" then
            detail = "Eliminate " .. missions.Factions[factionID].Target.Name
        end

        board[index] = {
            TypeID = typeID, SiteID = site.ID, Theme = factionID, ThemeName = missions.Factions[factionID].Name,
            Reward = missions.GetReward(typeID, factionID, 1),
            Rewards = {missions.GetReward(typeID, factionID, 1), missions.GetReward(typeID, factionID, 2), missions.GetReward(typeID, factionID, 3)},
            Label = info.Label, Detail = detail .. " • " .. site.Name
        }
    end

    return board
end

missions.RegisterMapProfile({Map = "gm_construct", Name = "gm_construct (Development)", DevelopmentOnly = true, SpawnZones = {}, ObjectiveZones = {}, SupportedMissionTypes = {}})
missions.RegisterMapProfile({Map = "gm_atomic_regen", Name = "Atomic Regeneration", IsHub = true, SpawnZones = {}, ObjectiveZones = {}, NPCAnchors = {}, SupportedMissionTypes = {"local_clear", "local_defend", "retrieve", "destroy", "hack", "survival", "alpha_hunt"}})

local function chooseSite(mission)
    local sites = missions.GetSites()
    local requestedID = mission.Parameters.SiteID
    if requestedID then
        for _, site in ipairs(sites) do
            if site.ID == requestedID then return site end
        end
    end
    return #sites > 0 and sites[math.random(#sites)] or nil
end

local function validateSiteMission()
    return #missions.GetSites() > 0, "No mission site has been saved for this hub yet."
end

local function initializeSiteMission(mission)
    local site = chooseSite(mission)
    if not site then return end
    mission.Runtime.Player = mission.Parameters.Player
    mission.Runtime.Site = site
    mission.Runtime.Zone = vectorFromData(site)
    mission.Runtime.Radius = site.Radius
    mission.Runtime.Phase = "travel"
    mission.Runtime.Theme = missions.GetFaction(mission.Parameters.Theme)
    mission.Name = mission.Name .. " (" .. missions.Factions[mission.Runtime.Theme].Name .. ")"

    local tierIndex = math.Clamp(math.floor(tonumber(mission.Parameters.Tier) or 1), 1, #missions.Tiers)

    if not missions.IsTierUnlocked(tierIndex) then
        tierIndex = 1
    end

    mission.Runtime.Tier = tierIndex

    local tier = missions.Tiers[tierIndex]

    if tierIndex > 1 then
        mission.Name = mission.Name .. " [" .. tier.Name .. "]"
    end

    -- Enemies spawned for this contract (including any placed ahead) drop more.
    if SERVER and LS_NPCs then
        LS_NPCs.MissionLootMult = tier.LootMult
    end
    missions.SetObjective("Travel to " .. site.Name, mission.Runtime.Zone, mission.Runtime.Radius)

    -- Handlers may populate the site now, so it is already overrun on arrival.
    local handler = SERVER and missions.Handlers and missions.Handlers[mission.TypeID]

    if handler and handler.Prepare then
        local success, reason = handler.Prepare(mission)

        if success == false then
            missions.Finish(false, reason or "Unable to prepare the contract.")
        end
    end
end

local function siteMissionComplete(mission)
    local player, tier = mission.Runtime.Player, missions.Tiers[mission.Runtime.Tier or 1]

    LS_Currency.Add(player, missions.GetReward(mission.TypeID, mission.Runtime.Theme, mission.Runtime.Tier), "Contract complete")
    LS_Components.AddMany(player, tier.Components, "Contract complete")

    -- Harder contracts also pay out loot caches by the player.
    for _ = 1, tier.Caches do
        local loot = ents.Create("ls_loot")

        if IsValid(loot) and IsValid(player) then
            loot:SetPos(player:GetPos() + Vector(math.Rand(-50, 50), math.Rand(-50, 50), 30))
            loot:SetItem(LS_Items.GenerateItem(tier.CacheWeights))
            loot:Spawn()
        end
    end

    if tier.Caches > 0 and IsValid(player) then
        player:PrintMessage(HUD_PRINTCENTER, tier.Name .. " BONUS: " .. tier.Caches .. " loot cache" .. (tier.Caches > 1 and "s" or ""))
    end

    if LS_Vendor and LS_Vendor.Restock then LS_Vendor.Restock() end
    missions.BrokerSay("success")
    missions.PlayCue(mission.Runtime.Player, "complete")
end

local function siteMissionFail(mission)
    missions.BrokerSay("fail")
    missions.PlayCue(mission.Runtime.Player, "fail")
end

-- Removes whatever the mission left behind. Everything a handler spawns is
-- tagged with LS_MissionID, so it is cleared on success and failure alike.
local function cleanupSiteMission(mission)
    local runtime = mission.Runtime
    local handler = missions.Handlers and missions.Handlers[mission.TypeID]

    if handler and handler.Cleanup then
        handler.Cleanup(mission)
    end

    if not mission.Success then
        if LS_Encounter and LS_Encounter.Active and LS_Encounter.Player == runtime.Player then
            LS_Encounter.Stop(true)
        end

        local target = runtime.Target
        if IsValid(target) then
            for _, entity in ipairs(ents.GetAll()) do
                if IsValid(entity) and entity.LS_SummonedBy == target then entity:Remove() end
            end
            target:Remove()
        end
    end

    for _, entity in ipairs(ents.GetAll()) do
        if IsValid(entity) and entity.LS_MissionID == mission.ID then
            entity:Remove()
        end
    end
end

for _, typeID in ipairs(missions.TypeOrder) do
    local info = missions.TypeInfo[typeID]

    missions.RegisterType({
        ID = typeID, Name = info.Name, Description = info.Description,
        Validate = validateSiteMission, OnStart = initializeSiteMission,
        OnComplete = siteMissionComplete, OnFail = siteMissionFail, OnCleanup = cleanupSiteMission
    })
end

if SERVER then
    util.AddNetworkString("LS_AcceptMission")
    util.AddNetworkString("LS_AbandonMission")
    util.AddNetworkString("LS_ShowSites")

    local function sendSites(player)
        local list = {}

        if player.LS_ShowSites then
            for _, site in ipairs(missions.GetSites()) do
                table.insert(list, {ID = site.ID, Name = site.Name, Position = vectorFromData(site), Radius = site.Radius})
            end
        end

        net.Start("LS_ShowSites")
            net.WriteTable(list)
        net.Send(player)
    end

    local function brokerPosition()
        local broker = readAnchorFile("lootershooter_hub_anchors.txt")[game.GetMap()]
        broker = broker and broker.MissionBroker
        return broker and broker.Position and Vector(broker.Position.x, broker.Position.y, broker.Position.z) or nil
    end

    -- Broker voice lines (HL2 male citizen set, matching the broker's model).
    local brokerLines = {
        greet = {"vo/npc/male01/hi01.wav", "vo/npc/male01/hi02.wav"},
        busy = {"vo/npc/male01/question06.wav", "vo/npc/male01/question11.wav"},
        accept = {"vo/npc/male01/letsgo01.wav", "vo/npc/male01/ok01.wav", "vo/npc/male01/ok02.wav"},
        abandon = {"vo/npc/male01/no01.wav", "vo/npc/male01/no02.wav"},
        success = {"vo/npc/male01/fantastic01.wav", "vo/npc/male01/fantastic02.wav", "vo/npc/male01/nice.wav"},
        fail = {"vo/npc/male01/gordead_ans03.wav", "vo/npc/male01/gordead_ans04.wav"}
    }

    function missions.BrokerSay(kind, broker)
        broker = IsValid(broker) and broker or ents.FindByClass("ls_mission_broker")[1]
        local lines = brokerLines[kind]
        if not IsValid(broker) or not lines then return end
        if broker.LS_VoiceUntil and broker.LS_VoiceUntil > CurTime() then return end
        broker.LS_VoiceUntil = CurTime() + 1.5
        broker:StopSound(broker.LS_LastLine or "")
        broker.LS_LastLine = lines[math.random(#lines)]
        broker:EmitSound(broker.LS_LastLine, 75, 100, 1, CHAN_VOICE)
    end

    function missions.PlayCue(player, name)
        if not IsValid(player) then return end
        local cues = {
            arrive = "buttons/combine_button3.wav",
            cleared = "buttons/button9.wav",
            complete = "buttons/bell1.wav",
            fail = "buttons/button10.wav",
            accept = "buttons/button14.wav"
        }
        if cues[name] then player:EmitSound(cues[name], 60, 100, 0.8) end
    end

    local function beginReturn(mission)
        if missions.Active ~= mission then return end
        mission.Runtime.Phase = "return"
        missions.PlayCue(mission.Runtime.Player, "cleared")
        missions.SetMusic("travel")
        mission.Runtime.Broker = brokerPosition()
        if mission.Runtime.Broker then
            missions.SetObjective("Return to the Mission Broker", mission.Runtime.Broker, 150)
        else
            missions.Finish(true, "Contract complete.")
        end
    end

    -- Find open, grounded floor near the site center that fits a Guard-sized hull.
    local function findAlphaSpawn(center, radius)
        local mins, maxs = Vector(-40, -40, 0), Vector(40, 40, 90)
        for attempt = 1, 24 do
            local offset = attempt == 1 and vector_origin or VectorRand() * math.min(radius * 0.5, 250)
            local start = center + Vector(offset.x, offset.y, 120)
            local ground = util.TraceLine({start = start, endpos = start - Vector(0, 0, 600), mask = MASK_SOLID_BRUSHONLY})
            if ground.Hit and not ground.StartSolid and ground.HitNormal.z > 0.7 then
                local position = ground.HitPos + Vector(0, 0, 4)
                local hull = util.TraceHull({start = position, endpos = position, mins = mins, maxs = maxs, mask = MASK_NPCSOLID})
                if not hull.Hit then return position end
            end
        end
        return center + Vector(0, 0, 12)
    end

    -- Mission handlers (sv_missiontypes.lua) use these.
    missions.BeginReturn = beginReturn
    missions.FindAlphaSpawn = findAlphaSpawn

    timer.Remove("LS_MissionRuntime")
    timer.Create("LS_MissionRuntime", 0.25, 0, function()
        local mission = missions.Active
        if not mission then return end
        local runtime, player = mission.Runtime, mission.Runtime.Player
        if not IsValid(player) or not player:Alive() then
            missions.Finish(false, "You were incapacitated.")
            return
        end

        local handler = missions.Handlers and missions.Handlers[mission.TypeID]

        if runtime.Phase == "travel" and player:GetPos():DistToSqr(runtime.Zone) <= runtime.Radius * runtime.Radius then
            missions.PlayCue(player, "arrive")
            missions.SetMusic("combat")
            if handler and handler.OnArrive then
                handler.OnArrive(mission)
            else
                missions.Finish(false, "This contract type is not available.")
            end
        elseif runtime.Phase == "objective" then
            if handler and handler.Think then handler.Think(mission, CurTime()) end
        elseif runtime.Phase == "return" and runtime.Broker and player:GetPos():DistToSqr(runtime.Broker) <= 150 * 150 then
            missions.Finish(true, "Contract complete.")
        end
    end)

    net.Receive("LS_AcceptMission", function(_, player)
        local typeID = net.ReadString()
        local siteID = net.ReadString()
        local themeID = net.ReadString()
        local tierIndex = net.ReadUInt(3)
        local success, result = missions.Start(typeID, {Player = player, SiteID = siteID, Theme = themeID, Tier = tierIndex})
        if success then
            missions.BrokerSay("accept")
            missions.PlayCue(player, "accept")
        else
            print("[LS] Mission unavailable:", result)
        end
    end)

    net.Receive("LS_AbandonMission", function(_, player)
        if missions.Active and missions.Active.Runtime.Player == player then
            missions.BrokerSay("abandon")
            missions.Cancel("Contract abandoned.")
            print("[LS] Contract abandoned.")
        end
    end)

    concommand.Add("ls_cancelmission", function()
        if missions.Cancel("Contract abandoned.") then print("[LS] Mission cancelled.") else print("[LS] No active mission.") end
    end)

    concommand.Add("ls_setbountyzone", function(player, _, args)
        local profile = missions.GetMapProfile()
        if not IsValid(player) or not profile or not profile.IsHub then return end
        local radius = math.Clamp(tonumber(args[1]) or 500, 250, 1200)
        missions.SetBountyZone(game.GetMap(), player:GetPos(), radius)
        print("[LS] Legacy bounty zone saved. Radius:", radius)
    end)

    concommand.Add("ls_setmissionsite", function(player, _, args)
        local profile, id = missions.GetMapProfile(), string.lower(args[1] or "")
        if not IsValid(player) or not profile or not profile.IsHub or id == "" then
            print("Usage: ls_setmissionsite <id> [radius] [display name]")
            return
        end
        local radius = math.Clamp(tonumber(args[2]) or 500, 250, 1200)
        local name = table.concat(args, " ", 3)
        if name == "" then name = string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2) end
        missions.SetSite(game.GetMap(), id, name, player:GetPos(), radius)
        print("[LS] Mission site saved:", id, "radius:", radius)
        if player.LS_ShowSites then sendSites(player) end
    end)

    -- Draws every site's radius in the world so they can be checked by eye.
    concommand.Add("ls_showmissionsites", function(player)
        if not IsValid(player) then return end
        player.LS_ShowSites = not player.LS_ShowSites
        sendSites(player)
        print("[LS] Mission site markers " .. (player.LS_ShowSites and "ON" or "OFF"))
    end)

    concommand.Add("ls_removemissionsite", function(player, _, args)
        local id = string.lower(args[1] or "")
        if id == "" then print("Usage: ls_removemissionsite <id>") return end
        if missions.RemoveSite(game.GetMap(), id) then
            print("[LS] Mission site removed:", id)
            if IsValid(player) then sendSites(player) end
        else
            print("[LS] No mission site with id:", id)
        end
    end)

    concommand.Add("ls_gotomissionsite", function(player, _, args)
        if not IsValid(player) then return end
        local id = string.lower(args[1] or "")
        for _, site in ipairs(missions.GetSites()) do
            if site.ID == id then
                player:SetPos(vectorFromData(site) + Vector(0, 0, 16))
                return
            end
        end
        print("[LS] No mission site with id:", id)
    end)

    concommand.Add("ls_listmissionsites", function()
        print("[LS] Mission sites for " .. game.GetMap() .. ":")
        for _, site in ipairs(missions.GetSites()) do print(" -", site.ID, "(" .. site.Name .. ")", "radius:", site.Radius) end
    end)
end

if CLIENT then
    hook.Add("HUDPaint", "LS_MissionObjectiveHUD", function()
        local text = GetGlobalString("LS_MissionObjective", "")
        if text == "" then return end
        local target = GetGlobalVector("LS_MissionTarget", vector_origin)
        local distance = math.floor(LocalPlayer():GetPos():Distance(target) / 52.49)
        draw.RoundedBox(4, 24, ScrH() - 105, 360, 58, Color(16, 19, 25, 220))
        draw.SimpleText("MISSION OBJECTIVE", "DermaDefaultBold", 38, ScrH() - 94, Color(255, 155, 45), TEXT_ALIGN_LEFT)
        draw.SimpleText(text .. "  (" .. distance .. "m)", "DermaDefault", 38, ScrH() - 70, Color(235, 238, 245), TEXT_ALIGN_LEFT)
        local marker = target:ToScreen()
        draw.SimpleText("◆", "Trebuchet24", math.Clamp(marker.x, 24, ScrW() - 24), math.Clamp(marker.y, 24, ScrH() - 24), Color(255, 155, 45), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
end
