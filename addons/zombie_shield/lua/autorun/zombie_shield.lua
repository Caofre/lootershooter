--[[
    ZOMBIE SHIELD (CoD Zombies style buildable)
    - Collect 3 parts, build them at a workbench (hold E), wear the shield on your back.
    - The shield is a real physics prop that follows the player (shadow-controlled).
    - Hits from behind land on the prop; it has durability and breaks when depleted.
]]

AddCSLuaFile()

ZS = ZS or {}

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------
ZS.ShieldModel = "models/hunter/plates/plate1x1.mdl" -- flat plate; thin axis is aligned to the player's back
ZS.ShieldColor = Color(120, 130, 140)

-- The 3 buildable parts (names + world models). Swap models freely.
ZS.Parts = {
    { name = "Door",  model = "models/props_vehicles/carparts_door01a.mdl" },
    { name = "Dolly", model = "models/props_vehicles/carparts_wheel01a.mdl" },
    { name = "Clamp", model = "models/props_c17/tools_wrench01a.mdl" },
}
ZS.AllPartsMask = bit.lshift(1, #ZS.Parts) - 1

local FL = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY)
ZS.CV = {
    health = CreateConVar("zs_shield_health",      "600", FL, "Total damage the shield absorbs before breaking"),
    craft  = CreateConVar("zs_shield_crafttime",   "3",   FL, "Seconds holding E at the workbench to build"),
    arc    = CreateConVar("zs_shield_arc",         "70",  FL, "Half-angle (deg) of the rear cone protected against melee/blast"),
    scale  = CreateConVar("zs_shield_damagescale", "1",   FL, "Multiplier on damage dealt to the shield"),
    back   = CreateConVar("zs_shield_back",        "14",  FL, "Units behind the player's centre"),
    up     = CreateConVar("zs_shield_up",          "40",  FL, "Height of the shield centre (standing)"),
    pitch  = CreateConVar("zs_shield_pitch",       "90",  FL, "Model rotation offset (tune if you change model)"),
    yaw    = CreateConVar("zs_shield_yaw",         "0",   FL, "Model rotation offset"),
    roll   = CreateConVar("zs_shield_roll",        "0",   FL, "Model rotation offset"),
}

ZS.BulletMask = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER)
ZS.BlockMask  = bit.bor(ZS.BulletMask, DMG_SLASH, DMG_CLUB, DMG_CRUSH, DMG_BLAST)

----------------------------------------------------------------------
-- SHARED HELPERS
----------------------------------------------------------------------
function ZS.HasPart(ply, id)
    return bit.band(ply:GetNWInt("ZS_Parts", 0), bit.lshift(1, id - 1)) ~= 0
end

function ZS.HasAllParts(ply)
    return ply:GetNWInt("ZS_Parts", 0) == ZS.AllPartsMask
end

-- Where the shield should sit for a given player (world pos + angles)
function ZS.GetShieldTransform(ply)
    local yaw    = ply:EyeAngles().y
    local base   = Angle(0, yaw, 0)
    local height = ply:OBBMaxs().z / 72 -- scales with crouching
    local pos    = ply:GetPos()
                 + Vector(0, 0, ZS.CV.up:GetFloat() * height)
                 - base:Forward() * ZS.CV.back:GetFloat()

    local ang = Angle(0, yaw + ZS.CV.yaw:GetFloat(), 0)
    ang:RotateAroundAxis(ang:Right(),   ZS.CV.pitch:GetFloat())
    ang:RotateAroundAxis(ang:Forward(), ZS.CV.roll:GetFloat())
    return pos, ang
end

-- Spawn menu entries (Entities tab > "Zombie Shield")
for id, part in ipairs(ZS.Parts) do
    list.Set("SpawnableEntities", "zs_part_" .. id, {
        PrintName  = "Shield Part: " .. part.name,
        ClassName  = "zs_part",
        Category   = "Zombie Shield",
        KeyValues  = { part = id },
    })
end

if CLIENT then return end

----------------------------------------------------------------------
-- SERVER
----------------------------------------------------------------------
function ZS.GetDamageScale()
    return math.max(ZS.CV.scale:GetFloat(), 0.01)
end

function ZS.GivePart(ply, id)
    ply:SetNWInt("ZS_Parts", bit.bor(ply:GetNWInt("ZS_Parts", 0), bit.lshift(1, id - 1)))
    ply:EmitSound("items/ammo_pickup.wav", 60)

    local count = 0
    for i = 1, #ZS.Parts do
        if ZS.HasPart(ply, i) then count = count + 1 end
    end
    if count == #ZS.Parts then
        ply:PrintMessage(HUD_PRINTCENTER, "All parts collected! Take them to a Shield Workbench.")
    else
        ply:PrintMessage(HUD_PRINTCENTER, "Picked up: " .. ZS.Parts[id].name .. " (" .. count .. "/" .. #ZS.Parts .. ")")
    end
end

function ZS.GiveShield(ply)
    if IsValid(ply.ZS_Shield) then ply.ZS_Shield:Remove() end

    local sh = ents.Create("zs_shield")
    if not IsValid(sh) then return end

    local pos, ang = ZS.GetShieldTransform(ply)
    sh:SetPos(pos)
    sh:SetAngles(ang)
    sh:SetWearer(ply)
    sh:Spawn()
    sh:Activate()

    ply.ZS_Shield = sh
    ply:SetNWEntity("ZS_Shield", sh)
    return sh
end

function ZS.RemoveShield(ply)
    if IsValid(ply.ZS_Shield) then ply.ZS_Shield:Remove() end
    ply.ZS_Shield = nil
    ply:SetNWEntity("ZS_Shield", NULL)
end

-- Is `pos` inside the protected rear cone of the player?
function ZS.IsBehind(ply, pos)
    local dir = pos - ply:WorldSpaceCenter()
    dir.z = 0
    if dir:LengthSqr() < 1 then return false end
    dir:Normalize()
    local fwd = Angle(0, ply:EyeAngles().y, 0):Forward()
    return fwd:Dot(dir) <= -math.cos(math.rad(ZS.CV.arc:GetFloat()))
end

-- Does the segment from->to pass through the shield's collision box?
function ZS.RayHitsShield(shield, from, to)
    local pad = Vector(4, 4, 4)
    return util.IntersectRayWithOBB(from, to - from, shield:GetPos(), shield:GetAngles(),
        shield:OBBMins() - pad, shield:OBBMaxs() + pad)
end

-- Move damage from a DamageInfo onto the shield. Returns true if fully absorbed.
-- Any overflow (shield broke mid-hit) is left on the DamageInfo for the player.
function ZS.Absorb(shield, dmg, pos)
    local scale = ZS.GetDamageScale()
    local left  = shield:Absorb(dmg:GetDamage() * scale, pos) / scale
    dmg:SetDamage(left)
    if left <= 0 then
        dmg:SetDamageForce(vector_origin)
        return true
    end
    return false
end

----------------------------------------------------------------------
-- DAMAGE HOOKS
----------------------------------------------------------------------

-- 1) Hitscan: evaluated per pellet. If a bullet that would hit the player passed
--    through the shield on its way, the shield eats the damage instead.
--    (Normally the prop's own collision catches the bullet first; this is the safety net.)
hook.Add("EntityFireBullets", "ZS_ShieldBullets", function(attacker, data)
    local old = data.Callback
    data.Callback = function(att, tr, dmg)
        local ret
        if old then ret = old(att, tr, dmg) end

        local victim = tr.Entity
        if IsValid(victim) and victim:IsPlayer() then
            victim.ZS_BulletTick = engine.TickCount()
            local sh = victim.ZS_Shield
            if IsValid(sh) and not sh.ZS_Broken then
                local hit = ZS.RayHitsShield(sh, tr.StartPos, tr.HitPos)
                if hit then ZS.Absorb(sh, dmg, hit) end
            end
        end
        return ret
    end
    return true
end)

-- 2) Everything else (NPC claws, melee, props, explosions, non-Lua bullets):
--    if the source is in the rear cone, the shield takes the hit.
hook.Add("EntityTakeDamage", "ZS_ShieldMelee", function(target, dmg)
    if not target:IsPlayer() then return end

    local sh = target.ZS_Shield
    if not IsValid(sh) or sh.ZS_Broken then return end
    if dmg:GetDamage() <= 0 then return end

    local dtype = dmg:GetDamageType()
    if bit.band(dtype, ZS.BlockMask) == 0 then return end

    local att = dmg:GetAttacker()
    if not IsValid(att) or att == target then return end

    -- bullets already got the precise per-pellet check above
    if bit.band(dtype, ZS.BulletMask) ~= 0 and target.ZS_BulletTick == engine.TickCount() then return end

    local inf = dmg:GetInflictor()
    local src = (IsValid(inf) and not inf:IsWeapon()) and inf or att
    if not ZS.IsBehind(target, src:WorldSpaceCenter()) then return end

    if ZS.Absorb(sh, dmg, sh:GetPos()) then return true end
end)

----------------------------------------------------------------------
-- LIFECYCLE
----------------------------------------------------------------------
hook.Add("PlayerDeath", "ZS_LoseOnDeath", function(ply)
    ZS.RemoveShield(ply)
    ply:SetNWInt("ZS_Parts", 0)
    ply:SetNWFloat("ZS_Craft", 0)
end)

hook.Add("PlayerDisconnected", "ZS_Cleanup", function(ply)
    ZS.RemoveShield(ply)
end)

-- reset crafting progress when the player lets go of E
hook.Add("Think", "ZS_CraftReset", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if ply.ZS_CraftStart and now - (ply.ZS_LastUse or 0) > 0.3 then
            ply.ZS_CraftStart = nil
            ply:SetNWFloat("ZS_Craft", 0)
        end
    end
end)

-- nobody should be able to yank the worn shield around
hook.Add("PhysgunPickup",          "ZS_NoPhysgun", function(_, ent) if ent:GetClass() == "zs_shield" then return false end end)
hook.Add("GravGunPickupAllowed",   "ZS_NoGrav",    function(_, ent) if IsValid(ent) and ent:GetClass() == "zs_shield" then return false end end)
hook.Add("GravGunPunt",            "ZS_NoPunt",    function(_, ent) if IsValid(ent) and ent:GetClass() == "zs_shield" then return false end end)

----------------------------------------------------------------------
-- ADMIN / TESTING COMMANDS
----------------------------------------------------------------------
concommand.Add("zs_giveshield", function(ply)
    if IsValid(ply) and ply:IsAdmin() then ZS.GiveShield(ply) end
end)

concommand.Add("zs_giveparts", function(ply)
    if IsValid(ply) and ply:IsAdmin() then ply:SetNWInt("ZS_Parts", ZS.AllPartsMask) end
end)

concommand.Add("zs_removeshield", function(ply)
    if IsValid(ply) and ply:IsAdmin() then ZS.RemoveShield(ply) end
end)
