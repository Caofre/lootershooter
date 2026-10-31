AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Each kind lists models in order of preference; the first that exists is used.
local models = {
    generator = {
        "models/props_vehicles/generatortrailer01.mdl",
        "models/props_c17/substation_transformer01a.mdl",
        "models/props_junk/wood_crate002a.mdl"
    },
    crate = {
        "models/Items/item_item_crate.mdl",
        "models/props_junk/wood_crate001a.mdl"
    },
    nest = {
        "models/props_wasteland/rockgranite02b.mdl",
        "models/props_junk/wood_crate002a.mdl"
    },
    terminal = {
        "models/props_combine/combine_interface001.mdl",
        "models/props_lab/monitor01a.mdl",
        "models/props_junk/wood_crate001a.mdl"
    }
}

local HACK_SECONDS = 7
local HACK_DECAY_PER_SECOND = 18

local function pickModel(kind)

    for _, model in ipairs(models[kind] or models.crate) do
        if util.IsValidModel(model) then
            return model
        end
    end

    return "models/props_junk/wood_crate001a.mdl"

end

function ENT:Initialize()

    local kind = self:GetKind()

    if kind == "" then
        kind = "crate"
        self:SetKind(kind)
    end

    self:SetModel(pickModel(kind))
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(kind == "terminal" and CONTINUOUS_USE or SIMPLE_USE)

    local physics = self:GetPhysicsObject()

    if IsValid(physics) then
        physics:EnableMotion(false)
    end

    if kind == "crate" then
        self:SetColor(Color(255, 220, 140))
    elseif kind == "nest" then
        self:SetColor(Color(150, 220, 120))
    end

    self.LS_Progress = 0

end

function ENT:SetupHealth(amount)

    self:SetObjMaxHealth(amount)
    self:SetObjHealth(amount)

end

-- Applies damage to the objective's own health pool. Used by weapons (Nest),
-- and by the Defend contract's siege logic (Generator).
function ENT:DamageObjective(amount, attacker)

    if self:GetDone() or amount <= 0 then
        return
    end

    local health = math.max(0, self:GetObjHealth() - amount)

    self:SetObjHealth(math.floor(health))

    if CurTime() >= (self.LS_NextHitFX or 0) then
        self.LS_NextHitFX = CurTime() + 0.25

        local effect = EffectData()
        effect:SetOrigin(self:WorldSpaceCenter() + VectorRand() * 20)
        util.Effect("ManhackSparks", effect)

        self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 70, math.random(90, 110))
    end

    if health <= 0 then
        self:SetDone(true)

        local effect = EffectData()
        effect:SetOrigin(self:WorldSpaceCenter())
        effect:SetScale(2)
        util.Effect("Explosion", effect, true, true)

        if self.LS_OnDestroyed then
            self.LS_OnDestroyed(self, attacker)
        end
    end

end

function ENT:OnTakeDamage(dmginfo)

    local kind = self:GetKind()
    local attacker = dmginfo:GetAttacker()

    if kind == "nest" and IsValid(attacker) and attacker:IsPlayer() then
        self:DamageObjective(dmginfo:GetDamage(), attacker)
    elseif kind == "generator" and IsValid(attacker) and attacker:IsNPC() then
        -- Players cannot wreck their own generator; enemies can.
        self:DamageObjective(dmginfo:GetDamage(), attacker)
    end

end

function ENT:Use(activator)

    if not IsValid(activator) or not activator:IsPlayer() or self:GetDone() then
        return
    end

    local kind = self:GetKind()

    if kind == "crate" then

        self:SetDone(true)
        self:EmitSound("items/ammocrate_open.wav", 75, 110)

        if self.LS_OnUse then
            self.LS_OnUse(self, activator)
        end

    elseif kind == "terminal" then

        -- Called every tick while E is held; Think turns that into progress.
        self.LS_HeldUntil = CurTime() + 0.3

    end

end

function ENT:Think()

    if self:GetKind() == "terminal" and not self:GetDone() then

        local now = CurTime()
        local delta = now - (self.LS_LastThink or now)

        self.LS_LastThink = now

        if (self.LS_HeldUntil or 0) > now then
            self.LS_Progress = math.min(100, self.LS_Progress + delta * 100 / (self.HackSeconds or HACK_SECONDS))

            if now >= (self.LS_NextBeep or 0) then
                self.LS_NextBeep = now + 0.6
                self:EmitSound("buttons/blip1.wav", 65, 100 + self.LS_Progress)
            end
        else
            self.LS_Progress = math.max(0, self.LS_Progress - delta * HACK_DECAY_PER_SECOND)
        end

        self:SetProgress(math.floor(self.LS_Progress))

        if self.LS_Progress >= 100 then
            self:SetDone(true)
            self:EmitSound("buttons/button9.wav", 75, 110)

            if self.LS_OnUse then
                self.LS_OnUse(self)
            end
        end

    end

    self:NextThink(CurTime() + 0.1)

    return true

end
