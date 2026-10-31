LS_Combat = {}
LS_Combat.TalentTriggerSuppression = 0
LS_Combat.FollowUpContext = nil

function LS_Combat.SuppressTalentTriggers(callback)

    LS_Combat.TalentTriggerSuppression =
        LS_Combat.TalentTriggerSuppression + 1

    callback()

    LS_Combat.TalentTriggerSuppression = math.max(
        0,
        LS_Combat.TalentTriggerSuppression - 1
    )

end

function LS_Combat.BuildContext(attacker, target, weapon, item)

    return {

		Attacker = attacker,

		Target = target,

		Weapon = weapon,

		Item = item,

		Damage = 0

}

end

hook.Add(
    "EntityTakeDamage",
    "LS_Combat_OnHit",
    function(target, dmginfo)
	
	if LS_Combat.TalentTriggerSuppression > 0 then
		return
	end

        local attacker = dmginfo:GetAttacker()

        if not IsValid(attacker) then
            return
        end

        if not attacker:IsPlayer() then
            return
        end
		
		if not (target:IsNPC() or target:IsPlayer()) then
			return
		end

        local weapon = attacker:GetActiveWeapon()

        if not IsValid(weapon) then
            return
        end

        -- FireBullets applies shotgun pellets individually. Let every pellet
        -- damage the target, but do not let a single blast roll on-hit talents
        -- repeatedly against the same entity.
        if weapon.LS_PelletHitTargets and
            weapon.LS_PelletHitTargets[target:EntIndex()] then
            return
        end

        if weapon.LS_PelletHitTargets then
            weapon.LS_PelletHitTargets[target:EntIndex()] = true
        end

        local item =
            LS_Equipment.GetEquippedWeaponItem(attacker)

        if not item then
            return
        end

        local context =
            LS_Combat.BuildContext(
                attacker,
                target,
                weapon,
                item
            )
			context.Damage = dmginfo:GetDamage()
			context.DamageInfo = dmginfo

			-- weapon_ls_base records the last bullet's hit group just before
			-- its damage is applied, which is what Headhunter reads.
			if weapon.LS_LastHitEntity == target then
				context.HitGroup = weapon.LS_LastHitGroup
				context.Headshot = weapon.LS_LastHitGroup == HITGROUP_HEAD
				context.HitDirection = weapon.LS_LastShotDir
			end

        local followUp = LS_Combat.FollowUpContext

        LS_Talents.Trigger(
            "OnHit",
            context,
            item,
            followUp and followUp.ExcludedTalents
        )

    end
)

function LS_Combat.FindNearbyTargets(originTarget, radius, maxTargets)

    local targets = {}

    for _, ent in ipairs(ents.FindInSphere(originTarget:GetPos(), radius)) do

        if ent == originTarget then
            continue
        end

        if not ent:IsNPC() then
			continue
		end

        table.insert(targets, ent)

    end

    table.sort(targets, function(a, b)

        return
            a:GetPos():DistToSqr(originTarget:GetPos()) <
            b:GetPos():DistToSqr(originTarget:GetPos())

    end)

    if maxTargets and #targets > maxTargets then

        while #targets > maxTargets do
            table.remove(targets)
        end

    end

    return targets

end

	function LS_Combat.FindNearestTarget(originTarget, radius)

		local targets =
			LS_Combat.FindNearbyTargets(
				originTarget,
				radius,
				1
			)

		if #targets == 0 then
			return nil
		end

		return targets[1]

	end
	
function LS_Combat.DealTalentDamage(
    context,
    target,
    damage,
    damageType,
    options
)

    if not IsValid(target) then
        return
    end

    local dmg = DamageInfo()

    dmg:SetDamage(damage)
    dmg:SetAttacker(context.Attacker)
    dmg:SetInflictor(context.Weapon)
    dmg:SetDamageType(damageType or DMG_GENERIC)

    options = options or {}

    if options.AllowTalentTriggers then

        local previousContext = LS_Combat.FollowUpContext
        LS_Combat.FollowUpContext = {
            ExcludedTalents = options.ExcludedTalents
        }

        target:TakeDamageInfo(dmg)

        LS_Combat.FollowUpContext = previousContext

    else

        LS_Combat.SuppressTalentTriggers(function()
            target:TakeDamageInfo(dmg)
        end)

    end

end

function LS_Combat.CreateExplosion(context, position, damage, radius)

    LS_Combat.SuppressTalentTriggers(function()
        util.BlastDamage(
            context.Weapon,
            context.Attacker,
            position,
            radius,
            damage
        )
    end)

    local effect = EffectData()
    effect:SetOrigin(position)
    effect:SetStart(position)
    effect:SetScale(math.max(1, radius / 100))
    util.Effect("Explosion", effect, true, true)

    sound.Play("BaseExplosionEffect.Sound", position, 75, 100)

end

function LS_Combat.HealPlayer(player, amount)

    if not IsValid(player) then
        return
    end

    if not player:IsPlayer() then
        return
    end

    local maxHealth = player:GetMaxHealth()

    player:SetHealth(
        math.min(
            player:Health() + amount,
            maxHealth
        )
    )

end
