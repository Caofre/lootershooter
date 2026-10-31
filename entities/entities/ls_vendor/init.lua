AddCSLuaFile()
AddCSLuaFile("shared.lua")

include("shared.lua")

local anchorFile = "lootershooter_hub_anchors.txt"

local function loadAnchors()
    if not file.Exists(anchorFile, "DATA") then return {} end
    return util.JSONToTable(file.Read(anchorFile, "DATA")) or {}
end

local function createVendor(position, angles, name)
    local vendor = ents.Create("ls_vendor")
    if not IsValid(vendor) then return nil end
    vendor:SetPos(position)
    vendor:SetAngles(angles)
    vendor:Spawn()
    vendor:SetVendorName(name or "Quartermaster")
    return vendor
end

function ENT:Initialize()
    self:SetModel("models/Humans/Group03/female_02.mdl")
    self:SetUseType(SIMPLE_USE)
    self:SetVendorName("Quartermaster")
    LS_HubWander.Setup(self, 200)
end

function ENT:RunBehaviour()
    LS_HubWander.Behave(self)
end

-- The Vendor is a fixture, not a target.
function ENT:OnInjured(damage)
    damage:SetDamage(0)
end

function ENT:OnKilled() end

function ENT:Use(player)
    if not IsValid(player) or not player:IsPlayer() then return end
    if player:GetPos():DistToSqr(self:GetPos()) > 160 * 160 then return end
    if self.LS_NextUse and self.LS_NextUse > CurTime() then return end
    self.LS_NextUse = CurTime() + 0.4
    LS_Vendor.Open(player, self)
end

concommand.Add("ls_spawnvendor", function(player)
    if not IsValid(player) then return end
    local trace = player:GetEyeTrace()
    if not trace.Hit then return end
    local direction = player:GetPos() - trace.HitPos
    direction.z = 0
    if IsValid(createVendor(trace.HitPos, Angle(0, direction:Angle().y, 0))) then
        print("[LS] Vendor placed. Look at it and run ls_savevendoranchor to keep this position.")
    end
end)

concommand.Add("ls_savevendoranchor", function(player)
    if not IsValid(player) then return end
    local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()
    if not profile or not profile.IsHub then
        print("[LS] Vendor anchors can only be saved on a registered hub map.")
        return
    end
    local vendor = player:GetEyeTrace().Entity
    if not IsValid(vendor) or vendor:GetClass() ~= "ls_vendor" then
        print("[LS] Look directly at the Vendor, then run ls_savevendoranchor.")
        return
    end
    local position = vendor.LS_Home or vendor:GetPos()
    local angles = vendor.LS_HomeAngles or vendor:GetAngles()
    local anchors = loadAnchors()
    anchors[game.GetMap()] = anchors[game.GetMap()] or {}
    anchors[game.GetMap()].Vendor = {
        Name = vendor:GetVendorName(),
        Position = {x = position.x, y = position.y, z = position.z},
        Angles = {p = angles.p, y = angles.y, r = angles.r}
    }
    file.Write(anchorFile, util.TableToJSON(anchors, true))
    print("[LS] Vendor anchor saved for " .. game.GetMap() .. ".")
end)

concommand.Add("ls_clearvendoranchor", function()
    local anchors = loadAnchors()
    if anchors[game.GetMap()] then anchors[game.GetMap()].Vendor = nil end
    file.Write(anchorFile, util.TableToJSON(anchors, true))
    print("[LS] Saved Vendor anchor cleared for " .. game.GetMap() .. ".")
end)

concommand.Add("ls_removevendors", function()
    for _, vendor in ipairs(ents.FindByClass("ls_vendor")) do vendor:Remove() end
    print("[LS] Vendors removed.")
end)

hook.Add("InitPostEntity", "LS_LoadHubVendor", function()
    timer.Simple(1, function()
        local profile = LS_Missions and LS_Missions.GetMapProfile and LS_Missions.GetMapProfile()
        local anchor = loadAnchors()[game.GetMap()]
        local data = anchor and anchor.Vendor
        if not profile or not profile.IsHub or not data or not data.Position or not data.Angles then return end
        createVendor(
            Vector(data.Position.x, data.Position.y, data.Position.z),
            Angle(data.Angles.p, data.Angles.y, data.Angles.r),
            data.Name
        )
    end)
end)
