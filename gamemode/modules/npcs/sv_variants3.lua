-- Batch 3 variants: Blinker, Charger, Suppressor, Phalanx.
-- Uses the behavior framework from sv_variants.lua.

if not SERVER then
    return
end

local nearestPlayer = LS_NPCs.NearestPlayer

local function effectAt(name, position)

    local effect = EffectData()
    effect:SetOrigin(position)
    util.Effect(name, effect)

end

----------------------------------------------------------------------
-- Blinker: teleports a short way when hit, and blinks closer when it is
-- far from the player.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "blinker",
    LootChanceMultiplier = 1.4,
    Name = "Blinker",
    Badge = "BLINKER  ◆",
    Color = Color(100, 130, 255),

    XPMultiplier = 1.3,

    SpawnWave = 4,
    SpawnMax = 5,
    MaxBaseHealth = 400

})

local BLINK_COOLDOWN = 3.5

-- Grounded, hull-clear position around `center` at a distance in [minimum, maximum].
local function findBlinkPosition(npc, center, minimum, maximum)

    local mins, maxs = npc:OBBMins(), npc:OBBMaxs()

    for _ = 1, 14 do

        local direction = Angle(0, math.Rand(0, 360), 0):Forward()
        local candidate = center + direction * math.Rand(minimum, maximum)

        local ground = util.TraceLine({
            start = candidate + Vector(0, 0, 96),
            endpos = candidate - Vector(0, 0, 300),
            mask = MASK_SOLID_BRUSHONLY
        })

        if ground.Hit and not ground.StartSolid and ground.HitNormal.z > 0.7 and
            bit.band(util.PointContents(ground.HitPos + Vector(0, 0, 8)), CONTENTS_WATER) == 0 then

            local position = ground.HitPos + Vector(0, 0, 4)
            local hull = util.TraceHull({
                start = position,
                endpos = position,
                mins = mins,
                maxs = maxs,
                mask = MASK_NPCSOLID,
                filter = npc
            })

            if not hull.Hit then
                return position
            end
        end

    end

end

local function blink(npc, position)

    effectAt("ManhackSparks", npc:WorldSpaceCenter())
    npc:EmitSound("ambient/energy/zap" .. math.random(5, 9) .. ".wav", 70, 140)

    npc:SetPos(position)

    effectAt("ManhackSparks", position + Vector(0, 0, 36))

end

LS_NPCs.RegisterBehavior("blinker", {

    OnSpawn = function(npc)
        npc.LS_NextBlink = CurTime() + 2
    end,

    OnDamaged = function(npc, dmginfo)

        if CurTime() < npc.LS_NextBlink or dmginfo:GetDamage() <= 0 then
            return
        end

        npc.LS_NextBlink = CurTime() + BLINK_COOLDOWN

        -- Deferred out of the damage callback; also skipped if it just died.
        timer.Simple(0, function()

            if not IsValid(npc) or npc:Health() <= 0 then
                return
            end

            local position = findBlinkPosition(npc, npc:GetPos(), 180, 320)

            if position then
                blink(npc, position)
            end

        end)

    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextBlink then
            return
        end

        local player, distance = nearestPlayer(npc)

        if not IsValid(player) or distance < 800 or distance > 2500 then
            return
        end

        local position = findBlinkPosition(npc, player:GetPos(), 350, 500)

        npc.LS_NextBlink = now + BLINK_COOLDOWN

        if position then
            blink(npc, position)
        end

    end

})

----------------------------------------------------------------------
-- Charger: winds up with a red glow, then launches itself at the player.
-- It damages and knocks back whoever it connects with.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "charger",
    LootChanceMultiplier = 1.3,
    Name = "Charger",
    Badge = "CHARGER  ◆",
    Color = Color(190, 120, 60),

    HealthMultiplier = 1.15,
    XPMultiplier = 1.3,

    SpawnWave = 3,
    SpawnMax = 6,
    MaxBaseHealth = 400

})

local CHARGE_WINDUP = 1.0
local CHARGE_SPEED = 1100
local CHARGE_AIR_TIME = 0.8

LS_NPCs.Charging = LS_NPCs.Charging or {}

LS_NPCs.RegisterBehavior("charger", {

    OnSpawn = function(npc)
        npc.LS_ChargeState = "idle"
        npc.LS_NextCharge = CurTime() + math.Rand(3, 6)
        npc.LS_BaseColor = npc:GetColor()
    end,

    OnThink = function(npc, now)

        if npc.LS_ChargeState == "idle" then

            if now < npc.LS_NextCharge then
                return
            end

            local player, distance = nearestPlayer(npc)

            if not IsValid(player) or distance < 300 or distance > 900 or not npc:Visible(player) then
                return
            end

            npc.LS_ChargeState = "windup"
            npc.LS_WindupEnds = now + CHARGE_WINDUP
            npc.LS_Frozen = true
            npc:SetSchedule(SCHED_NPC_FREEZE)
            npc:SetColor(Color(255, 60, 40))
            npc:EmitSound("npc/zombie/zombie_alert" .. math.random(1, 3) .. ".wav", 80, 70)

        elseif npc.LS_ChargeState == "windup" then

            local player = nearestPlayer(npc)

            if IsValid(player) then
                local face = (player:GetPos() - npc:GetPos()):Angle()
                npc:SetAngles(Angle(0, face.y, 0))
            end

            if now < npc.LS_WindupEnds then
                return
            end

            npc:SetColor(npc.LS_BaseColor or color_white)

            if not IsValid(player) then
                npc.LS_ChargeState = "idle"
                npc.LS_NextCharge = now + 6
                return
            end

            local direction = player:GetPos() - npc:GetPos()
            direction.z = 0
            direction:Normalize()

            npc.LS_Frozen = nil
            npc:SetCondition(COND.NPC_UNFREEZE)
            npc:SetSchedule(SCHED_CHASE_ENEMY)
            npc:SetGroundEntity(NULL)
            npc:SetVelocity(direction * CHARGE_SPEED + Vector(0, 0, 160))

            npc.LS_ChargeState = "charging"
            npc.LS_ChargeEnds = now + CHARGE_AIR_TIME
            npc.LS_ChargeDirection = direction
            npc.LS_ChargeHit = false

            table.insert(LS_NPCs.Charging, npc)

        end

    end

})

-- Hit detection runs every tick while a charge is in the air.
hook.Add("Think", "LS_ChargerImpact", function()

    for index = #LS_NPCs.Charging, 1, -1 do

        local npc = LS_NPCs.Charging[index]

        if not IsValid(npc) or npc:Health() <= 0 or npc.LS_ChargeState ~= "charging" then
            table.remove(LS_NPCs.Charging, index)
        elseif CurTime() >= npc.LS_ChargeEnds or npc.LS_ChargeHit then
            npc.LS_ChargeState = "idle"
            npc.LS_NextCharge = CurTime() + math.Rand(8, 12)
            table.remove(LS_NPCs.Charging, index)
        else

            for _, player in ipairs(player.GetAll()) do

                if IsValid(player) and player:Alive() and
                    player:GetPos():Distance(npc:GetPos()) < 75 then

                    local damage = DamageInfo()
                    damage:SetDamage(10 + (npc.LS_Level or 1) * 4)
                    damage:SetDamageType(DMG_CLUB)
                    damage:SetAttacker(npc)
                    damage:SetInflictor(npc)
                    player:TakeDamageInfo(damage)

                    player:SetVelocity(npc.LS_ChargeDirection * 380 + Vector(0, 0, 200))
                    player:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 80)
                    util.ScreenShake(player:GetPos(), 6, 8, 0.5, 100)

                    npc.LS_ChargeHit = true
                    break

                end

            end

        end

    end

end)

----------------------------------------------------------------------
-- Suppressor (armed enemies only): lays down a stream of inaccurate fire
-- around the player on top of its normal shooting.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "suppressor",
    LootChanceMultiplier = 1.3,
    Name = "Suppressor",
    Badge = "SUPPRESSOR  ◆",
    Color = Color(170, 150, 70),

    XPMultiplier = 1.3,

    SpawnWave = 3,
    SpawnMax = 5,
    RequiresEquipment = true

})

LS_NPCs.RegisterBehavior("suppressor", {

    OnSpawn = function(npc)
        npc.LS_NextSuppress = 0
        npc.LS_NextSuppressSound = 0
    end,

    OnThink = function(npc, now)

        if now < npc.LS_NextSuppress or not IsValid(npc:GetActiveWeapon()) then
            return
        end

        local player, distance = nearestPlayer(npc)

        if not IsValid(player) or distance > 1300 or not npc:Visible(player) then
            return
        end

        npc.LS_NextSuppress = now + 0.2

        local source = npc:GetShootPos()
        local target = player:WorldSpaceCenter() + VectorRand() * 90

        for _ = 1, 2 do
            npc:FireBullets({
                Attacker = npc,
                Damage = 1 + (npc.LS_Level or 1),
                Num = 1,
                Src = source,
                Dir = (target + VectorRand() * 40 - source):GetNormalized(),
                Spread = Vector(0.04, 0.04, 0),
                Tracer = 1,
                TracerName = "Tracer"
            })
        end

        if now >= npc.LS_NextSuppressSound then
            npc.LS_NextSuppressSound = now + 0.4
            npc:EmitSound("Weapon_SMG1.Single", 75, 100, 0.7)
        end

    end

})

----------------------------------------------------------------------
-- Phalanx (Zombies and Zombines): carries a shield plate in front. Shots
-- from the front arc are absorbed until the plate breaks; flank it.
----------------------------------------------------------------------

LS_NPCs.RegisterVariant({

    ID = "phalanx",
    LootChanceMultiplier = 1.6,
    Name = "Phalanx",
    Badge = "PHALANX  ◆",
    Color = Color(150, 165, 185),

    XPMultiplier = 1.5,

    SpawnWave = 3,
    SpawnMax = 6,
    AllowedNPCs = {"zombie", "zombine"},

    -- The plate's durability, as a fraction of the NPC's health.
    PlateFraction = 0.9

})

LS_NPCs.RegisterBehavior("phalanx", {

    OnSpawn = function(npc, variant)

        local plate = ents.Create("ls_phalanx_shield")

        if not IsValid(plate) then
            return
        end

        local position, angles = LS_Phalanx.GetTransform(npc)

        plate:SetPos(position)
        plate:SetAngles(angles)
        plate:SetWearer(npc)
        plate:Spawn()
        plate:Activate()
        plate:SetDurabilityPool(math.max(1, math.floor((npc.LS_MaxHealth or 100) * (variant.PlateFraction or 0.9))))

        npc.LS_PhalanxPlate = plate
        plate.LS_SummonedBy = npc.LS_SummonedBy

    end,

    OnKilled = function(npc)

        if IsValid(npc.LS_PhalanxPlate) then
            npc.LS_PhalanxPlate:Remove()
        end

    end

})
