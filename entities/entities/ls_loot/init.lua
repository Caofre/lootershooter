AddCSLuaFile()

include("shared.lua")

function ENT:Initialize()

    self:SetModel(
        "models/Items/item_item_crate.mdl"
    )
	self:SetUseType(SIMPLE_USE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

    -- Keep a use-traceable bounding box, but never create a physics object.
    -- Combat NPCs therefore cannot shove the cache away from the player.
    self:SetTrigger(true)

    -- Drop cue scales with rarity; Common and Uncommon stay silent.
    local dropSounds = {
        Rare = {"buttons/blip1.wav", 75, 110, 0.7},
        Epic = {"buttons/combine_button7.wav", 85, 100, 0.9},
        Legendary = {"ambient/energy/whiteflash.wav", 95, 105, 1}
    }

    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        local cue = dropSounds[self:GetItemRarity()]
        if not cue then return end
        sound.Play(cue[1], self:GetPos(), cue[2], cue[3], cue[4])
        if self:GetItemRarity() == "Legendary" then
            sound.Play("items/ammocrate_open.wav", self:GetPos(), 85, 105, 1)
        end
    end)

    -- Loot is deliberately plentiful during testing, so unattended caches
    -- need a firm lifetime to prevent hundreds of rendered entities piling up.
    timer.Simple(60, function()
        if IsValid(self) then
            self:Remove()
        end
    end)

end

function ENT:SetItem(item)

    self.Item = item

    self:SetItemName(
        item.prefix .. " " .. item.weapon
    )

    self:SetItemRarity(
        item.rarity
    )

end

function ENT:Use(ply)

    if not self.Item then
        return
    end

    local id =
    LS_Inventory.AddItem(self.Item)

	LS_Networking.SendInventory(ply)

    local summary = {
        Name = self:GetItemName(),
        Rarity = self:GetItemRarity(),
        Prefix = self.Item.prefix or "",
        Stats = {},
        Talents = {}
    }

    if self.Item.gadget or self.Item.armor then
        for statName, value in SortedPairs(self.Item.stats or {}) do
            table.insert(summary.Stats, statName .. " +" .. value .. "%")
        end
    end

    for _, statName in ipairs(LS_Items.StatTypes) do
        local value = self.Item.stats and self.Item.stats[statName]

        if value then
            table.insert(summary.Stats, statName .. " +" .. value .. "%")
        end
    end

    for _, instance in ipairs(self.Item.talents or {}) do
        local talent = LS_Talents.Get(instance.id)

        if talent then
            table.insert(summary.Talents, talent.Name)
        end
    end

    net.Start("LS_LootPickup")
        net.WriteTable(summary)
    net.Send(ply)

	self:Remove()

end

