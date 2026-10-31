-- Damage numbers: tells the attacking player how much damage each hit did,
-- after every damage modifier has run (talents, armor, shields...).

if not SERVER then
    return
end

util.AddNetworkString("LS_DamageNumber")

-- Kinds: 0 normal, 1 fire, 2 shock, 3 blast, 4 damage over time, 5 shield absorbed
function LS_Combat.ShowDamageNumber(attacker, position, amount, kind, headshot, kill)

    amount = math.floor(amount or 0)

    if amount < 1 or not IsValid(attacker) or not attacker:IsPlayer() then
        return
    end

    net.Start("LS_DamageNumber")
        net.WriteVector(position)
        net.WriteUInt(math.min(amount, 65535), 16)
        net.WriteUInt(kind or 0, 3)
        net.WriteBool(headshot and true or false)
        net.WriteBool(kill and true or false)
    net.Send(attacker)

end

local function damageKind(damageType)

    if bit.band(damageType, DMG_BURN) ~= 0 then return 1 end
    if bit.band(damageType, DMG_SHOCK) ~= 0 then return 2 end
    if bit.band(damageType, DMG_BLAST) ~= 0 then return 3 end
    if damageType == DMG_GENERIC then return 4 end

    return 0

end

-- Shotgun pellets and multi-hit blasts land in the same tick, so they are
-- summed per target and shown as one number.
local pending = {}

local function flush(key)

    local entry = pending[key]
    pending[key] = nil

    if not entry then
        return
    end

    local target = entry.Target
    local kill = not IsValid(target) or target:Health() <= 0

    LS_Combat.ShowDamageNumber(entry.Attacker, entry.Position, entry.Amount, entry.Kind, entry.Headshot, kill)

end

hook.Add("PostEntityTakeDamage", "LS_DamageNumbers", function(target, dmginfo, took)

    if not took or not IsValid(target) or not target:IsNPC() then
        return
    end

    local attacker = dmginfo:GetAttacker()

    if not IsValid(attacker) or not attacker:IsPlayer() then
        return
    end

    local damage = dmginfo:GetDamage()

    if damage < 1 then
        return
    end

    local damageType = dmginfo:GetDamageType()
    local center = target:WorldSpaceCenter()
    local position = dmginfo:GetDamagePosition()

    if position == vector_origin or position:DistToSqr(center) > 150 * 150 then
        position = center
    end

    local weapon = attacker:GetActiveWeapon()
    local headshot = bit.band(damageType, DMG_BULLET) ~= 0 and IsValid(weapon) and
        weapon.LS_LastHitEntity == target and weapon.LS_LastHitGroup == HITGROUP_HEAD

    local key = target:EntIndex()
    local entry = pending[key]

    if not entry then
        entry = {
            Target = target,
            Attacker = attacker,
            Amount = 0,
            Kind = damageKind(damageType),
            Headshot = false,
            Position = position
        }

        pending[key] = entry

        timer.Simple(0, function() flush(key) end)
    end

    entry.Amount = entry.Amount + damage
    entry.Headshot = entry.Headshot or headshot

end)
