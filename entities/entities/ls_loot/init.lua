AddCSLuaFile()

include("shared.lua")

function ENT:Initialize()

    self:SetModel(
        "models/Items/item_item_crate.mdl"
    )
	self:SetUseType(SIMPLE_USE)
    self:PhysicsInit(SOLID_VPHYSICS)

    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()

    if IsValid(phys) then
        phys:Wake()
    end

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

	print(
		"Picked up item #" .. id
	)

	self:Remove()

end