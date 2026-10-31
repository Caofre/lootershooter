AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "FAMAS"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "ar2"
SWEP.Slot = 2
SWEP.SlotPos = 3

SWEP.ViewModelFOV = 64
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_rif_famas.mdl"
SWEP.WorldModel = "models/weapons/w_rif_famas.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 17
SWEP.Primary.Delay = 0.08
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.ClipMax = 90
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.02
SWEP.Primary.Recoil = 0.8
SWEP.Primary.Sound = Sound("Weapon_FAMAS.Single")

SWEP.IronSightsPos = Vector(-6.24, -2.757, 1.36)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.37
    }
}
