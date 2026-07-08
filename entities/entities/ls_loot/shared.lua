ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Loot"
ENT.Category = "Looter Shooter"

ENT.Spawnable = false

function ENT:SetupDataTables()

    self:NetworkVar("String", 0, "ItemName")
    self:NetworkVar("String", 1, "ItemRarity")

end