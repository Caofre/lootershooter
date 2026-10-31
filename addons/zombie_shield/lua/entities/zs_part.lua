AddCSLuaFile()

ENT.Type      = "anim"
ENT.PrintName = "Shield Part"
ENT.Category  = "Zombie Shield"
ENT.Spawnable = false -- spawned via the per-part entries registered in autorun/zombie_shield.lua

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "PartID")
end

if CLIENT then return end

-- the spawn menu entries pass { part = <id> } as a key/value
function ENT:KeyValue(key, value)
    if key == "part" then self:SetPartID(tonumber(value) or 1) end
end

function ENT:Initialize()
    local id = self:GetPartID()
    if id < 1 or id > #ZS.Parts then
        id = math.random(#ZS.Parts)
        self:SetPartID(id)
    end

    self:SetModel(ZS.Parts[id].model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    local id = self:GetPartID()
    if ZS.HasPart(ply, id) then
        ply:PrintMessage(HUD_PRINTCENTER, "You already have the " .. ZS.Parts[id].name .. ".")
        return
    end

    ZS.GivePart(ply, id)
    self:Remove()
end
