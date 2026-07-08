LS_NPCs = {}

hook.Add("OnNPCKilled", "LS_NPCLootDrop", function(npc, attacker, inflictor)

    local loot = ents.Create("ls_loot")

    if not IsValid(loot) then return end

    loot:SetPos(
        npc:GetPos() + Vector(0, 0, 20)
    )

    loot:SetItem(
        LS_Items.GenerateItem()
    )

    loot:Spawn()

end)