-- Lets hub NPCs (Broker, Vendor) idle and stroll around their anchor point.
-- Movement is straight-line (no navmesh needed): a destination is only chosen
-- if a hull trace to it is clear, and a stuck check ends the walk early.
LS_HubWander = LS_HubWander or {}

if SERVER then
    local TALK_DISTANCE = 170

    function LS_HubWander.Setup(ent, radius)
        ent.LS_Home = ent:GetPos()
        ent.LS_HomeAngles = ent:GetAngles()
        ent.LS_WanderRadius = radius or 180

        ent:SetCollisionBounds(Vector(-13, -13, 0), Vector(13, 13, 72))
        ent:SetHealth(1000000)
        ent:SetMaxHealth(1000000)
        ent.loco:SetStepHeight(18)
        ent.loco:SetMaxYawRate(360)
        ent.loco:SetAcceleration(300)
        ent.loco:SetDeceleration(900)
    end

    local function nearbyPlayer(ent)
        for _, player in ipairs(player.GetAll()) do
            if IsValid(player) and player:Alive() and
                player:GetPos():DistToSqr(ent:GetPos()) < TALK_DISTANCE * TALK_DISTANCE then
                return player
            end
        end
    end

    local function setActivity(ent, activity)
        if ent.LS_Activity ~= activity then
            ent.LS_Activity = activity
            ent:StartActivity(activity)
        end
    end

    local function pickDestination(ent)
        for _ = 1, 12 do
            local direction = Angle(0, math.Rand(0, 360), 0):Forward()
            local candidate = ent.LS_Home + direction * math.Rand(60, ent.LS_WanderRadius)
            local ground = util.TraceLine({
                start = candidate + Vector(0, 0, 48),
                endpos = candidate - Vector(0, 0, 96),
                mask = MASK_PLAYERSOLID,
                filter = ent
            })

            if ground.Hit and not ground.StartSolid and ground.HitNormal.z > 0.9 and
                math.abs(ground.HitPos.z - ent.LS_Home.z) <= 24 then
                local path = util.TraceHull({
                    start = ent:GetPos() + Vector(0, 0, 20),
                    endpos = ground.HitPos + Vector(0, 0, 20),
                    mins = Vector(-14, -14, 0),
                    maxs = Vector(14, 14, 50),
                    mask = MASK_PLAYERSOLID,
                    filter = ent
                })
                if path.Fraction >= 1 and not path.StartSolid then
                    return ground.HitPos
                end
            end
        end
    end

    local function walkTo(ent, destination)
        setActivity(ent, ACT_WALK)
        ent.loco:SetDesiredSpeed(65)

        local nextCheck, lastPosition = CurTime() + 0.7, ent:GetPos()
        local deadline = CurTime() + 12

        while IsValid(ent) and CurTime() < deadline do
            if nearbyPlayer(ent) then return end

            local here = ent:GetPos()
            if here:Distance2D(destination) < 20 then return end

            ent.loco:FaceTowards(destination)
            ent.loco:Approach(destination, 1)

            if CurTime() > nextCheck then
                if here:Distance2D(lastPosition) < 6 then return end
                lastPosition, nextCheck = here, CurTime() + 0.7
            end

            coroutine.yield()
        end
    end

    function LS_HubWander.Behave(ent)
        while true do
            -- Safety net: if the NPC was shoved or fell, put it back home.
            if ent:GetPos():Distance(ent.LS_Home) > ent.LS_WanderRadius * 3 or
                ent:GetPos().z < ent.LS_Home.z - 150 then
                ent:SetPos(ent.LS_Home)
                ent:SetAngles(ent.LS_HomeAngles)
            end

            local player = nearbyPlayer(ent)

            if player then
                setActivity(ent, ACT_IDLE)
                -- FaceTowards only turns for the tick it is called, so keep
                -- calling it every tick instead of once per wait.
                local untilTime = CurTime() + 0.2
                while IsValid(ent) and CurTime() < untilTime do
                    ent.loco:FaceTowards(player:GetPos())
                    coroutine.yield()
                end
            else
                setActivity(ent, ACT_IDLE)

                local until_ = CurTime() + math.Rand(5, 11)
                while IsValid(ent) and CurTime() < until_ and not nearbyPlayer(ent) do
                    coroutine.wait(0.25)
                end

                if not nearbyPlayer(ent) then
                    local destination = pickDestination(ent)
                    if destination then walkTo(ent, destination) end
                end
            end
        end
    end
end
