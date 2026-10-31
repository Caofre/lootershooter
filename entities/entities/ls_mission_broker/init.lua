AddCSLuaFile()
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("LS_OpenMissionBroker")

local anchorFile = "lootershooter_hub_anchors.txt"

local function loadAnchors()
    if not file.Exists(anchorFile, "DATA") then
        return {}
    end

    return util.JSONToTable(file.Read(anchorFile, "DATA")) or {}
end

local function saveAnchors(anchors)
    file.Write(anchorFile, util.TableToJSON(anchors, true))
end

local function createBroker(position, angles, name)
    local broker = ents.Create("ls_mission_broker")
    if not IsValid(broker) then
        return nil
    end

    broker:SetPos(position)
    broker:SetAngles(angles)
    broker:Spawn()
    broker:SetBrokerName(name or "Mission Broker")
    return broker
end

function ENT:Initialize()
    self:SetModel("models/Humans/Group03/male_07.mdl")
    self:SetUseType(SIMPLE_USE)
    self:SetBrokerName("Mission Broker")
    LS_HubWander.Setup(self, 150)
end

function ENT:RunBehaviour()
    LS_HubWander.Behave(self)
end

-- The Broker is a fixture, not a target.
function ENT:OnInjured(damage)
    damage:SetDamage(0)
end

function ENT:OnKilled() end

function ENT:Use(player)
    if not IsValid(player) or not player:IsPlayer() or
        player:GetPos():DistToSqr(self:GetPos()) > 160 * 160 then
        return
    end

    if self.LS_NextUse and self.LS_NextUse > CurTime() then
        return
    end

    self.LS_NextUse = CurTime() + 0.4

    net.Start("LS_OpenMissionBroker")
        net.WriteEntity(self)
        net.WriteString(self:GetBrokerName())
        net.WriteTable(LS_Missions and LS_Missions.GetBoard and LS_Missions.GetBoard() or {})
    net.Send(player)

    if LS_Missions and LS_Missions.BrokerSay then
        LS_Missions.BrokerSay(GetGlobalBool("LS_MissionActive", false) and "busy" or "greet", self)
    end
end

concommand.Add("ls_spawnmissionbroker", function(player)
    if not IsValid(player) then
        print("[LS] This command must be run by a player.")
        return
    end

    local trace = player:GetEyeTrace()
    if not trace.Hit then
        return
    end

    local direction = player:GetPos() - trace.HitPos
    direction.z = 0

    local broker = createBroker(trace.HitPos, Angle(0, direction:Angle().y, 0))
    if not IsValid(broker) then
        return
    end

    print("[LS] Mission Broker placed. Use it, then tell Codex when you have chosen its final hub position.")
end)

concommand.Add("ls_savebrokeranchor", function(player)
    if not IsValid(player) then
        return
    end

    local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()
    if not profile or not profile.IsHub then
        print("[LS] Broker anchors can only be saved on a registered hub map.")
        return
    end

    local broker = player:GetEyeTrace().Entity
    if not IsValid(broker) or broker:GetClass() ~= "ls_mission_broker" then
        print("[LS] Look directly at the Mission Broker, then run ls_savebrokeranchor.")
        return
    end

    local position = broker.LS_Home or broker:GetPos()
    local angles = broker.LS_HomeAngles or broker:GetAngles()
    local anchors = loadAnchors()
    anchors[game.GetMap()] = anchors[game.GetMap()] or {}
    anchors[game.GetMap()].MissionBroker = {
        Name = broker:GetBrokerName(),
        Position = {x = position.x, y = position.y, z = position.z},
        Angles = {p = angles.p, y = angles.y, r = angles.r}
    }
    saveAnchors(anchors)
    broker.LS_IsPersistentHubBroker = true

    print("[LS] Mission Broker anchor saved for " .. game.GetMap() .. ".")
end)

concommand.Add("ls_clearbrokeranchor", function()
    local anchors = loadAnchors()
    if anchors[game.GetMap()] then anchors[game.GetMap()].MissionBroker = nil end
    saveAnchors(anchors)
    print("[LS] Saved Mission Broker anchor cleared for " .. game.GetMap() .. ".")
end)

concommand.Add("ls_removebrokers", function()
    for _, broker in ipairs(ents.FindByClass("ls_mission_broker")) do
        broker:Remove()
    end
    print("[LS] Mission Brokers removed.")
end)

hook.Add("InitPostEntity", "LS_LoadHubMissionBroker", function()
    timer.Simple(1, function()
        local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()
        local anchor = loadAnchors()[game.GetMap()]
        local broker = anchor and anchor.MissionBroker

        if not profile or not profile.IsHub or not broker or
            not broker.Position or not broker.Angles then
            return
        end

        createBroker(
            Vector(broker.Position.x, broker.Position.y, broker.Position.z),
            Angle(broker.Angles.p, broker.Angles.y, broker.Angles.r),
            broker.Name
        )
    end)
end)
