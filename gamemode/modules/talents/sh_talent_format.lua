-- Helpers for showing talents to the player: roll names, units, and text wrapping.

-- The unit shown after a rolled value. A talent can override a roll's unit with
-- the table below when the same roll name means something different.
LS_Talents.RollUnits = {
    Chance = "%", DamagePercent = "%", LifeSteal = "%", Slow = "%", FreezeChance = "%",
    Reflect = "%", Heal = "%", Refill = "%", Reduction = "%", Bonus = "%", MaxBonus = "%",
    PerStack = "%", FireRate = "%", Speed = "%", Threshold = "%", Penalty = "%",
    LosePenalty = "%", WinBonus = "%", WinChance = "%", ArmorPierce = "%", ShieldBonus = "%",
    Durability = "%",
    Duration = "s", Cooldown = "s", Stun = "s", Immunity = "s", Wait = "s", Seconds = "s",
    Radius = " units", Credits = " CR"
}

local overrides = {
    fortified = {Cooldown = "%"},
    tesla_coil = {Damage = "%"},
    rocket_pod = {Damage = "%"},
    cluster = {Damage = "%"}
}

function LS_Talents.RollLabel(name)
    return string.Trim(string.gsub(name, "(%u)", " %1"))
end

function LS_Talents.FormatRoll(talentID, rollName, value)

    local unit = (overrides[talentID] and overrides[talentID][rollName]) or LS_Talents.RollUnits[rollName] or ""

    return tostring(value) .. unit

end

if CLIENT then

    -- Splits text into lines that fit `width` pixels in `font`.
    function LS_Talents.WrapLines(text, font, width)

        surface.SetFont(font)

        local lines, current = {}, ""

        for word in string.gmatch(text or "", "%S+") do

            local attempt = current == "" and word or (current .. " " .. word)

            if surface.GetTextSize(attempt) > width and current ~= "" then
                table.insert(lines, current)
                current = word
            else
                current = attempt
            end

        end

        if current ~= "" then
            table.insert(lines, current)
        end

        return lines

    end

end
