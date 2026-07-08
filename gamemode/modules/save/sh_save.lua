print("[LS] SAVE FILE LOADED")

LS_Save = {}

function LS_Save.SaveInventory()

    local saveData = {

    Inventory = {

        Items = LS_Inventory.Items,
        NextID = LS_Inventory.NextID

    },

    Equipment = LS_Equipment.Slots

}

    local json =
        util.TableToJSON(
            saveData,
            true
        )

    file.Write(
        "lootershooter_inventory.txt",
        json
    )

    print(
        "[LS] Inventory Saved"
    )

end

function LS_Save.LoadInventory()

    if not file.Exists(
        "lootershooter_inventory.txt",
        "DATA"
    ) then

        print(
            "[LS] No save found"
        )

        return
    end

    local json =
        file.Read(
            "lootershooter_inventory.txt",
            "DATA"
        )

    local tbl =
        util.JSONToTable(json)

    if not tbl then
        return
    end

    if tbl.Inventory then

    LS_Inventory.Items =
        tbl.Inventory.Items or {}

    LS_Inventory.NextID =
        tbl.Inventory.NextID or 1

end

if tbl.Equipment then

    LS_Equipment.Slots =
        tbl.Equipment

end

local ply = Entity(1)

if IsValid(ply) then

    LS_Equipment.RestoreEquipment(
        ply
    )

end

    print(
    "[LS] Loaded " ..
    #LS_Inventory.Items ..
    " items"
	)

end