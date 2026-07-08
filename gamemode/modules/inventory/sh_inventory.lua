LS_Inventory = {}

LS_Inventory.Items = {}

LS_Inventory.NextID = 1

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

    for _, item in ipairs(LS_Inventory.Items) do

        if item.id == id then
            return item
        end

    end

    return nil

end