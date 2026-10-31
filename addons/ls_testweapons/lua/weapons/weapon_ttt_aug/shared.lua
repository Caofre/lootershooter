AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "AUG"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "ar2"
SWEP.Slot = 2
SWEP.SlotPos = 8

SWEP.ViewModelFOV = 60
SWEP.ViewModel = "models/weapons/cstrike/c_rif_aug.mdl"
SWEP.WorldModel = "models/weapons/w_rif_aug.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 19
SWEP.Primary.Delay = 0.09
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.ClipMax = 90
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.02
SWEP.Primary.Sound = Sound("Weapon_AUG.Single")

SWEP.ScopeZoomFOV = 20
SWEP.ScopeMouseSensitivity = 0.2
SWEP.IronSightsPos = Vector(-2.3, -4, 1.4)
SWEP.IronSightsAng = Vector(0, 0, 0)
SWEP.ReloadAnim = {DefaultReload = {Time = 3.8}}
