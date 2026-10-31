AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "XM1014"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "shotgun"
SWEP.Slot = 2
SWEP.SlotPos = 7

SWEP.ViewModelFOV = 54
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_shot_xm1014.mdl"
SWEP.WorldModel = "models/weapons/w_shot_xm1014.mdl"

SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Damage = 7
SWEP.Primary.NumShots = 14
SWEP.Primary.Delay = 0.85
SWEP.Primary.ClipSize = 8
SWEP.Primary.DefaultClip = 8
SWEP.Primary.ClipMax = 24
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.05
SWEP.Primary.Recoil = 7
SWEP.Primary.Sound = Sound("Weapon_XM1014.Single")

SWEP.ReloadPerShell = true
SWEP.ReloadShellTime = 0.6

SWEP.IronSightsPos = Vector(-2.4, -4, 1.5)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.2
    }
}
