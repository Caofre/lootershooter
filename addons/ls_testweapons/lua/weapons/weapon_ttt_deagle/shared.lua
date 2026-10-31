AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "Deagle"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "pistol"
SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.ViewModelFOV = 54
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"

SWEP.Primary.Ammo = "357"
SWEP.Primary.Damage = 37
SWEP.Primary.Delay = 0.4
SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.Primary.ClipMax = 36
SWEP.Primary.Automatic = false
SWEP.Primary.Cone = 0.012
SWEP.Primary.Recoil = 3.5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Single")

SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 2.2
    }
}
