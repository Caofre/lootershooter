AddCSLuaFile "cl_init.lua"
AddCSLuaFile "shared.lua"

include 'shared.lua'

SWEP.Weight				= 30
SWEP.AutoSwitchTo			= true
SWEP.AutoSwitchFrom			= true

function SWEP:Initialize()
	self.BaseClass.Initialize(self)
	self:SetWeaponHoldType "ar2"
end

function SWEP:OnRemove()
end


