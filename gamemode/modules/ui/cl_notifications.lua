LS_Notifications = LS_Notifications or {}
LS_Notifications.Entries = LS_Notifications.Entries or {}
LS_Notifications.DisplayDuration = 4

function LS_Notifications.AddLoot(summary)

    table.insert(LS_Notifications.Entries, 1, {
        Name = summary.Name or "Unknown Item",
        Rarity = summary.Rarity or "Common",
        Prefix = summary.Prefix or "",
        Stats = summary.Stats or {},
        Talents = summary.Talents or {},
        CreatedAt = CurTime()
    })

    surface.PlaySound("items/ammo_pickup.wav")

    local pickupCue = {
        Rare = "buttons/button17.wav",
        Epic = "buttons/button9.wav",
        Legendary = "buttons/combine_button_locked.wav"
    }
    if pickupCue[summary.Rarity] then surface.PlaySound(pickupCue[summary.Rarity]) end

    while #LS_Notifications.Entries > 4 do
        table.remove(LS_Notifications.Entries)
    end

end

net.Receive("LS_LootPickup", function()

    LS_Notifications.AddLoot(net.ReadTable())

end)

hook.Add("HUDPaint", "LS_LootNotifications", function()

    local now = CurTime()
    local startY = ScrH() * 0.32

    for index = #LS_Notifications.Entries, 1, -1 do
        local entry = LS_Notifications.Entries[index]

        if now >= entry.CreatedAt + LS_Notifications.DisplayDuration then
            table.remove(LS_Notifications.Entries, index)
        end
    end

    for index, entry in ipairs(LS_Notifications.Entries) do

        local remaining = entry.CreatedAt +
            LS_Notifications.DisplayDuration - now
        local alpha = math.Clamp(remaining, 0, 1) * 255
        local rarityColor = LS_Items.RarityColors[entry.Rarity] or color_white
        local width = 330
        local height = 58 + (#entry.Stats * 15)

        if #entry.Talents > 0 then
            height = height + 16
        end

        local x = ScrW() - width - 28
        local y = startY

        for previousIndex = 1, index - 1 do
            local previous = LS_Notifications.Entries[previousIndex]
            local previousHeight = 58 + (#previous.Stats * 15)

            if #previous.Talents > 0 then
                previousHeight = previousHeight + 16
            end

            y = y + previousHeight + 8
        end

        draw.RoundedBox(
            4,
            x,
            y,
            width,
            height,
            Color(18, 18, 22, math.floor(alpha * 0.9))
        )

        draw.RoundedBox(
            4,
            x,
            y,
            4,
            height,
            Color(rarityColor.r, rarityColor.g, rarityColor.b, alpha)
        )

        draw.SimpleText(
            "PICKED UP",
            "DermaDefaultBold",
            x + 14,
            y + 11,
            Color(190, 190, 195, alpha),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            entry.Name,
            "DermaDefaultBold",
            x + 14,
            y + 28,
            Color(rarityColor.r, rarityColor.g, rarityColor.b, alpha),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            "PREFIX: " .. entry.Prefix,
            "DermaDefault",
            x + 14,
            y + 45,
            Color(205, 205, 210, alpha),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        for statIndex, statText in ipairs(entry.Stats) do
            draw.SimpleText(
                statText,
                "DermaDefault",
                x + 14,
                y + 58 + (statIndex - 1) * 15,
                Color(225, 225, 225, alpha),
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end

        if #entry.Talents > 0 then
            draw.SimpleText(
                "TALENTS: " .. table.concat(entry.Talents, ", "),
                "DermaDefault",
                x + 14,
                y + 58 + (#entry.Stats * 15),
                Color(rarityColor.r, rarityColor.g, rarityColor.b, alpha),
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end

    end

end)
