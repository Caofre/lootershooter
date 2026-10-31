AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "M16"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "ar2"
SWEP.Slot = 2
SWEP.SlotPos = 5

SWEP.ViewModelFOV = 64
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 31
SWEP.Primary.Delay = 0.165
SWEP.Primary.ClipSize = 24
SWEP.Primary.DefaultClip = 24
SWEP.Primary.ClipMax = 72
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.018
SWEP.Primary.Recoil = 1.6
SWEP.Primary.Sound = Sound("Weapon_M4A1.Single")

SWEP.IronSightsPos = Vector(-2.5, -4, 1.4)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.08
    }
}
