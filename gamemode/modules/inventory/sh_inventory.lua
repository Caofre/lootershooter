LS_Inventory = {}

LS_Inventory.Items = {}

LS_Inventory.NextID = 1

-- Lookup index by item id. It is rebuilt whenever the Items table is replaced
-- (save loading) or its size changes, and cleared on add/remove.
local indexOf, indexSource, indexCount

local function rebuildIndex()

    indexOf = {}

    for _, item in ipairs(LS_Inventory.Items) do
        indexOf[item.id] = item
    end

    indexSource = LS_Inventory.Items
    indexCount = #LS_Inventory.Items

end

function LS_Inventory.GenerateID()

    local id = LS_Inventory.NextID

    LS_Inventory.NextID =
        LS_Inventory.NextID + 1

    return id

end

function LS_Inventory.AddItem(item)

    item.id =
        LS_Inventory.GenerateID()

    table.insert(
        LS_Inventory.Items,
        item
    )

    indexOf = nil

    if LS_Save and LS_Save.MarkDirty then LS_Save.MarkDirty() end

    return item.id

end

function LS_Inventory.ListItems()

    print("")
    print("=== INVENTORY ===")

    for _, item in ipairs(
        LS_Inventory.Items
    ) do

        print(
            "[" .. item.id .. "] " ..
            item.rarity .. " " ..
            item.prefix .. " " ..
            item.weapon
        )

    end

    print("=================")
    print("")

end

function LS_Inventory.GetItemByID(id)

    if not indexOf or indexSource ~= LS_Inventory.Items or indexCount ~= #LS_Inventory.Items then
        rebuildIndex()
    end

    return indexOf[id]

end

function LS_Inventory.RemoveItemByID(id)

    for index, item in ipairs(LS_Inventory.Items) do

        if item.id == id then
            table.remove(LS_Inventory.Items, index)
            indexOf = nil
            if LS_Save and LS_Save.MarkDirty then LS_Save.MarkDirty() end
            return item
        end

    end

    return nil

end
