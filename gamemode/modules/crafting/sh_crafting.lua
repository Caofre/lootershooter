-- Crafting: three components (Scrap, Parts, Cores) come from dismantling gear
-- and from contracts. At a Workbench you spend them, plus credits, to craft a
-- specific item at a rarity you choose. The base item and rarity are
-- guaranteed; the stat rolls and talents are still random.

LS_Components = LS_Components or {}

LS_Components.Order = {"scrap", "parts", "cores"}

LS_Components.Names = {scrap = "Scrap", parts = "Parts", cores = "Cores"}

LS_Components.Colors = {
    scrap = Color(185, 190, 200),
    parts = Color(90, 175, 255),
    cores = Color(255, 160, 60)
}

-- What dismantling an item of each rarity returns.
LS_Components.DismantleYield = {
    Common = {scrap = 3},
    Uncommon = {scrap = 6},
    Rare = {scrap = 4, parts = 3},
    Epic = {parts = 4, cores = 2},
    Legendary = {parts = 6, cores = 5}
}

-- Each talent on an item adds one of the rarity's main component.
local talentBonus = {Rare = "parts", Epic = "cores", Legendary = "cores"}

function LS_Components.GetYield(item)

    local yield = table.Copy(LS_Components.DismantleYield[item and item.rarity] or {})
    local bonus = talentBonus[item and item.rarity]

    if bonus then
        yield[bonus] = (yield[bonus] or 0) + #(item.talents or {})
    end

    return yield

end

function LS_Components.Get(id)
    return GetGlobalInt("LS_Comp_" .. id, 0)
end

-- A readable "4 Scrap, 3 Parts" for a cost or yield table.
function LS_Components.Describe(amounts)

    local parts = {}

    for _, id in ipairs(LS_Components.Order) do
        if (amounts[id] or 0) > 0 then
            table.insert(parts, amounts[id] .. " " .. LS_Components.Names[id])
        end
    end

    return table.concat(parts, ", ")

end

LS_Crafting = LS_Crafting or {}

-- Cost to craft one item of each rarity.
LS_Crafting.Costs = {
    Common = {Credits = 20, scrap = 10},
    Uncommon = {Credits = 60, scrap = 25},
    Rare = {Credits = 200, scrap = 30, parts = 12},
    Epic = {Credits = 600, parts = 24, cores = 8},
    Legendary = {Credits = 1600, parts = 30, cores = 20}
}

----------------------------------------------------------------------
-- Reforging
----------------------------------------------------------------------

-- Base cost of a reforge, by the item's rarity. Each action scales it.
LS_Crafting.ReforgeBase = {
    Common = {Credits = 10, scrap = 4},
    Uncommon = {Credits = 25, scrap = 10},
    Rare = {Credits = 80, scrap = 12, parts = 5},
    Epic = {Credits = 240, parts = 10, cores = 3},
    Legendary = {Credits = 640, parts = 14, cores = 8}
}

LS_Crafting.ReforgeActions = {
    {ID = "stat_values", Name = "STAT VALUES", Mult = 0.5,
        Description = "Reroll the numbers on the stats the item already has."},
    {ID = "stats", Name = "STATS", Mult = 1, Lockable = "stat",
        Description = "Reroll which stats the item has, and their values. Click a stat to lock it."},
    {ID = "talent_values", Name = "TALENT VALUES", Mult = 0.5, NeedsTalents = true,
        Description = "Reroll the numbers on the talents the item already has."},
    {ID = "talents", Name = "TALENTS", Mult = 1.5, Lockable = "talent", NeedsTalents = true,
        Description = "Replace the item's talents with new ones. Click a talent to lock it."}
}

-- Locking something costs half again as much.
LS_Crafting.LockMultiplier = 1.5

function LS_Crafting.GetReforgeCost(rarity, actionIndex, locked)

    local base = LS_Crafting.ReforgeBase[rarity]
    local action = LS_Crafting.ReforgeActions[actionIndex]

    if not base or not action then
        return nil
    end

    local multiplier = action.Mult * (locked and LS_Crafting.LockMultiplier or 1)
    local cost = {}

    for key, amount in pairs(base) do
        cost[key] = math.max(1, math.ceil(amount * multiplier))
    end

    return cost

end

if CLIENT then
    return
end

----------------------------------------------------------------------
-- Server
----------------------------------------------------------------------

util.AddNetworkString("LS_ComponentGain")
util.AddNetworkString("LS_OpenWorkbench")
util.AddNetworkString("LS_CraftItem")
util.AddNetworkString("LS_CraftResult")
util.AddNetworkString("LS_ReforgeItem")
util.AddNetworkString("LS_ReforgeResult")

function LS_Components.Set(id, amount)

    SetGlobalInt("LS_Comp_" .. id, math.max(0, math.floor(amount or 0)))

    if LS_Save and LS_Save.MarkDirty then
        LS_Save.MarkDirty()
    end

end

function LS_Components.Add(player, id, amount, reason)

    amount = math.floor(amount or 0)

    if amount == 0 or not LS_Components.Names[id] then
        return
    end

    LS_Components.Set(id, LS_Components.Get(id) + amount)

    if IsValid(player) then
        net.Start("LS_ComponentGain")
            net.WriteString(id)
            net.WriteInt(amount, 32)
            net.WriteString(reason or "")
        net.Send(player)
    end

end

-- Grants a whole table ({scrap = 4, parts = 3}).
function LS_Components.AddMany(player, amounts, reason)

    for _, id in ipairs(LS_Components.Order) do
        if (amounts[id] or 0) > 0 then
            LS_Components.Add(player, id, amounts[id], reason)
        end
    end

end

function LS_Components.CanAfford(cost)

    for _, id in ipairs(LS_Components.Order) do
        if (cost[id] or 0) > LS_Components.Get(id) then
            return false
        end
    end

    return true

end

function LS_Components.Spend(player, cost, reason)

    if not LS_Components.CanAfford(cost) then
        return false
    end

    for _, id in ipairs(LS_Components.Order) do
        if (cost[id] or 0) > 0 then
            LS_Components.Add(player, id, -cost[id], reason)
        end
    end

    return true

end

-- Dismantling gives back components for each item removed.
function LS_Components.GiveYield(player, items, reason)

    local total = {}

    for _, item in ipairs(items) do
        for id, amount in pairs(LS_Components.GetYield(item)) do
            total[id] = (total[id] or 0) + amount
        end
    end

    LS_Components.AddMany(player, total, reason or "Dismantled")

end

----------------------------------------------------------------------
-- Crafting
----------------------------------------------------------------------

local function nearWorkbench(player)

    for _, bench in ipairs(ents.FindByClass("ls_workbench")) do
        if bench:GetPos():DistToSqr(player:GetPos()) <= 300 * 300 then
            return bench
        end
    end

end

-- Builds the crafted item, or nil if the request is invalid.
local function generate(kind, id, rarity)

    if kind == "weapon" and LS_Weapons.Data[id] then
        return LS_Items.GenerateItem(nil, {Weapon = id, Rarity = rarity})
    elseif kind == "gadget" and LS_Gadgets.Get(id) then
        return LS_Gadgets.GenerateItem(rarity, id)
    elseif kind == "armor" and LS_Armor.Get(id) then
        return LS_Armor.GenerateItem(rarity, id)
    end

end

net.Receive("LS_CraftItem", function(_, player)

    local kind, id = net.ReadString(), net.ReadString()
    local rarity = LS_Items.Rarities[net.ReadUInt(3)]
    local cost = rarity and LS_Crafting.Costs[rarity]

    if not cost or not nearWorkbench(player) then
        return
    end

    if CurTime() < (player.LS_NextCraft or 0) then
        return
    end

    if not LS_Components.CanAfford(cost) or LS_Currency.Get() < cost.Credits then
        player:EmitSound("buttons/button10.wav", 70, 100)
        return
    end

    local item = generate(kind, id, rarity)

    if not item then
        return
    end

    player.LS_NextCraft = CurTime() + 0.5

    LS_Components.Spend(player, cost, "Crafted " .. item.weapon)
    LS_Currency.Spend(cost.Credits)

    net.Start("LS_CurrencyGain")
        net.WriteInt(-cost.Credits, 32)
        net.WriteString("Crafted " .. item.weapon)
    net.Send(player)

    LS_Inventory.AddItem(item)
    LS_Networking.SendInventory(player)

    net.Start("LS_CraftResult")
        net.WriteTable(item)
    net.Send(player)

    player:EmitSound("ambient/machines/hydraulic_1.wav", 65, 110)

    print("[LS] Crafted " .. item.rarity .. " " .. item.prefix .. " " .. item.weapon)

end)

-- Testing aid: ls_givecomponents <scrap> [parts] [cores]
concommand.Add("ls_givecomponents", function(player, _, args)

    LS_Components.AddMany(player, {
        scrap = tonumber(args[1]) or 0,
        parts = tonumber(args[2]) or 0,
        cores = tonumber(args[3]) or 0
    }, "Debug grant")

end)

----------------------------------------------------------------------
-- Reforging (server)
----------------------------------------------------------------------

-- The stats an item can have.
local function statPool(item)

    if item.gadget then
        return table.Copy(LS_Gadgets.Get(item.gadget).Stats)
    elseif item.armor then
        return table.Copy(LS_Armor.StatNames)
    end

    return table.Copy(LS_Items.StatTypes)

end

local function rollValue(item, stat)

    if item.gadget then
        return LS_Gadgets.RollStatValue(stat, item.rarity)
    elseif item.armor then
        return LS_Armor.RollStatValue(stat, item.rarity)
    end

    return LS_Items.RollStatValue(item, stat)

end

local function pickStat(item, available)

    if not item.gadget and not item.armor then
        return LS_Items.GetWeightedStat(item.prefix, available) or available[math.random(#available)]
    end

    return available[math.random(#available)]

end

local function rerollStatValues(item)

    for stat in pairs(item.stats) do
        item.stats[stat] = rollValue(item, stat)
    end

end

-- New stats (and values), keeping the same number of stats. A locked stat is kept as it is.
local function rerollStats(item, lockedStat)

    local count = table.Count(item.stats)
    local available = statPool(item)
    local result = {}

    if lockedStat and item.stats[lockedStat] ~= nil then
        result[lockedStat] = item.stats[lockedStat]
        table.RemoveByValue(available, lockedStat)
        count = count - 1
    end

    for _ = 1, count do

        if #available == 0 then
            break
        end

        local stat = pickStat(item, available)

        table.RemoveByValue(available, stat)
        result[stat] = rollValue(item, stat)

    end

    item.stats = result

end

local function rerollTalentValues(item)

    for _, instance in ipairs(item.talents) do
        instance.rolls = LS_Talents.Roll(instance.id).rolls
    end

end

-- The talents this item is allowed to roll.
local function talentPool(item)

    local pool = {}

    for id, talent in pairs(LS_Talents.Registered) do

        local allowed

        if item.gadget then
            allowed = talent.Slot == "GADGET" and (not talent.Gadgets or table.HasValue(talent.Gadgets, item.gadget))
        elseif item.armor then
            allowed = talent.Slot == "ARMOR"
        else
            allowed = not talent.Slot
        end

        if allowed then
            table.insert(pool, id)
        end

    end

    return pool

end

-- New talents; a locked talent is kept (with its rolls).
local function rerollTalents(item, lockedID)

    local kept, keptIDs, currentIDs = {}, {}, {}

    for _, instance in ipairs(item.talents) do

        currentIDs[instance.id] = true

        if instance.id == lockedID then
            table.insert(kept, instance)
            keptIDs[instance.id] = true
        end

    end

    local needed = #item.talents - #kept
    local pool = talentPool(item)
    local fresh = {}

    -- Prefer talents the item does not already have, so a reforge changes something.
    for _, id in ipairs(pool) do
        if not currentIDs[id] then
            table.insert(fresh, id)
        end
    end

    if #fresh < needed then
        fresh = {}

        for _, id in ipairs(pool) do
            if not keptIDs[id] then
                table.insert(fresh, id)
            end
        end
    end

    for _ = 1, needed do

        if #fresh == 0 then
            break
        end

        table.insert(kept, LS_Talents.Roll(table.remove(fresh, math.random(#fresh))))

    end

    item.talents = kept

end

-- If the item is worn, make the change take effect now.
local function refreshEquipped(player, item)

    if not LS_Equipment.IsItemEquipped(item.id) then
        return
    end

    if item.gadget then
        LS_Gadgets.OnEquip(player, item)
    elseif item.armor then
        LS_Armor.OnEquip(player, item)
    else
        LS_Weapons.RefreshPlayerWeapons(player)
        LS_PlayerStats.Rebuild()
    end

end

net.Receive("LS_ReforgeItem", function(_, player)

    local itemID, actionIndex, lockKey = net.ReadUInt(16), net.ReadUInt(3), net.ReadString()
    local item = LS_Inventory.GetItemByID(itemID)
    local action = LS_Crafting.ReforgeActions[actionIndex]

    if not item or not action or not nearWorkbench(player) or CurTime() < (player.LS_NextCraft or 0) then
        return
    end

    if action.NeedsTalents and #(item.talents or {}) == 0 then
        return
    end

    -- A lock only counts if it matches the action and exists on the item.
    local locked

    if action.Lockable == "stat" and item.stats[lockKey] ~= nil then
        locked = lockKey
    elseif action.Lockable == "talent" then
        for _, instance in ipairs(item.talents) do
            if instance.id == lockKey then
                locked = lockKey
            end
        end
    end

    local cost = LS_Crafting.GetReforgeCost(item.rarity, actionIndex, locked ~= nil)

    if not cost or not LS_Components.CanAfford(cost) or LS_Currency.Get() < cost.Credits then
        player:EmitSound("buttons/button10.wav", 70, 100)
        return
    end

    player.LS_NextCraft = CurTime() + 0.5

    LS_Components.Spend(player, cost, "Reforged " .. item.weapon)
    LS_Currency.Spend(cost.Credits)

    net.Start("LS_CurrencyGain")
        net.WriteInt(-cost.Credits, 32)
        net.WriteString("Reforged " .. item.weapon)
    net.Send(player)

    if action.ID == "stat_values" then
        rerollStatValues(item)
    elseif action.ID == "stats" then
        rerollStats(item, locked)
    elseif action.ID == "talent_values" then
        rerollTalentValues(item)
    else
        rerollTalents(item, locked)
    end

    refreshEquipped(player, item)

    if LS_Save and LS_Save.MarkDirty then
        LS_Save.MarkDirty()
    end

    LS_Networking.SendInventory(player)

    net.Start("LS_ReforgeResult")
    net.Send(player)

    print("[LS] Reforged (" .. action.ID .. ") " .. item.rarity .. " " .. item.prefix .. " " .. item.weapon)

end)
