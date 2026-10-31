-- Adapted from the Zombie Shield addon: a real physics plate that is dragged
-- along by shadow control. Here it is worn in FRONT of an NPC (Phalanx
-- variant). Bullets that hit the plate, or that come from the front arc, are
-- absorbed until its durability runs out; the NPC is then unprotected.

AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

LS_Phalanx = LS_Phalanx or {}

LS_Phalanx.Model = "models/hunter/plates/plate1x1.mdl"
LS_Phalanx.Color = Color(150, 165, 185)
LS_Phalanx.ForwardOffset = 26
LS_Phalanx.FrontArcDot = math.cos(math.rad(65))
LS_Phalanx.BlockMask = bit.bor(
    DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_SLASH, DMG_CLUB,
    DMG_CRUSH, DMG_BLAST, DMG_SHOCK, DMG_ENERGYBEAM, DMG_PLASMA
)

-- World position and angles for the plate in front of the NPC.
function LS_Phalanx.GetTransform(npc)

    local yaw = npc:GetAngles().y
    local base = Angle(0, yaw, 0)
    local height = math.max(40, npc:OBBMaxs().z)

    local position = npc:GetPos() +
        Vector(0, 0, height * 0.55) +
        base:Forward() * LS_Phalanx.ForwardOffset

    local angles = Angle(0, yaw, 0)
    angles:RotateAroundAxis(angles:Right(), 90)

    return position, angles

end

-- Is `position` inside the protected front arc of the NPC?
function LS_Phalanx.IsInFront(npc, position)

    local direction = position - npc:WorldSpaceCenter()
    direction.z = 0

    if direction:LengthSqr() < 1 then
        return true
    end

    direction:Normalize()

    return Angle(0, npc:GetAngles().y, 0):Forward():Dot(direction) >= LS_Phalanx.FrontArcDot

end

function ENT:Initialize()

    local model = LS_Phalanx.Model

    if not util.IsValidModel(model) then
        model = "models/props_junk/wood_crate001a.mdl"
    end

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    -- Does not block players or the world, but is still hit by bullets.
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetColor(LS_Phalanx.Color)

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
        -- Reuses the Shielded bar on the NPC health display.
        wearer:SetNW2Int("LS_ShieldMax", self:GetMaxDurability())
        wearer:SetNW2Int("LS_Shield", self:GetDurability())
    end

end

function ENT:PhysicsSimulate(physics, deltaTime)

    local wearer = self:GetWearer()

    if not IsValid(wearer) or wearer:Health() <= 0 then
        return
    end

    local position, angles = LS_Phalanx.GetTransform(wearer)
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

    if not IsValid(wearer) or wearer:Health() <= 0 then
        self:Remove()
        return
    end

    self:NextThink(CurTime() + 0.25)

    return true

end

function ENT:OnRemove()

    local wearer = self:GetWearer()

    if IsValid(wearer) and wearer.LS_PhalanxPlate == self then
        wearer.LS_PhalanxPlate = nil
        wearer:SetNW2Int("LS_Shield", 0)
        wearer:SetNW2Int("LS_ShieldMax", 0)
    end

end

-- Direct hits on the plate itself.
function ENT:OnTakeDamage(dmginfo)

    if self.Broken or dmginfo:GetAttacker() == self:GetWearer() then
        return
    end

    if bit.band(dmginfo:GetDamageType(), LS_Phalanx.BlockMask) == 0 then
        return
    end

    local bonus = LS_Talents.GetPlayerRoll(dmginfo:GetAttacker(), "armor_breaker", "ShieldBonus")
    local multiplier = 1 + (bonus or 0) / 100

    local amount = dmginfo:GetDamage() * multiplier
    local overflow = self:Absorb(amount, dmginfo:GetDamagePosition())

    LS_Combat.ShowDamageNumber(dmginfo:GetAttacker(), dmginfo:GetDamagePosition(), (amount - overflow) / multiplier, 5)

end

-- Takes `amount` damage and returns how much was NOT absorbed (overflow).
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
    local base = LS_Phalanx.Color

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

        self:Remove()

    end)

end

-- Shots or blasts from the front arc that did not hit the plate directly are
-- still absorbed by it, so the plate cannot be sidestepped by an off-angle hit.
hook.Add("EntityTakeDamage", "LS_PhalanxFrontAbsorb", function(target, dmginfo)

    if not IsValid(target) or not target:IsNPC() then
        return
    end

    local plate = target.LS_PhalanxPlate

    if not IsValid(plate) or plate.Broken or dmginfo:GetDamage() <= 0 then
        return
    end

    if bit.band(dmginfo:GetDamageType(), LS_Phalanx.BlockMask) == 0 then
        return
    end

    local attacker = dmginfo:GetAttacker()

    if not IsValid(attacker) or attacker == target then
        return
    end

    if not LS_Phalanx.IsInFront(target, attacker:WorldSpaceCenter()) then
        return
    end

    local bonus = LS_Talents.GetPlayerRoll(attacker, "armor_breaker", "ShieldBonus")
    local multiplier = 1 + (bonus or 0) / 100
    local before = dmginfo:GetDamage()
    local remaining = plate:Absorb(before * multiplier, plate:GetPos()) / multiplier

    LS_Combat.ShowDamageNumber(attacker, plate:GetPos(), before - remaining, 5)

    dmginfo:SetDamage(remaining)

    if remaining <= 0 then
        dmginfo:SetDamageForce(vector_origin)
        return true
    end

end)

-- Nobody should be able to drag a worn plate around.
hook.Add("PhysgunPickup", "LS_PhalanxNoPhysgun", function(_, entity)
    if IsValid(entity) and entity:GetClass() == "ls_phalanx_shield" then return false end
end)

hook.Add("GravGunPickupAllowed", "LS_PhalanxNoGrav", function(_, entity)
    if IsValid(entity) and entity:GetClass() == "ls_phalanx_shield" then return false end
end)
