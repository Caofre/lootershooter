-- The Sentry Turret gadget: a temporary turret that turns toward and shoots the
-- nearest visible enemy, then retires after its lifetime runs out.

AddCSLuaFile()
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local MODELS = {
    "models/combine_turrets/floor_turret.mdl",
    "models/props_junk/PopCan01a.mdl"
}

local RANGE = 800
local FIRE_INTERVAL = 0.14
local MUZZLE_HEIGHT = 38

function ENT:Initialize()

    local model = MODELS[#MODELS]

    for _, candidate in ipairs(MODELS) do
        if util.IsValidModel(candidate) then
            model = candidate
            break
        end
    end

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    -- Does not block the player, but can still be walked around.
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetColor(Color(130, 205, 255))

    local physics = self:GetPhysicsObject()

    if IsValid(physics) then
        physics:EnableMotion(false)
    end

    self.Damage = self.Damage or 9
    self.DieAt = CurTime() + (self.Lifetime or 18)
    self.NextShot = 0
    self.NextRocket = CurTime() + 1.5
    self.NextPull = 0

    self:EmitSound("npc/turret_floor/deploy.wav", 75, 100)

end

local function findTarget(sentry, muzzle)

    local best, bestDistance

    for _, entity in ipairs(ents.FindInSphere(sentry:GetPos(), RANGE)) do

        if IsValid(entity) and entity:IsNPC() and entity:Health() > 0 and
            entity:GetNW2Bool("LS_IsFrameworkNPC", false) then

            local distance = entity:GetPos():DistToSqr(sentry:GetPos())

            if not bestDistance or distance < bestDistance then

                local trace = util.TraceLine({
                    start = muzzle,
                    endpos = entity:WorldSpaceCenter(),
                    mask = MASK_SHOT,
                    filter = {sentry, sentry:GetOwnerPlayer()}
                })

                if trace.Entity == entity or trace.Fraction > 0.97 then
                    best, bestDistance = entity, distance
                end

            end

        end

    end

    return best

end

function ENT:Think()

    local now = CurTime()

    if now >= self.DieAt then
        self:Retire()
        return
    end

    local muzzle = self:GetPos() + Vector(0, 0, MUZZLE_HEIGHT)
    local target = findTarget(self, muzzle)

    -- Decoy talent: draw nearby enemies toward the turret.
    if self.DecoyRadius and now >= self.NextPull then

        self.NextPull = now + 1

        for _, npc in ipairs(ents.FindInSphere(self:GetPos(), self.DecoyRadius)) do

            if IsValid(npc) and npc:IsNPC() and npc:Health() > 0 and
                npc:GetNW2Bool("LS_IsFrameworkNPC", false) and not npc.LS_Frozen and
                npc.LS_Variant ~= "looter" and
                npc:GetPos():DistToSqr(self:GetPos()) > 220 * 220 and
                math.random(100) <= (self.DecoyChance or 50) then

                npc:SetLastPosition(self:GetPos() + Vector(math.Rand(-80, 80), math.Rand(-80, 80), 0))
                npc:SetSchedule(SCHED_FORCED_GO_RUN)

            end

        end

    end

    if IsValid(target) then

        local direction = target:WorldSpaceCenter() - muzzle
        local wanted = Angle(0, direction:Angle().y, 0)

        self:SetAngles(LerpAngle(0.45, self:GetAngles(), wanted))

        if now >= self.NextShot then

            self.NextShot = now + FIRE_INTERVAL

            local owner = self:GetOwnerPlayer()

            -- The player's weapon talents must not trigger from sentry fire.
            LS_Combat.SuppressTalentTriggers(function()
                self:FireBullets({
                    Attacker = IsValid(owner) and owner or self,
                    Damage = self.Damage,
                    Num = 1,
                    Src = muzzle,
                    Dir = direction:GetNormalized(),
                    Spread = Vector(0.025, 0.025, 0),
                    Tracer = 1,
                    TracerName = "AR2Tracer",
                    IgnoreEntity = self,
                    Callback = function(_, trace, dmg)

                        if IsValid(owner) and trace.Entity == owner then
                            dmg:SetDamage(0)
                            return
                        end

                        -- Tesla Coil talent: shots can chain to nearby enemies.
                        if self.TeslaChance and IsValid(trace.Entity) and trace.Entity:IsNPC() and
                            math.random(100) <= self.TeslaChance then

                            for _, other in ipairs(LS_Combat.FindNearbyTargets(trace.Entity, 250, self.TeslaTargets or 1)) do
                                LS_Combat.DealTalentDamage(
                                    {Attacker = owner, Weapon = self},
                                    other,
                                    math.max(1, math.floor(self.Damage * (self.TeslaDamage or 40) / 100)),
                                    DMG_SHOCK
                                )

                                LS_Effects.TeslaBeam(trace.Entity:WorldSpaceCenter(), other:WorldSpaceCenter())
                            end

                        end

                    end
                })
            end)

            self:EmitSound("Weapon_SMG1.Single", 70, 115, 0.6)

        end

        -- Rocket Pod talent: an occasional explosive shot.
        if self.RocketDamage and now >= self.NextRocket then

            self.NextRocket = now + 3.2

            local aimPoint = target:WorldSpaceCenter()

            LS_Effects.TeslaBeam(muzzle, aimPoint)
            self:EmitSound("weapons/rpg/rocketfire1.wav", 70, 125, 0.7)

            timer.Simple(0.35, function()

                if not IsValid(self) then
                    return
                end

                local owner = self:GetOwnerPlayer()
                local position = IsValid(target) and target:WorldSpaceCenter() or aimPoint

                if IsValid(owner) then
                    owner.LS_GrenadeBlast = true
                    LS_Combat.CreateExplosion({Attacker = owner, Weapon = self}, position, self.RocketDamage, 130)
                    owner.LS_GrenadeBlast = nil
                end

            end)

        end

    end

    self:NextThink(CurTime() + 0.05)

    return true

end

function ENT:Retire()

    if self.Retiring then
        return
    end

    self.Retiring = true

    local effect = EffectData()
    effect:SetOrigin(self:WorldSpaceCenter())
    util.Effect("ManhackSparks", effect)

    self:EmitSound("npc/turret_floor/die.wav", 70, 100)
    self:Remove()

end
