LS_Status = {}

LS_Status.Registered = {}

LS_Status.Active = {}

function LS_Status.Register(data)

    data.OnApply = data.OnApply or nil
    data.OnTick = data.OnTick or nil
    data.OnExpire = data.OnExpire or nil

    LS_Status.Registered[data.ID] = data

end

function LS_Status.Get(id)

    return LS_Status.Registered[id]

end

function LS_Status.GetBucket(entity)

    if not IsValid(entity) then
        return nil
    end

    local index = entity:EntIndex()

    if not LS_Status.Active[index] then

        LS_Status.Active[index] = {

            Entity = entity,

            Statuses = {}

        }

    end

    return LS_Status.Active[index]

end

function LS_Status.GetActive(entity)

    if not IsValid(entity) then
        return {}
    end

    local bucket = LS_Status.Active[entity:EntIndex()]

    if not bucket then
        return {}
    end

    return bucket.Statuses

end

function LS_Status.GetActiveIDs(entity)

    if not IsValid(entity) then
        return {}
    end

    if CLIENT then

        local serializedIDs = entity:GetNW2String("LS_StatusIDs", "")

        if serializedIDs == "" then
            return {}
        end

        return string.Explode(",", serializedIDs)

    end

    local ids = {}

    for statusID in pairs(LS_Status.GetActive(entity)) do
        table.insert(ids, statusID)
    end

    table.sort(ids)

    return ids

end

function LS_Status.SyncActiveIDs(entity)

    if not SERVER or not IsValid(entity) then
        return
    end

    entity:SetNW2String(
        "LS_StatusIDs",
        table.concat(LS_Status.GetActiveIDs(entity), ",")
    )

end

function LS_Status.Apply(entity, statusID, duration, data)

    local bucket =
        LS_Status.GetBucket(entity)

    if not bucket then
        return
    end

    local definition =
        LS_Status.Get(statusID)

    if not definition then
        return
    end

    bucket.Statuses[statusID] = {

        EndTime = CurTime() + duration,

        LastTick = CurTime(),

        Data = data or {}

    }

    if definition.OnApply then

        definition.OnApply(

            entity,

            bucket.Statuses[statusID]

        )

    end

    LS_Status.SyncActiveIDs(entity)

end

function LS_Status.Remove(entity, statusID)

    local bucket =
        LS_Status.GetBucket(entity)

    if not bucket then
        return
    end

    local status =
        bucket.Statuses[statusID]

    if not status then
        return
    end

    local definition =
        LS_Status.Get(statusID)

    if definition and definition.OnExpire then

        definition.OnExpire(
            entity,
            status
        )

    end

    bucket.Statuses[statusID] = nil

    LS_Status.SyncActiveIDs(entity)

    if table.IsEmpty(bucket.Statuses) then

        LS_Status.Active[entity:EntIndex()] = nil

    end

end

hook.Add("Think", "LS_StatusThink", function()

    local now = CurTime()

    for index, bucket in pairs(LS_Status.Active) do

        local entity = bucket.Entity

        if not IsValid(entity) then

            LS_Status.Active[index] = nil
            continue

        end

        for statusID, status in pairs(bucket.Statuses) do

            local definition =
                LS_Status.Get(statusID)

            if definition and definition.OnTick then

                definition.OnTick(
                    entity,
                    status
                )

            end

            if now >= status.EndTime then

                LS_Status.Remove(
                    entity,
                    statusID
                )

            end

        end

    end

end)

-- Frost: slows an NPC by scaling its animation playback rate (which also
-- slows how fast it attacks), and tints it icy blue. It never deals damage.
-- Other systems that change playback rate (Frenzied, Hunter) store their rate in
-- npc.LS_BaseRate and call LS_NPCs.ApplySpeed, which multiplies in the frost factor.
LS_Status.Register({

    ID = "frost",

    OnApply = function(entity, status)

        if not SERVER or not IsValid(entity) or not entity:IsNPC() then
            return
        end

        local slow = math.Clamp(status.Data.Slow or 30, 0, 80)

        -- Bosses are only half as slowed.
        if entity.LS_Variant == "alpha" then
            slow = slow * 0.5
        end

        entity.LS_FrostFactor = 1 - slow / 100

        if not entity.LS_FrostBaseColor then
            entity.LS_FrostBaseColor = entity:GetColor()
        end

        local base = entity.LS_FrostBaseColor

        entity:SetColor(Color(
            Lerp(0.65, base.r, 150),
            Lerp(0.65, base.g, 205),
            Lerp(0.65, base.b, 255)
        ))

        entity:SetNW2Bool("LS_Frosted", true)

        if LS_NPCs and LS_NPCs.ApplySpeed then
            LS_NPCs.ApplySpeed(entity)
        end

    end,

    OnTick = function(entity, status)

        if not SERVER or not IsValid(entity) or not entity.LS_FrostFactor or entity:Health() <= 0 then
            return
        end

        -- Animations change often and reset the rate, so keep re-applying it.
        if CurTime() < (status.NextRate or 0) then
            return
        end

        status.NextRate = CurTime() + 0.15

        if LS_NPCs and LS_NPCs.ApplySpeed then
            LS_NPCs.ApplySpeed(entity)
        end

    end,

    OnExpire = function(entity, status)

        if not SERVER or not IsValid(entity) then
            return
        end

        entity.LS_FrostFactor = nil
        entity:SetNW2Bool("LS_Frosted", false)

        if entity.LS_FrostBaseColor then
            entity:SetColor(entity.LS_FrostBaseColor)
            entity.LS_FrostBaseColor = nil
        end

        if LS_NPCs and LS_NPCs.ApplySpeed then
            LS_NPCs.ApplySpeed(entity)
        end

    end

})
