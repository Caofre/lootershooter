AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "MAC10"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "smg"
SWEP.Slot = 2
SWEP.SlotPos = 4

SWEP.ViewModelFOV = 54
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_smg_mac10.mdl"
SWEP.WorldModel = "models/weapons/w_smg_mac10.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 16
SWEP.Primary.Delay = 0.065
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.ClipMax = 90
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.02
SWEP.Primary.Recoil = 1.15
SWEP.Primary.Sound = Sound("Weapon_MAC10.Single")

SWEP.IronSightsPos = Vector(-2, -4, 1.3)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.17
    }
}
