SWEP.Author = "Zaratusa"
SWEP.Contact = "http://steamcommunity.com/profiles/76561198032479768"
SWEP.PrintName = "Dual Elites"

if SERVER then
    AddCSLuaFile()
else
    SWEP.Slot = 1
    SWEP.Icon = "vgui/ttt/icon_dual_elites"
    SWEP.UseHands = true
    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 55
end

SWEP.Base = "weapon_ls_base"

SWEP.Primary.Ammo = "pistol"
SWEP.Primary.Delay = 0.15
SWEP.Primary.Recoil = 1.5
SWEP.Primary.Cone = 0.025
SWEP.Primary.Damage = 20
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 20
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Sound = Sound("Weapon_Elite.Single")

SWEP.HoldType = "duel"
SWEP.ViewModel = Model("models/weapons/cstrike/c_pist_elite.mdl")
SWEP.WorldModel = Model("models/weapons/w_pist_elite.mdl")

SWEP.Kind = WEAPON_PISTOL
SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_ammo_pistol_ttt"
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = true

SWEP.DeploySpeed = 1.4
SWEP.ReloadSpeed = 1
SWEP.ReloadAnim = {
    DefaultReload = {
        Anim = "reload",
        Time = 3.8
    }
}
