ENT.Type = "anim"
ENT.PrintName = "Phalanx Shield"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Wearer")
    self:NetworkVar("Int", 0, "Durability")
    self:NetworkVar("Int", 1, "MaxDurability")
end
