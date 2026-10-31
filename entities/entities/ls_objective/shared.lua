ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Mission Objective"
ENT.Category = "Looter Shooter"
ENT.Spawnable = false

-- One entity class for every mission objective prop. Kinds:
--   generator  defended by Defend contracts (has health; enemies wear it down)
--   crate      picked up with E by Retrieve contracts
--   nest       destroyed with weapons by Destroy contracts
--   terminal   hacked by holding E (Hack contracts)
function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Kind")
    self:NetworkVar("Int", 0, "ObjHealth")
    self:NetworkVar("Int", 1, "ObjMaxHealth")
    self:NetworkVar("Int", 2, "Progress")
    self:NetworkVar("Bool", 0, "Done")
end
