LS_Currency = LS_Currency or {}

-- Credits (CR) are the single soft currency: earned from contracts and by
-- dismantling gear, spent at vendors. The balance lives in a networked global
-- so the HUD and menus can read it without extra net traffic.
LS_Currency.Name = "Credits"
LS_Currency.Short = "CR"

LS_Currency.DismantleValues = {
    Common = 2,
    Uncommon = 6,
    Rare = 15,
    Epic = 40,
    Legendary = 100
}
LS_Currency.TalentBonus = 2

function LS_Currency.GetDismantleValue(item)
    if not item then return 0 end
    local base = LS_Currency.DismantleValues[item.rarity] or 1
    return base + #(item.talents or {}) * LS_Currency.TalentBonus
end

function LS_Currency.Get()
    return GetGlobalInt("LS_Credits", 0)
end

if SERVER then
    util.AddNetworkString("LS_CurrencyGain")

    function LS_Currency.Set(amount)
        SetGlobalInt("LS_Credits", math.max(0, math.floor(amount or 0)))
        if LS_Save and LS_Save.MarkDirty then LS_Save.MarkDirty() end
    end

    function LS_Currency.Add(player, amount, reason)
        amount = math.floor(amount or 0)
        if amount == 0 then return end
        LS_Currency.Set(LS_Currency.Get() + amount)
        if IsValid(player) then
            net.Start("LS_CurrencyGain")
                net.WriteInt(amount, 32)
                net.WriteString(reason or "")
            net.Send(player)
        end
    end

    function LS_Currency.CanAfford(amount)
        return LS_Currency.Get() >= amount
    end

    function LS_Currency.Spend(amount)
        amount = math.floor(amount or 0)
        if amount < 0 or not LS_Currency.CanAfford(amount) then return false end
        LS_Currency.Set(LS_Currency.Get() - amount)
        return true
    end

    concommand.Add("ls_credits", function()
        print("[LS] Credits: " .. LS_Currency.Get())
    end)

    -- Testing aid: ls_givecredits <amount>
    concommand.Add("ls_givecredits", function(player, _, args)
        local amount = tonumber(args[1])
        if not amount then print("Usage: ls_givecredits <amount>") return end
        LS_Currency.Add(player, amount, "Debug grant")
    end)
end
