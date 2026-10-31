LS_Save = {}
LS_Save.Loaded = false
LS_Save.Dirty = false

function LS_Save.SaveInventory(silent)

    local saveData = {

    Inventory = {

        Items = LS_Inventory.Items,
        NextID = LS_Inventory.NextID

    },

    Equipment = LS_Equipment.Slots,

    Currency = LS_Currency.Get(),

    Crates = LS_Crates and LS_Crates.Pity or {},

    Components = LS_Components and {
        scrap = LS_Components.Get("scrap"),
        parts = LS_Components.Get("parts"),
        cores = LS_Components.Get("cores")
    } or {}

}

    local json =
        util.TableToJSON(
            saveData,
            false
        )

    file.Write(
        "lootershooter_inventory.txt",
        json
    )

    if not silent then
        print(
            "[LS] Inventory Saved"
        )
    end

end

function LS_Save.LoadInventory()

    if not file.Exists(
        "lootershooter_inventory.txt",
        "DATA"
    ) then

        print(
            "[LS] No save found"
        )

        LS_Save.Loaded = true

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
        -- Keep the unreadable file for recovery, then allow saving again.
        file.Write("lootershooter_inventory_corrupt.txt", json)
        print("[LS] Save file unreadable; backed up to lootershooter_inventory_corrupt.txt")
        LS_Save.Loaded = true
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

if LS_Currency.Set then
    LS_Currency.Set(tbl.Currency or 0)
end

if LS_Crates and tbl.Crates then
    LS_Crates.Pity = tbl.Crates
end

if LS_Components and LS_Components.Set and tbl.Components then
    for id, amount in pairs(tbl.Components) do
        LS_Components.Set(id, amount)
    end
end

local ply = Entity(1)

if IsValid(ply) then

    LS_Equipment.RestoreEquipment(
        ply
    )

end

    LS_Save.Loaded = true

    print(
    "[LS] Loaded " ..
    #LS_Inventory.Items ..
    " items"
	)

end

-- Autosave. Changes only mark the save dirty; a short timer writes it, and
-- shutdown writes any remainder. Nothing saves until the first load attempt
-- has finished, so an empty startup state can never overwrite a real save.
function LS_Save.MarkDirty()
    if SERVER and LS_Save.Loaded then LS_Save.Dirty = true end
end

if SERVER then
    timer.Remove("LS_AutoSave")
    timer.Create("LS_AutoSave", 10, 0, function()
        if LS_Save.Dirty then
            LS_Save.Dirty = false
            LS_Save.SaveInventory(true)
        end
    end)

    hook.Add("ShutDown", "LS_AutoSaveShutdown", function()
        if LS_Save.Loaded then LS_Save.SaveInventory(true) end
    end)

    hook.Add("PlayerInitialSpawn", "LS_AutoLoad", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) or LS_Save.Loaded then return end
            LS_Save.LoadInventory()
            LS_Networking.SendInventory(ply)
        end)
    end)
end
