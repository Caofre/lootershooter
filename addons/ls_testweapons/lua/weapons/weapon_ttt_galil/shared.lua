AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "Galil"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "ar2"
SWEP.Slot = 2
SWEP.SlotPos = 9

SWEP.ViewModelFOV = 64
SWEP.ViewModel = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel = "models/weapons/w_rif_galil.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 18
SWEP.Primary.Delay = 0.085
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.ClipMax = 90
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.03
SWEP.Primary.Sound = Sound("Weapon_Galil.Single")

SWEP.IronSightsPos = Vector(-2.4, -4, 1.4)
SWEP.IronSightsAng = Vector(0, 0, 0)
SWEP.ReloadAnim = {DefaultReload = {Time = 2.98}}
