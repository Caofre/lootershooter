-- The Riot Plate gadget: a real physics plate worn on the player's back,
-- dragged along by shadow control (adapted from the Zombie Shield addon). It
-- absorbs damage that hits it, or that comes from behind, until its durability
-- is gone, then breaks and the gadget goes on cooldown.

AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

LS_BackShield = LS_BackShield or {}

LS_BackShield.Model = "models/hunter/plates/plate1x1.mdl"
LS_BackShield.Color = Color(120, 130, 140)
LS_BackShield.BackOffset = 14
LS_BackShield.Height = 40
LS_BackShield.RearArcDot = math.cos(math.rad(70))
LS_BackShield.BlockMask = bit.bor(
    DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_SLASH, DMG_CLUB, DMG_CRUSH, DMG_BLAST
)

function LS_BackShield.GetTransform(player)

    local yaw = player:EyeAngles().y
    local base = Angle(0, yaw, 0)
    local height = player:OBBMaxs().z / 72

    local position = player:GetPos() +
        Vector(0, 0, LS_BackShield.Height * height) -
        base:Forward() * LS_BackShield.BackOffset

    local angles = Angle(0, yaw, 0)
    angles:RotateAroundAxis(angles:Right(), 90)

    return position, angles

end

-- Is `position` inside the protected rear arc of the player?
function LS_BackShield.IsBehind(player, position)

    local direction = position - player:WorldSpaceCenter()
    direction.z = 0

    if direction:LengthSqr() < 1 then
        return false
    end

    direction:Normalize()

    return Angle(0, player:EyeAngles().y, 0):Forward():Dot(direction) <= -LS_BackShield.RearArcDot

end

function ENT:Initialize()

    local model = LS_BackShield.Model

    if not util.IsValidModel(model) then
        model = "models/props_junk/wood_crate001a.mdl"
    end

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    -- Does not block players or the world, but is still hit by bullets and melee.
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetColor(LS_BackShield.Color)

    self:SetMaxHealth(999999)
    self:SetHealth(999999)

    local physics = self:GetPhysicsObject()

    if IsValid(physics) then
        physics:SetMass(40)
        physics:EnableGravity(false)
        physics:SetMaterial("metal")
        physics:Wake()
    end

    self.Shadow = {}
    self:StartMotionController()

end

function ENT:SetDurabilityPool(amount)

    self:SetMaxDurability(amount)
    self:SetDurability(amount)
    self:SyncWearer()

end

function ENT:SyncWearer()

    local wearer = self:GetWearer()

    if IsValid(wearer) then
        wearer:SetNW2Float("LS_GadgetFill", self:GetDurability() / math.max(1, self:GetMaxDurability()))
    end

end

function ENT:PhysicsSimulate(physics, deltaTime)

    local wearer = self:GetWearer()

    if not IsValid(wearer) or not wearer:Alive() then
        return
    end

    local position, angles = LS_BackShield.GetTransform(wearer)
    local shadow = self.Shadow

    shadow.secondstoarrive = 0.03
    shadow.pos = position
    shadow.angle = angles
    shadow.maxangular = 5000
    shadow.maxangulardamp = 10000
    shadow.maxspeed = 1000000
    shadow.maxspeeddamp = 10000
    shadow.dampfactor = 0.8
    shadow.teleportdistance = 100
    shadow.deltatime = deltaTime

    physics:Wake()
    physics:ComputeShadowControl(shadow)

end

function ENT:Think()

    local wearer = self:GetWearer()

    if not IsValid(wearer) or not wearer:Alive() then
        self:Remove()
        return
    end

    self:NextThink(CurTime() + 0.25)

    return true

end

function ENT:OnRemove()

    local wearer = self:GetWearer()

    if IsValid(wearer) and wearer.LS_BackShield == self then
        wearer.LS_BackShield = nil
        wearer:SetNW2Bool("LS_GadgetShield", false)
    end

end

-- Direct hits on the plate.
function ENT:OnTakeDamage(dmginfo)

    if self.Broken or dmginfo:GetAttacker() == self:GetWearer() then
        return
    end

    if bit.band(dmginfo:GetDamageType(), LS_BackShield.BlockMask) == 0 then
        return
    end

    local amount = dmginfo:GetDamage()

    self:Absorb(amount, dmginfo:GetDamagePosition())

    if LS_Gadgets then
        LS_Gadgets.TriggerShieldHit(self:GetWearer(), dmginfo:GetAttacker(), amount, self)
    end

end

-- Takes `amount` damage and returns how much was NOT absorbed.
function ENT:Absorb(amount, position)

    if self.Broken then
        return amount
    end

    local durability = self:GetDurability()
    local taken = math.min(durability, amount)

    durability = durability - taken
    self:SetDurability(durability)
    self:SyncWearer()

    position = position or self:GetPos()

    local effect = EffectData()
    effect:SetOrigin(position)
    effect:SetNormal(-self:GetForward())
    util.Effect("ManhackSparks", effect)

    self:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", 70, math.random(95, 110))

    -- Tint shifts toward burnt red as it wears down.
    local fraction = durability / math.max(self:GetMaxDurability(), 1)
    local base = LS_BackShield.Color

    self:SetColor(Color(
        Lerp(fraction, 200, base.r),
        Lerp(fraction, 60, base.g),
        Lerp(fraction, 50, base.b)
    ))

    if durability <= 0 then
        self:Break()
    end

    return amount - taken

end

function ENT:Break()

    if self.Broken then
        return
    end

    self.Broken = true

    local wearer = self:GetWearer()

    -- Deferred so nothing is deleted in the middle of a damage callback.
    timer.Simple(0, function()

        if not IsValid(self) then
            return
        end

        local position = self:GetPos()

        sound.Play("physics/metal/metal_box_break1.wav", position, 80, 100)

        local effect = EffectData()
        effect:SetOrigin(position)
        util.Effect("ManhackSparks", effect)

        for _ = 1, 3 do
            local debris = ents.Create("prop_physics")

            if IsValid(debris) then
                debris:SetModel(self:GetModel())
                debris:SetPos(position + VectorRand() * 6)
                debris:SetAngles(AngleRand())
                debris:Spawn()
                debris:SetModelScale(0.3, 0)
                debris:SetColor(self:GetColor())
                debris:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

                local physics = debris:GetPhysicsObject()

                if IsValid(physics) then
                    physics:SetVelocity(VectorRand() * 150 + Vector(0, 0, 100))
                end

                SafeRemoveEntityDelayed(debris, 6)
            end
        end

        if IsValid(wearer) then
            wearer:PrintMessage(HUD_PRINTCENTER, "Your riot plate broke!")
            LS_Gadgets.ShieldBroken(wearer)
        end

        self:Remove()

    end)

end

-- Hits that come from behind are absorbed even if they missed the plate itself.
hook.Add("EntityTakeDamage", "LS_BackShieldAbsorb", function(target, dmginfo)

    if not IsValid(target) or not target:IsPlayer() then
        return
    end

    local plate = target.LS_BackShield

    if not IsValid(plate) or plate.Broken or dmginfo:GetDamage() <= 0 then
        return
    end

    if bit.band(dmginfo:GetDamageType(), LS_BackShield.BlockMask) == 0 then
        return
    end

    local attacker = dmginfo:GetAttacker()

    if not IsValid(attacker) or attacker == target then
        return
    end

    if not LS_BackShield.IsBehind(target, attacker:WorldSpaceCenter()) then
        return
    end

    local incoming = dmginfo:GetDamage()
    local remaining = plate:Absorb(incoming, plate:GetPos())

    if LS_Gadgets then
        LS_Gadgets.TriggerShieldHit(target, attacker, incoming, plate)
    end

    dmginfo:SetDamage(remaining)

    if remaining <= 0 then
        dmginfo:SetDamageForce(vector_origin)
        return true
    end

end)

hook.Add("PhysgunPickup", "LS_BackShieldNoPhysgun", function(_, entity)
    if IsValid(entity) and entity:GetClass() == "ls_back_shield" then return false end
end)

hook.Add("GravGunPickupAllowed", "LS_BackShieldNoGrav", function(_, entity)
    if IsValid(entity) and entity:GetClass() == "ls_back_shield" then return false end
end)
