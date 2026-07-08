LS_PlayerStats = {}

LS_PlayerStats.Current = {
    Damage = 0,
    ["Fire Rate"] = 0,
    ["Reload Speed"] = 0,
    ["Magazine Size"] = 0
}

function LS_PlayerStats.Rebuild()

    local stats = {
        Damage = 0,
        ["Fire Rate"] = 0,
        ["Reload Speed"] = 0,
        ["Magazine Size"] = 0
    }

    for _, itemID in pairs(LS_Equipment.Slots) do

        if itemID then

            local item =
                LS_Inventory.GetItemByID(itemID)

            if item then

                for stat, value in pairs(item.stats) do

                    stats[stat] =
                        stats[stat] + value

                end

            end

        end

    end

    LS_PlayerStats.Current = stats

end

