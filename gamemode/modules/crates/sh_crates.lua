-- Loot crates: a credit sink. Buy a crate from the Quartermaster, watch it open,
-- and get one random item (weapon, gadget or armor) added to your inventory.
-- Each crate type has its own odds and a "pity" guarantee: every N openings
-- without reaching a rarity, the next crate is guaranteed to.

LS_Crates = LS_Crates or {}
LS_Crates.Registered = LS_Crates.Registered or {}
LS_Crates.Order = LS_Crates.Order or {}

-- Openings since each crate type last paid out its pity rarity (saved with the inventory).
LS_Crates.Pity = LS_Crates.Pity or {}

function LS_Crates.Register(definition)

    LS_Crates.Registered[definition.ID] = definition

    if not table.HasValue(LS_Crates.Order, definition.ID) then
        table.insert(LS_Crates.Order, definition.ID)
    end

end

function LS_Crates.Get(id)
    return LS_Crates.Registered[id]
end

-- Percent chance of each rarity, for display.
function LS_Crates.GetOdds(definition)

    local total = 0

    for _, rarity in ipairs(LS_Items.Rarities) do
        total = total + (definition.Weights[rarity] or 0)
    end

    local odds = {}

    for _, rarity in ipairs(LS_Items.Rarities) do
        odds[rarity] = total > 0 and (definition.Weights[rarity] or 0) / total * 100 or 0
    end

    return odds

end

local function rarityRank(rarity)

    for index, name in ipairs(LS_Items.Rarities) do
        if name == rarity then
            return index
        end
    end

    return 0

end

LS_Crates.Register({

    ID = "supply",
    Name = "Supply Crate",
    Description = "Standard issue. Mostly everyday gear, with a shot at something better.",
    Price = 150,
    Color = Color(120, 190, 130),
    Weights = {Common = 30, Uncommon = 40, Rare = 20, Epic = 8, Legendary = 2},
    Pity = {Rarity = "Epic", Every = 12},
    GadgetChance = 12,
    ArmorChance = 12

})

LS_Crates.Register({

    ID = "military",
    Name = "Military Crate",
    Description = "Surplus from the front line. Rare or better most of the time.",
    Price = 450,
    Color = Color(110, 160, 235),
    Weights = {Common = 5, Uncommon = 30, Rare = 40, Epic = 20, Legendary = 5},
    Pity = {Rarity = "Epic", Every = 6},
    GadgetChance = 14,
    ArmorChance = 14

})

LS_Crates.Register({

    ID = "prototype",
    Name = "Prototype Crate",
    Description = "Experimental equipment. Always Rare or better, and a real chance at Legendary.",
    Price = 1200,
    Color = Color(255, 160, 60),
    Weights = {Rare = 30, Epic = 50, Legendary = 20},
    Pity = {Rarity = "Legendary", Every = 8},
    GadgetChance = 16,
    ArmorChance = 16

})

if CLIENT then
    return
end

----------------------------------------------------------------------
-- Server
----------------------------------------------------------------------

util.AddNetworkString("LS_CrateOpen")
util.AddNetworkString("LS_CrateResult")

-- The weights restricted to rarities at or above `minimum`.
local function weightsAtLeast(weights, minimum)

    local filtered = {}
    local floor = rarityRank(minimum)

    for _, rarity in ipairs(LS_Items.Rarities) do
        if rarityRank(rarity) >= floor then
            filtered[rarity] = weights[rarity] or 0
        end
    end

    local total = 0

    for _, value in pairs(filtered) do
        total = total + value
    end

    -- A crate with no weight at or above the pity rarity falls back to it exactly.
    if total <= 0 then
        filtered[minimum] = 1
    end

    return filtered

end

-- Rolls one item from a crate and updates its pity counter.
function LS_Crates.Roll(definition)

    local weights = definition.Weights
    local pity = LS_Crates.Pity[definition.ID] or 0
    local guaranteed = definition.Pity and pity + 1 >= definition.Pity.Every

    if guaranteed then
        weights = weightsAtLeast(weights, definition.Pity.Rarity)
    end

    local item = LS_Items.GenerateItem(weights, {
        GadgetChance = definition.GadgetChance,
        ArmorChance = definition.ArmorChance
    })

    if definition.Pity and rarityRank(item.rarity) >= rarityRank(definition.Pity.Rarity) then
        LS_Crates.Pity[definition.ID] = 0
    else
        LS_Crates.Pity[definition.ID] = pity + 1
    end

    return item

end

function LS_Crates.Open(player, crateID)

    local definition = LS_Crates.Get(crateID)

    if not definition or not IsValid(player) then
        return
    end

    -- One crate at a time, and only near the Quartermaster.
    if CurTime() < (player.LS_NextCrate or 0) then
        return
    end

    local nearest

    for _, vendor in ipairs(ents.FindByClass("ls_vendor")) do
        if vendor:GetPos():DistToSqr(player:GetPos()) <= 300 * 300 then
            nearest = vendor
            break
        end
    end

    if not nearest then
        return
    end

    if not LS_Currency.Spend(definition.Price) then
        if LS_Vendor then LS_Vendor.Say("broke", nearest) end
        return
    end

    player.LS_NextCrate = CurTime() + 1

    local item = LS_Crates.Roll(definition)

    LS_Inventory.AddItem(item)
    LS_Networking.SendInventory(player)

    net.Start("LS_CurrencyGain")
        net.WriteInt(-definition.Price, 32)
        net.WriteString("Opened " .. definition.Name)
    net.Send(player)

    net.Start("LS_CrateResult")
        net.WriteString(definition.ID)
        net.WriteTable(item)
    net.Send(player)

    if LS_Vendor then LS_Vendor.Say("buy", nearest) end

    print("[LS] Opened " .. definition.Name .. ": " .. item.rarity .. " " .. item.prefix .. " " .. item.weapon)

end

net.Receive("LS_CrateOpen", function(_, player)
    LS_Crates.Open(player, net.ReadString())
end)

concommand.Add("ls_crates", function()

    print("[LS] Crates:")

    for _, id in ipairs(LS_Crates.Order) do

        local definition = LS_Crates.Get(id)

        print(string.format("  %-10s %5d CR   pity %d/%d (%s+)", id, definition.Price,
            LS_Crates.Pity[id] or 0, definition.Pity and definition.Pity.Every or 0,
            definition.Pity and definition.Pity.Rarity or "-"))

    end

end)
