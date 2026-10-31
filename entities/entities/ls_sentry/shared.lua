ENT.Type = "anim"
ENT.PrintName = "Sentry Turret"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "OwnerPlayer")
end
