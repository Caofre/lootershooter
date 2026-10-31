AddCSLuaFile()

SWEP.Base = "weapon_ls_base"
SWEP.PrintName = "FN P90"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.HoldType = "smg"
SWEP.Slot = 2
SWEP.SlotPos = 2

SWEP.ViewModelFOV = 55
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/cstrike/c_smg_p90.mdl"
SWEP.WorldModel = "models/weapons/w_smg_p90.mdl"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Damage = 12
SWEP.Primary.Delay = 0.05
SWEP.Primary.ClipSize = 50
SWEP.Primary.DefaultClip = 50
SWEP.Primary.ClipMax = 150
SWEP.Primary.Automatic = true
SWEP.Primary.Cone = 0.025
SWEP.Primary.Recoil = 0.65
SWEP.Primary.Sound = Sound("Weapon_P90.Single")

-- The original TTT scope offset assumed a different ironsight system. This
-- restrained offset keeps the P90 in frame with weapon_ls_base's transform.
SWEP.IronSightsPos = Vector(-2, -4, 1.4)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.ReloadAnim = {
    DefaultReload = {
        Time = 3.4
    }
}
