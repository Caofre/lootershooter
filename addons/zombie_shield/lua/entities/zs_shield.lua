AddCSLuaFile()

ENT.Type      = "anim"
ENT.PrintName = "Zombie Shield"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Wearer")
    self:NetworkVar("Int",    0, "Durability")
    self:NetworkVar("Int",    1, "MaxDurability")
end

if CLIENT then return end

function ENT:Initialize()
    local mdl = ZS.ShieldModel
    if not util.IsValidModel(mdl) then mdl = "models/props_junk/wood_crate001a.mdl" end

    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    -- Doesn't block players / world (no jitter against walls) but is still hit by bullets & melee traces
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetColor(ZS.ShieldColor)

    local max = ZS.CV.health:GetInt()
    self:SetMaxDurability(max)
    self:SetDurability(max)
    self:SetMaxHealth(999999)
    self:SetHealth(999999) -- real durability is tracked in Absorb()

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(40)
        phys:EnableGravity(false)
        phys:SetMaterial("metal")
        phys:Wake()
    end

    self.Shadow = {}
    self:StartMotionController()
end

-- Physics prop that follows the wearer: shadow control drags it to the back mount every physics tick
function ENT:PhysicsSimulate(phys, dt)
    local ply = self:GetWearer()
    if not IsValid(ply) or not ply:Alive() then return end

    local pos, ang = ZS.GetShieldTransform(ply)
    local s = self.Shadow
    s.secondstoarrive  = 0.03
    s.pos              = pos
    s.angle            = ang
    s.maxangular       = 5000
    s.maxangulardamp   = 10000
    s.maxspeed         = 1000000
    s.maxspeeddamp     = 10000
    s.dampfactor       = 0.8
    s.teleportdistance = 100
    s.deltatime        = dt

    phys:Wake()
    phys:ComputeShadowControl(s)
end

function ENT:Think()
    local ply = self:GetWearer()
    if not IsValid(ply) or not ply:Alive() then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 0.25)
    return true
end

function ENT:OnRemove()
    local ply = self:GetWearer()
    if IsValid(ply) and ply.ZS_Shield == self then
        ply.ZS_Shield = nil
        ply:SetNWEntity("ZS_Shield", NULL)
    end
end

-- Direct hit on the prop (bullets / melee traces that hit the entity itself)
function ENT:OnTakeDamage(dmg)
    if self.ZS_Broken then return end
    if dmg:GetAttacker() == self:GetWearer() then return end
    if bit.band(dmg:GetDamageType(), ZS.BlockMask) == 0 then return end

    self:Absorb(dmg:GetDamage() * ZS.GetDamageScale(), dmg:GetDamagePosition())
end

-- Takes `amount` damage, returns how much was NOT absorbed (overflow once broken)
function ENT:Absorb(amount, pos)
    if self.ZS_Broken then return amount end

    local dur   = self:GetDurability()
    local taken = math.min(dur, amount)
    dur = dur - taken
    self:SetDurability(dur)

    pos = pos or self:GetPos()

    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetNormal(-self:GetForward())
    util.Effect("ManhackSparks", fx)
    self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 70, math.random(95, 110))

    -- tint shifts toward burnt red as it wears down
    local f, base = dur / math.max(self:GetMaxDurability(), 1), ZS.ShieldColor
    self:SetColor(Color(Lerp(f, 200, base.r), Lerp(f, 60, base.g), Lerp(f, 50, base.b)))

    if dur <= 0 then self:Break() end
    return amount - taken
end

function ENT:Break()
    if self.ZS_Broken then return end
    self.ZS_Broken = true

    -- deferred so we never delete things in the middle of a trace / damage callback
    timer.Simple(0, function()
        if not IsValid(self) then return end

        local pos = self:GetPos()
        local ply = self:GetWearer()

        sound.Play("physics/metal/metal_box_break1.wav", pos, 80, 100)
        local fx = EffectData()
        fx:SetOrigin(pos)
        util.Effect("ManhackSparks", fx)

        for _ = 1, 3 do
            local d = ents.Create("prop_physics")
            if IsValid(d) then
                d:SetModel(self:GetModel())
                d:SetPos(pos + VectorRand() * 6)
                d:SetAngles(AngleRand())
                d:Spawn()
                d:SetModelScale(0.3, 0)
                d:SetColor(self:GetColor())
                d:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                local p = d:GetPhysicsObject()
                if IsValid(p) then p:SetVelocity(VectorRand() * 150 + Vector(0, 0, 100)) end
                SafeRemoveEntityDelayed(d, 6)
            end
        end

        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCENTER, "Your shield broke!") end
        self:Remove()
    end)
end
