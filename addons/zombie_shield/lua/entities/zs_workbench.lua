AddCSLuaFile()

ENT.Type      = "anim"
ENT.PrintName = "Shield Workbench"
ENT.Category  = "Zombie Shield"
ENT.Spawnable = true

if CLIENT then return end

function ENT:Initialize()
    local mdl = "models/props_c17/FurnitureTable001a.mdl"
    if not util.IsValidModel(mdl) then mdl = "models/props_junk/wood_crate001a.mdl" end

    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(CONTINUOUS_USE) -- Use() fires every tick while E is held

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

local function Notify(ply, text)
    local now = CurTime()
    if now < (ply.ZS_NextMsg or 0) then return end
    ply.ZS_NextMsg = now + 2
    ply:PrintMessage(HUD_PRINTCENTER, text)
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end

    if IsValid(ply.ZS_Shield) then
        Notify(ply, "You're already wearing a shield.")
        return
    end

    if not ZS.HasAllParts(ply) then
        Notify(ply, "You need all " .. #ZS.Parts .. " parts to build the shield.")
        return
    end

    local now = CurTime()

    -- (re)start progress if this is a fresh press
    if ply.ZS_CraftBench ~= self or now - (ply.ZS_LastUse or 0) > 0.3 then
        ply.ZS_CraftStart = now
        ply.ZS_CraftBench = self
        ply.ZS_NextSnd    = 0
    end
    ply.ZS_LastUse = now

    local frac = (now - ply.ZS_CraftStart) / math.max(ZS.CV.craft:GetFloat(), 0.1)
    ply:SetNWFloat("ZS_Craft", math.Clamp(frac, 0, 1))

    if now >= ply.ZS_NextSnd then
        ply.ZS_NextSnd = now + 0.5
        self:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 65)
    end

    if frac >= 1 then
        ply:SetNWInt("ZS_Parts", 0)
        ply:SetNWFloat("ZS_Craft", 0)
        ply.ZS_CraftStart = nil

        ZS.GiveShield(ply)
        self:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 75)
        ply:PrintMessage(HUD_PRINTCENTER, "Zombie Shield built!")
    end
end
