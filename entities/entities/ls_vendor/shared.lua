ENT.Type = "nextbot"
ENT.Base = "base_nextbot"
ENT.PrintName = "Vendor"
ENT.Category = "Looter Shooter"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "VendorName")
end
