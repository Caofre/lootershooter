AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "MP5"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "smg"
SWEP.Slot = 2
SWEP.SlotPos = 6

SWEP.ViewModelFOV = 60
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_smg_mp5.mdl"
SWEP.WorldModel = "models/weapons/w_smg_mp5.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 18
SWEP.Primary.Delay = 0.08
SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 30
SWEP.Primary.ClipMax = 90
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.025
SWEP.Primary.Recoil = 1.2
SWEP.Primary.Sound = Sound("Weapon_MP5Navy.Single")

SWEP.IronSightsPos = Vector(-2.2, -4, 1.3)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.08
    }
}
