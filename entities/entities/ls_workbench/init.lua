-- The crafting Workbench: a static prop in the hub. Use it (E) to open the
-- crafting menu. Its position is saved per map like the Broker and Vendor.

AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local anchorFile = "lootershooter_hub_anchors.txt"

-- Models in order of preference; the first one that exists is used.
local MODELS = {
    "models/props_wasteland/controlroom_desk001b.mdl",
    "models/props_c17/FurnitureTable002a.mdl",
    "models/props_wasteland/kitchen_counter001a.mdl",
    "models/props_junk/wood_crate002a.mdl"
}

local function loadAnchors()
    if not file.Exists(anchorFile, "DATA") then return {} end
    return util.JSONToTable(file.Read(anchorFile, "DATA")) or {}
end

local function createBench(position, angles)

    local bench = ents.Create("ls_workbench")

    if not IsValid(bench) then return nil end

    bench:SetPos(position)
    bench:SetAngles(angles)
    bench:Spawn()

    return bench

end

function ENT:Initialize()

    local model = MODELS[#MODELS]

    for _, candidate in ipairs(MODELS) do
        if util.IsValidModel(candidate) then
            model = candidate
            break
        end
    end

    self:SetModel(model)
    self:PhysicsInitStatic(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

end

function ENT:Use(player)

    if not IsValid(player) or not player:IsPlayer() then return end
    if player:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end
    if self.LS_NextUse and self.LS_NextUse > CurTime() then return end

    self.LS_NextUse = CurTime() + 0.5

    self:EmitSound("ambient/machines/keyboard" .. math.random(1, 6) .. "_clicks.wav", 65, 100)

    net.Start("LS_OpenWorkbench")
    net.Send(player)

end

concommand.Add("ls_spawnworkbench", function(player)

    if not IsValid(player) then return end

    local trace = player:GetEyeTrace()

    if not trace.Hit then return end

    local direction = player:GetPos() - trace.HitPos
    direction.z = 0

    if IsValid(createBench(trace.HitPos, Angle(0, direction:Angle().y, 0))) then
        print("[LS] Workbench placed. Look at it and run ls_saveworkbenchanchor to keep this position.")
    end

end)

concommand.Add("ls_saveworkbenchanchor", function(player)

    if not IsValid(player) then return end

    local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()

    if not profile or not profile.IsHub then
        print("[LS] Workbench anchors can only be saved on a registered hub map.")
        return
    end

    local bench = player:GetEyeTrace().Entity

    if not IsValid(bench) or bench:GetClass() ~= "ls_workbench" then
        print("[LS] Look directly at the Workbench, then run ls_saveworkbenchanchor.")
        return
    end

    local position, angles = bench:GetPos(), bench:GetAngles()
    local anchors = loadAnchors()

    anchors[game.GetMap()] = anchors[game.GetMap()] or {}
    anchors[game.GetMap()].Workbench = {
        Position = {x = position.x, y = position.y, z = position.z},
        Angles = {p = angles.p, y = angles.y, r = angles.r}
    }

    file.Write(anchorFile, util.TableToJSON(anchors, true))
    print("[LS] Workbench anchor saved for " .. game.GetMap() .. ".")

end)

concommand.Add("ls_clearworkbenchanchor", function()

    local anchors = loadAnchors()

    if anchors[game.GetMap()] then anchors[game.GetMap()].Workbench = nil end

    file.Write(anchorFile, util.TableToJSON(anchors, true))
    print("[LS] Saved Workbench anchor cleared for " .. game.GetMap() .. ".")

end)

concommand.Add("ls_removeworkbenches", function()

    for _, bench in ipairs(ents.FindByClass("ls_workbench")) do bench:Remove() end

    print("[LS] Workbenches removed.")

end)

hook.Add("InitPostEntity", "LS_LoadHubWorkbench", function()

    timer.Simple(1, function()

        local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()
        local anchor = loadAnchors()[game.GetMap()]
        local data = anchor and anchor.Workbench

        if not profile or not profile.IsHub or not data or not data.Position or not data.Angles then return end

        createBench(
            Vector(data.Position.x, data.Position.y, data.Position.z),
            Angle(data.Angles.p, data.Angles.y, data.Angles.r)
        )

    end)

end)
