AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("LS_SendInventory")

print("[Looter Shooter] Server loaded")

-- A player model gives the player a body and, through it, the first-person
-- hands that c_ viewmodels are drawn with.
function GM:PlayerSetModel(ply)

    local model = player_manager.TranslatePlayerModel(ply:GetInfo("cl_playermodel"))

    util.PrecacheModel(model)
    ply:SetModel(model)

end

function GM:PlayerSetHandsModel(ply, hands)

    local info = player_manager.TranslatePlayerHands(player_manager.TranslateToPlayerModelName(ply:GetModel()))

    if info then
        hands:SetModel(info.model)
        hands:SetSkin(info.skin)
        hands:SetBodyGroups(info.body)
    end

end

function GM:PlayerSpawn(ply)
    -- No default HL2 weapons: everything comes from equipped loot.
    ply:StripWeapons()
    ply:StripAmmo()

    GAMEMODE:PlayerSetModel(ply)
    ply:SetupHands()

    timer.Simple(0.1, function()
        if IsValid(ply) and LS_Equipment then
            LS_Equipment.RestoreEquipment(ply)
        end
    end)

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

        if not IsValid(ent) then return end

        ent:SetItem(LS_Items.GenerateItem())

        ent:SetPos(
            ply:GetEyeTrace().HitPos +
            Vector(0, 0, 20)
        )

        ent:Spawn()

    end
)

concommand.Add("ls_spawnzombie", function(ply)

    LS_NPCs.Spawn(

        "zombie",

        ply:GetEyeTrace().HitPos

    )

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
    function(ply)

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

util.AddNetworkString("LS_EquipItem")

net.Receive("LS_EquipItem", function(len, ply)

    local itemID = net.ReadUInt(16)

    local item =
        LS_Inventory.GetItemByID(itemID)

    if not item then
        return
    end

    LS_Equipment.EquipItem(
        ply,
        item
    )

    LS_Networking.SendInventory(ply)

    print(
        "[LS] Equipped:",
        item.weapon
    )

end)

util.AddNetworkString("LS_DismantleItem")
util.AddNetworkString("LS_DismantleItems")

net.Receive("LS_DismantleItems", function(len, ply)

    local count = math.min(net.ReadUInt(8), 200)
    local total, removed = 0, 0
    local removedItems = {}

    for _ = 1, count do

        local itemID = net.ReadUInt(16)

        if not LS_Equipment.IsItemEquipped(itemID) then

            local item = LS_Inventory.RemoveItemByID(itemID)

            if item then
                total = total + LS_Currency.GetDismantleValue(item)
                removed = removed + 1
                table.insert(removedItems, item)
            end

        end

    end

    if removed == 0 then
        return
    end

    LS_Currency.Add(ply, total, "Dismantled " .. removed .. " items")
    LS_Components.GiveYield(ply, removedItems, "Dismantled " .. removed .. " items")
    LS_Networking.SendInventory(ply)

    print("[LS] Dismantled " .. removed .. " items for " .. total .. " CR")

end)

net.Receive("LS_DismantleItem", function(len, ply)

    local itemID = net.ReadUInt(16)

    if LS_Equipment.IsItemEquipped(itemID) then
        return
    end

    local item = LS_Inventory.RemoveItemByID(itemID)

    if not item then
        return
    end

    local value = LS_Currency.GetDismantleValue(item)
    LS_Currency.Add(ply, value, "Dismantled " .. item.weapon)
    LS_Components.GiveYield(ply, {item}, "Dismantled " .. item.weapon)

    LS_Networking.SendInventory(ply)

    print(
        "[LS] Dismantled:",
        item.weapon
    )

end)


concommand.Add("ls_talents", function()

    LS_Talents.List()

end)

concommand.Add(
    "ls_eventtest",
    function()

        LS_Events.Call(

            "Test",

            {

                message = "Hello"

            }

        )

    end
)

concommand.Add(
    "ls_talenttest",
    function()

        local item = LS_Inventory.Items[1]

        if not item then

            print("No item in inventory.")

            return

        end

        LS_Talents.Trigger(

            "OnHit",

            {},

            item

        )

    end
)

concommand.Add("ls_npcdebug", function(ply)

    local tr = ply:GetEyeTrace()

    if not IsValid(tr.Entity) then
        print("No entity.")
        return
    end

    local ent = tr.Entity

	print(ent.LS_Name)
	print(ent.LS_Level)
	print(ent.LS_Definition)

    PrintTable(ent:GetKeyValues())

end)

concommand.Add("ls_statustest", function(ply)

    local bucket =
        LS_Status.GetBucket(ply)

    PrintTable(bucket)

end)

concommand.Add("ls_applyfrost", function(ply)

    LS_Status.Apply(

        ply,

        "frost",

        5,

        {

            Slow = 50

        }

    )

end)

concommand.Add("ls_removefrost", function(ply)

    LS_Status.Remove(
        ply,
        "frost"
    )

end)

concommand.Add("ls_explosiontest", function(ply)

    local tr = ply:GetEyeTrace()

    LS_Combat.CreateExplosion(

        {

            Attacker = ply

        },

        tr.HitPos,

        50,

        200

    )

end)

concommand.Add("ls_npcs", function()

    LS_NPCs.List()

end)

concommand.Add("ls_spawncombine", function(ply)

    LS_NPCs.Spawn(
        "combine_soldier",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnantlion", function(ply)

    LS_NPCs.Spawn(
        "antlion",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnrebel", function(ply)

    LS_NPCs.Spawn(
        "rebel",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnmetropolice", function(ply)

    LS_NPCs.Spawn(
        "metropolice",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnpoisonzombie", function(ply)

    LS_NPCs.Spawn(
        "poison_zombie",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnantlionguard", function(ply)

    LS_NPCs.Spawn(
        "antlion_guard",
        ply:GetEyeTrace().HitPos
    )

end)

concommand.Add("ls_spawnnpc", function(ply, cmd, args)

    local npcID = args[1]
    local variantID = args[2]

    if not npcID or not LS_NPCs.Get(npcID) then
        print("Usage: ls_spawnnpc <npc id> [variant id]")
        print("Available NPCs:")
        LS_NPCs.List()
        return
    end

    if variantID and not LS_NPCs.GetVariant(variantID) then
        print("Unknown variant: " .. variantID)
        return
    end

    LS_NPCs.Spawn(
        npcID,
        ply:GetEyeTrace().HitPos,
        variantID
    )

end)

concommand.Add("ls_spawnrandomnpc", function(ply)

    local definitions = {}

    for _, definition in pairs(LS_NPCs.Registered) do
        table.insert(definitions, definition)
    end

    if #definitions == 0 then
        print("No NPC definitions are registered.")
        return
    end

    local definition = definitions[math.random(#definitions)]
    local npc = LS_NPCs.Spawn(
        definition.ID,
        ply:GetEyeTrace().HitPos
    )

    if IsValid(npc) then
        print(
            "Spawned " .. definition.ID ..
            " with variant " .. (npc.LS_Variant or "normal")
        )
    end

end)
