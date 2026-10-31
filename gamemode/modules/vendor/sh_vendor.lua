LS_Vendor = LS_Vendor or {}

LS_Vendor.StockSize = 6
LS_Vendor.Prices = {Common = 25, Uncommon = 60, Rare = 150, Epic = 400, Legendary = 1000}
LS_Vendor.TalentPrice = 20
-- Legendary stock is possible but rare; most shelves are Uncommon/Rare.
LS_Vendor.RarityWeights = {Common = 10, Uncommon = 40, Rare = 35, Epic = 14, Legendary = 1}

function LS_Vendor.GetPrice(item)
    if not item then return 0 end
    return (LS_Vendor.Prices[item.rarity] or 25) + #(item.talents or {}) * LS_Vendor.TalentPrice
end

if SERVER then
    util.AddNetworkString("LS_OpenVendor")
    util.AddNetworkString("LS_VendorBuy")

    LS_Vendor.Stock = LS_Vendor.Stock or {}

    local lines = {
        greet = {"vo/npc/female01/hi01.wav", "vo/npc/female01/hi02.wav"},
        buy = {"vo/npc/female01/fantastic01.wav", "vo/npc/female01/fantastic02.wav", "vo/npc/female01/ok01.wav"},
        broke = {"vo/npc/female01/no01.wav", "vo/npc/female01/no02.wav"}
    }

    function LS_Vendor.Say(kind, vendor)
        vendor = IsValid(vendor) and vendor or ents.FindByClass("ls_vendor")[1]
        local set = lines[kind]
        if not IsValid(vendor) or not set then return end
        if vendor.LS_VoiceUntil and vendor.LS_VoiceUntil > CurTime() then return end
        vendor.LS_VoiceUntil = CurTime() + 1.5
        vendor:StopSound(vendor.LS_LastLine or "")
        vendor.LS_LastLine = set[math.random(#set)]
        vendor:EmitSound(vendor.LS_LastLine, 75, 100, 1, CHAN_VOICE)
    end

    function LS_Vendor.Restock()
        LS_Vendor.Stock = {}
        for index = 1, LS_Vendor.StockSize do
            local item = LS_Items.GenerateItem(LS_Vendor.RarityWeights)
            LS_Vendor.Stock[index] = {Item = item, Price = LS_Vendor.GetPrice(item), Sold = false}
        end
    end

    function LS_Vendor.Send(player, vendor, quiet)
        if #LS_Vendor.Stock == 0 then LS_Vendor.Restock() end
        net.Start("LS_OpenVendor")
            net.WriteEntity(vendor)
            net.WriteString(IsValid(vendor) and vendor:GetVendorName() or "Vendor")
            net.WriteBool(quiet and true or false)
            net.WriteTable(LS_Vendor.Stock)
        net.Send(player)
    end

    function LS_Vendor.Open(player, vendor)
        LS_Vendor.Send(player, vendor)
        LS_Vendor.Say("greet", vendor)
    end

    net.Receive("LS_VendorBuy", function(_, player)
        local index = net.ReadUInt(8)
        local entry = LS_Vendor.Stock[index]
        if not entry or entry.Sold then return end

        local nearest
        for _, vendor in ipairs(ents.FindByClass("ls_vendor")) do
            if vendor:GetPos():DistToSqr(player:GetPos()) <= 300 * 300 then nearest = vendor break end
        end
        if not nearest then return end

        if not LS_Currency.Spend(entry.Price) then
            LS_Vendor.Say("broke", nearest)
            return
        end

        entry.Sold = true
        local id = LS_Inventory.AddItem(table.Copy(entry.Item))
        LS_Networking.SendInventory(player)
        -- Spend() already changed the balance; this only drives the HUD toast.
        net.Start("LS_CurrencyGain")
            net.WriteInt(-entry.Price, 32)
            net.WriteString("Bought " .. entry.Item.weapon)
        net.Send(player)
        LS_Vendor.Say("buy", nearest)
        LS_Vendor.Send(player, nearest, true)
        print("[LS] Purchased item #" .. id .. " for " .. entry.Price .. " CR")
    end)

    concommand.Add("ls_restockvendor", function()
        LS_Vendor.Restock()
        print("[LS] Vendor restocked.")
    end)
end
