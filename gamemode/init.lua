AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("LS_SendInventory")

print("[Looter Shooter] Server loaded")

function GM:PlayerSpawn(ply)
    ply:StripWeapons()

    ply:Give("weapon_crowbar")
    ply:Give("weapon_pistol")

    print("[Looter Shooter] Player spawned")
end

concommand.Add("ls_generateitem", function(ply)

    local item =
        LS_Items.GenerateItem()

    local id =
        LS_Inventory.AddItem(item)

    LS_Networking.SendInventory(ply)

    print("Added item #" .. id)

end)

concommand.Add("ls_inventory", function()

    LS_Inventory.ListItems()

end)

concommand.Add("ls_item", function(ply, cmd, args)

    local id = tonumber(args[1])

    if not id then
        print("Usage: ls_item <id>")
        return
    end

    local item =
        LS_Inventory.GetItemByID(id)

    if not item then
        print("Item not found.")
        return
    end

    LS_Items.PrintItem(item)


end)

concommand.Add("ls_equip", function(ply, cmd, args)

    local id = tonumber(args[1])

    if not id then
        print("Usage: ls_equip <id>")
        return
    end

    local item = LS_Inventory.GetItemByID(id)

    if not item then
        print("Item not found.")
        return
    end

    LS_Equipment.EquipItem(ply, item)

    print(
        "Equipped " ..
        item.weapon ..
        " to " ..
        item.slot
    )

end)

concommand.Add("ls_equipment", function()

    LS_Equipment.ListEquipment()

end)

concommand.Add("ls_stats", function()

    local stats =
        LS_Equipment.GetTotalStats()

    print("")
    print("=== TOTAL STATS ===")

    PrintTable(stats)

    print("===================")
    print("")

end)

concommand.Add(
    "ls_spawnloot",
    function(ply)

        local ent = ents.Create("ls_loot")
		local item = LS_Items.GenerateItem()

		ent:SetItem(item)

        if not IsValid(ent) then return end

        ent:SetPos(
            ply:GetEyeTrace().HitPos +
            Vector(0, 0, 20)
        )

        ent:Spawn()

    end
)

concommand.Add("ls_spawnzombie", function(ply)

    local npc = ents.Create("npc_zombie")

    if not IsValid(npc) then return end

    npc:SetPos(
        ply:GetEyeTrace().HitPos
    )

    npc:Spawn()

end)

concommand.Add("ls_playerstats", function()

    print("")
    print("=== PLAYER STATS ===")

    PrintTable(
        LS_PlayerStats.Current
    )

    print("====================")
    print("")

end)

concommand.Add(
    "ls_refreshweapons",
    function(ply)

        LS_Weapons.RefreshPlayerWeapons(
            Entity(1)
        )

        print("Weapons refreshed")

    end
)

concommand.Add(
    "ls_save",
    function()

        LS_Save.SaveInventory()

    end
)

concommand.Add(
    "ls_load",
    function()

        LS_Save.LoadInventory()

		LS_Networking.SendInventory(ply)

    end
)

concommand.Add(
    "ls_inventoryui",
    function()
   
    end
)

concommand.Add(
    "ls_sync",
    function(ply)

        LS_Networking.SendInventory(ply)

    end
)