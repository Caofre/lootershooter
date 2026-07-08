LS_Networking = {}


function LS_Networking.SendInventory(ply)

    print("[LS] Sending inventory:", #LS_Inventory.Items)

    net.Start("LS_SendInventory")
        net.WriteTable(LS_Inventory.Items)
    net.Send(ply)

end