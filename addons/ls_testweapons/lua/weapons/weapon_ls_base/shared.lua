AddCSLuaFile()

SWEP.Base = "weapon_base"
SWEP.Category = "Looter Shooter"
SWEP.Spawnable = false
SWEP.DrawCrosshair = true
SWEP.HoldType = "ar2"
SWEP.Primary.Sound = Sound("Weapon_Pistol.Single")
SWEP.Primary.Damage = 1
SWEP.Primary.Delay = 0.2
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Cone = 0.02

-- ADS tuning. The cone multiplier tightens spread while aiming; the FOV scale
-- zooms the view slightly (scoped weapons use ScopeZoomFOV instead).
SWEP.AdsConeMultiplier = 0.5
SWEP.AdsFOVScale = 0.88
SWEP.AdsBlendSpeed = 9

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "LSIronsights")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetLSIronsights(false)

    -- "c_" viewmodels have no arms of their own and are drawn with the player's
    -- hands; older "v_" models already include arms and must not get extra hands.
    if string.find(string.lower(self.ViewModel or ""), "/c_", 1, true) then
        self.UseHands = true
    end
end

function SWEP:SetIronsights(value)
    self:SetLSIronsights(value)
end

function SWEP:GetIronsights()
    return self:GetLSIronsights()
end

function SWEP:CanPrimaryAttack()
    if self:Clip1() > 0 then
        return true
    end

    self:EmitSound("Weapon_Pistol.Empty")
    self:SetNextPrimaryFire(CurTime() + 0.2)
    return false
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then
        return
    end

    local owner = self:GetOwner()

    if not IsValid(owner) then
        return
    end

    if SERVER and self.LS_Reloading then
        self.LS_Reloading = false
        self.LS_ReloadToken = (self.LS_ReloadToken or 0) + 1
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:EmitSound(self.Primary.Sound)
    owner:SetAnimation(PLAYER_ATTACK1)

    local pelletTargets = nil

    if SERVER and (self.Primary.NumShots or 1) > 1 then
        pelletTargets = {}
        self.LS_PelletHitTargets = pelletTargets
    end

    local cone = self.Primary.Cone or 0.02

    self.LS_ShotHit = false

    if self:GetLSIronsights() then
        cone = cone * (self.AdsConeMultiplier or 1)
    end

    owner:FireBullets({
        Attacker = owner,
        Damage = self.Primary.Damage,
        Force = 1,
        Num = self.Primary.NumShots or 1,
        Src = owner:GetShootPos(),
        Dir = owner:GetAimVector(),
        Spread = Vector(cone, cone, 0),
        Tracer = 1,
        -- Runs for each bullet just before its damage is applied. The talent
        -- system uses it for headshots, piercing direction and miss detection.
        Callback = function(attacker, trace)
            if IsValid(trace.Entity) and trace.Entity:IsNPC() then
                self.LS_ShotHit = true
            end

            self.LS_LastHitEntity = trace.Entity
            self.LS_LastHitGroup = trace.HitGroup
            self.LS_LastShotDir = trace.Normal
        end
    })

    if SERVER then
        hook.Run("LS_WeaponFired", self, owner, self.LS_ShotHit)
    end

    if SERVER and self.LS_PelletHitTargets == pelletTargets then
        self.LS_PelletHitTargets = nil
    end

    self:TakePrimaryAmmo(1)

    -- Do not apply the old server-only ViewPunch here. It displaced later
    -- shots without moving the standard crosshair, making weapons appear to
    -- fire below the reticle. Recoil will return as a client-visible system.
end

function SWEP:SecondaryAttack()
    if not self.IronSightsPos or self:GetNextSecondaryFire() > CurTime() then
        return
    end

    local aiming = not self:GetLSIronsights()

    self:SetLSIronsights(aiming)
    self:SetScopeZoom(aiming)
    self:SetNextSecondaryFire(CurTime() + 0.3)
end

function SWEP:SetScopeZoom(enabled)

    if not self.ScopeZoomFOV then
        return
    end

    local owner = self:GetOwner()

    if IsValid(owner) and owner:IsPlayer() then
        owner:SetFOV(enabled and self.ScopeZoomFOV or 0, 0.2)
    end

end

function SWEP:ResetScope()

    self:SetLSIronsights(false)
    self:SetScopeZoom(false)

end

function SWEP:Reload()
    local owner = self:GetOwner()

    if not IsValid(owner) or self:Clip1() >= self.Primary.ClipSize or
        owner:GetAmmoCount(self.Primary.Ammo) <= 0 then
        return
    end

    if self.ReloadPerShell then
        self:ReloadShellByShell(owner)
        return
    end

    local reloadSpeed = self:GetNWFloat("LS_ReloadSpeed", 1)

    self:ResetScope()
    self:SendWeaponAnim(ACT_VM_RELOAD)
    self:SetPlaybackRate(reloadSpeed)

    local animationDuration = self:SequenceDuration()

    -- Some imported weapons (currently the M4A1) are missing their original
    -- viewmodel. Source then reports an almost-zero sequence duration even
    -- though the weapon definition still supplies a real reload duration.
    if animationDuration <= 0.1 and self.ReloadAnim then
        local reloadData = self.ReloadAnim.DefaultReload

        if self:Clip1() <= 0 and self.ReloadAnim.ReloadEmpty then
            reloadData = self.ReloadAnim.ReloadEmpty
        end

        if reloadData and reloadData.Time then
            animationDuration = reloadData.Time
        end
    end

    local reloadTime = math.max(0.1, animationDuration / reloadSpeed)

    self:SetNextPrimaryFire(CurTime() + reloadTime)
    self:SetNextSecondaryFire(CurTime() + reloadTime)
    owner:SetAnimation(PLAYER_RELOAD)

    if SERVER then
        self:SetNWFloat("LS_ReloadStartedAt", CurTime())
        self:SetNWFloat("LS_ReloadEndsAt", CurTime() + reloadTime)
    end

    if CLIENT then
        return
    end

    if self.LS_Reloading then
        return
    end

    self.LS_Reloading = true
    self.LS_ReloadToken = (self.LS_ReloadToken or 0) + 1

    local reloadToken = self.LS_ReloadToken

    timer.Simple(reloadTime, function()
        if not IsValid(self) or not IsValid(owner) or self:GetOwner() ~= owner or
            self.LS_ReloadToken ~= reloadToken then
            return
        end

        local ammoToLoad = math.min(
            self.Primary.ClipSize - self:Clip1(),
            owner:GetAmmoCount(self.Primary.Ammo)
        )

        if ammoToLoad > 0 then
            owner:RemoveAmmo(ammoToLoad, self.Primary.Ammo)
            self:SetClip1(self:Clip1() + ammoToLoad)
        end

        self:SetPlaybackRate(1)
        self.LS_Reloading = false
    end)

    -- Talents (Quick Hands, Shockwave) hook in here, after the reload is set up.
    hook.Run("LS_WeaponReload", self, owner)
end

-- Finishes the current reload immediately (used by Quick Hands).
function SWEP:CompleteReloadNow()
    local owner = self:GetOwner()

    if not SERVER or not IsValid(owner) then
        return
    end

    -- Invalidates the pending reload timers, then loads the ammo right now.
    self.LS_ReloadToken = (self.LS_ReloadToken or 0) + 1
    self.LS_Reloading = false

    local ammoToLoad = math.min(
        self.Primary.ClipSize - self:Clip1(),
        owner:GetAmmoCount(self.Primary.Ammo)
    )

    if ammoToLoad > 0 then
        owner:RemoveAmmo(ammoToLoad, self.Primary.Ammo)
        self:SetClip1(self:Clip1() + ammoToLoad)
    end

    self:SetPlaybackRate(1)
    self:SetNextPrimaryFire(CurTime())
    self:SetNextSecondaryFire(CurTime())
    self:SetNWFloat("LS_ReloadEndsAt", 0)
    self:SendWeaponAnim(ACT_VM_IDLE)
end

function SWEP:ReloadShellByShell(owner)

    local reloadSpeed = self:GetNWFloat("LS_ReloadSpeed", 1)
    local shellTime = math.max(
        0.1,
        (self.ReloadShellTime or 0.6) / reloadSpeed
    )

    self:SetLSIronsights(false)
    self:SendWeaponAnim(ACT_VM_RELOAD)
    self:SetPlaybackRate(reloadSpeed)
    self:SetNextPrimaryFire(CurTime() + shellTime)
    self:SetNextSecondaryFire(CurTime() + shellTime)
    owner:SetAnimation(PLAYER_RELOAD)

    if CLIENT or self.LS_Reloading then
        return
    end

    self.LS_Reloading = true
    self.LS_ReloadToken = (self.LS_ReloadToken or 0) + 1

    local reloadToken = self.LS_ReloadToken

    local function finishReload()
        if not IsValid(self) then
            return
        end

        self.LS_Reloading = false
        self:SetPlaybackRate(1)
    end

    local function loadShell()

        if not IsValid(self) or not IsValid(owner) or
            self:GetOwner() ~= owner or
            self.LS_ReloadToken ~= reloadToken or
            not self.LS_Reloading then
            return
        end

        if self:Clip1() >= self.Primary.ClipSize or
            owner:GetAmmoCount(self.Primary.Ammo) <= 0 then
            finishReload()
            return
        end

        self:SendWeaponAnim(ACT_VM_RELOAD)
        self:SetPlaybackRate(reloadSpeed)
        self:SetNextPrimaryFire(CurTime() + shellTime)
        self:SetNextSecondaryFire(CurTime() + shellTime)

        timer.Simple(shellTime, function()

            if not IsValid(self) or not IsValid(owner) or
                self:GetOwner() ~= owner or
                self.LS_ReloadToken ~= reloadToken or
                not self.LS_Reloading then
                return
            end

            if self:Clip1() < self.Primary.ClipSize and
                owner:GetAmmoCount(self.Primary.Ammo) > 0 then
                owner:RemoveAmmo(1, self.Primary.Ammo)
                self:SetClip1(self:Clip1() + 1)
            end

            loadShell()

        end)

    end

    hook.Run("LS_WeaponReload", self, owner)

    loadShell()

end

function SWEP:Deploy()
    self:ResetScope()
    return true
end

function SWEP:Holster()
    self:ResetScope()
    return true
end

function SWEP:OnRemove()
    self:ResetScope()
end

function SWEP:Think()
    if not CLIENT then
        return
    end

    local owner = self:GetOwner()
    local viewModel = IsValid(owner) and owner:GetViewModel()

    if not IsValid(viewModel) then
        return
    end

    if CurTime() < self:GetNWFloat("LS_ReloadEndsAt", 0) then
        viewModel:SetPlaybackRate(self:GetNWFloat("LS_ReloadSpeed", 1))
    else
        viewModel:SetPlaybackRate(1)
    end
end

-- ===== ADS: per-weapon sight poses, smooth blend, in-game tuner =====
-- Poses live in lootershooter_ads.txt (DATA). A saved pose overrides the
-- SWEP's IronSightsPos / IronSightsAng. Use ls_ads_tune to align a weapon.
LS_ADS = LS_ADS or {Live = {}, Saved = {}, Tuning = false}

if CLIENT then
    local dataFile = "lootershooter_ads.txt"

    function LS_ADS.Load()
        LS_ADS.Saved = {}
        LS_ADS.Live = {}
        if not file.Exists(dataFile, "DATA") then return end
        LS_ADS.Saved = util.JSONToTable(file.Read(dataFile, "DATA") or "") or {}
    end

    function LS_ADS.GetPose(weapon)
        local class = weapon:GetClass()
        local pose = LS_ADS.Live[class]

        if not pose then
            local saved = LS_ADS.Saved[class]

            if saved and saved.pos and saved.ang then
                pose = {
                    Pos = Vector(saved.pos[1], saved.pos[2], saved.pos[3]),
                    Ang = Vector(saved.ang[1], saved.ang[2], saved.ang[3])
                }
            else
                pose = {
                    Pos = Vector(weapon.IronSightsPos or vector_origin),
                    Ang = Vector(weapon.IronSightsAng or vector_origin)
                }
            end

            LS_ADS.Live[class] = pose
        end

        return pose
    end

    function LS_ADS.SaveCurrent(weapon)
        local class = weapon:GetClass()
        local pose = LS_ADS.GetPose(weapon)

        LS_ADS.Saved[class] = {
            pos = {math.Round(pose.Pos.x, 3), math.Round(pose.Pos.y, 3), math.Round(pose.Pos.z, 3)},
            ang = {math.Round(pose.Ang.x, 3), math.Round(pose.Ang.y, 3), math.Round(pose.Ang.z, 3)}
        }

        file.Write(dataFile, util.TableToJSON(LS_ADS.Saved, true))

        print("[LS] ADS pose saved for " .. class .. ":")
        print(string.format("SWEP.IronSightsPos = Vector(%.3f, %.3f, %.3f)", pose.Pos.x, pose.Pos.y, pose.Pos.z))
        print(string.format("SWEP.IronSightsAng = Vector(%.3f, %.3f, %.3f)", pose.Ang.x, pose.Ang.y, pose.Ang.z))
    end

    function LS_ADS.ResetCurrent(weapon)
        local class = weapon:GetClass()
        LS_ADS.Saved[class] = nil
        LS_ADS.Live[class] = nil
        file.Write(dataFile, util.TableToJSON(LS_ADS.Saved, true))
        print("[LS] ADS pose reset to the weapon default for " .. class)
    end

    LS_ADS.Load()

    concommand.Add("ls_ads_tune", function()
        LS_ADS.Tuning = not LS_ADS.Tuning

        if LS_ADS.Tuning then
            print("[LS] ADS tuner ON. Hold a gun and use:")
            print("  Arrows: left/right = x, up/down = height (z)")
            print("  PageUp/PageDown: forward/back (y)")
            print("  Rotate: Insert/Delete = pitch, Home/End = yaw, [ and ] = roll (keypad 8/2, 4/6, 7/9 also work)")
            print("  Shift = fine, Ctrl = coarse, ENTER = save, BACKSPACE = reset gun")
        else
            print("[LS] ADS tuner OFF.")
        end
    end)

    concommand.Add("ls_ads_reload", function()
        LS_ADS.Load()
        print("[LS] ADS poses reloaded.")
    end)

    hook.Add("Think", "LS_ADSTuner", function()
        if not LS_ADS.Tuning then return end

        local player = LocalPlayer()
        local weapon = IsValid(player) and player:GetActiveWeapon()

        if not IsValid(weapon) or not weapon.IronSightsPos then return end
        if gui.IsGameUIVisible() or vgui.CursorVisible() then return end
        if CurTime() < (LS_ADS.NextNudge or 0) then return end

        LS_ADS.NextNudge = CurTime() + 0.03

        local step = 0.06
        if input.IsShiftDown() then step = 0.015 elseif input.IsControlDown() then step = 0.3 end

        local pose = LS_ADS.GetPose(weapon)
        local down = input.IsKeyDown

        if down(KEY_RIGHT) then pose.Pos.x = pose.Pos.x + step end
        if down(KEY_LEFT) then pose.Pos.x = pose.Pos.x - step end
        if down(KEY_UP) then pose.Pos.z = pose.Pos.z + step end
        if down(KEY_DOWN) then pose.Pos.z = pose.Pos.z - step end
        if down(KEY_PAGEUP) then pose.Pos.y = pose.Pos.y + step end
        if down(KEY_PAGEDOWN) then pose.Pos.y = pose.Pos.y - step end

        local angleStep = step * 5
        if down(KEY_INSERT) then pose.Ang.x = pose.Ang.x + angleStep end
        if down(KEY_DELETE) then pose.Ang.x = pose.Ang.x - angleStep end
        if down(KEY_END) then pose.Ang.y = pose.Ang.y + angleStep end
        if down(KEY_HOME) then pose.Ang.y = pose.Ang.y - angleStep end
        if down(KEY_RBRACKET) then pose.Ang.z = pose.Ang.z + angleStep end
        if down(KEY_LBRACKET) then pose.Ang.z = pose.Ang.z - angleStep end
        if down(KEY_PAD_8) then pose.Ang.x = pose.Ang.x + angleStep end
        if down(KEY_PAD_2) then pose.Ang.x = pose.Ang.x - angleStep end
        if down(KEY_PAD_6) then pose.Ang.y = pose.Ang.y + angleStep end
        if down(KEY_PAD_4) then pose.Ang.y = pose.Ang.y - angleStep end
        if down(KEY_PAD_9) then pose.Ang.z = pose.Ang.z + angleStep end
        if down(KEY_PAD_7) then pose.Ang.z = pose.Ang.z - angleStep end
    end)

    hook.Add("PlayerButtonDown", "LS_ADSTunerKeys", function(player, button)
        if not LS_ADS.Tuning or player ~= LocalPlayer() then return end

        local weapon = player:GetActiveWeapon()
        if not IsValid(weapon) or not weapon.IronSightsPos then return end

        if button == KEY_ENTER then
            LS_ADS.SaveCurrent(weapon)
        elseif button == KEY_BACKSPACE then
            LS_ADS.ResetCurrent(weapon)
        end
    end)

    hook.Add("HUDPaint", "LS_ADSTunerHUD", function()
        if not LS_ADS.Tuning then return end

        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid(weapon) or not weapon.IronSightsPos then return end

        local pose = LS_ADS.GetPose(weapon)
        local x, y = ScrW() / 2, ScrH() * 0.62
        local saved = LS_ADS.Saved[weapon:GetClass()] and "saved" or "unsaved"

        draw.SimpleText("ADS TUNER  -  " .. weapon:GetClass() .. "  (" .. saved .. ")", "DermaDefaultBold", x, y, Color(255, 205, 90), TEXT_ALIGN_CENTER)
        draw.SimpleText(string.format("Pos  %.3f  %.3f  %.3f", pose.Pos.x, pose.Pos.y, pose.Pos.z), "DermaDefault", x, y + 18, color_white, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.format("Ang  %.3f  %.3f  %.3f", pose.Ang.x, pose.Ang.y, pose.Ang.z), "DermaDefault", x, y + 34, color_white, TEXT_ALIGN_CENTER)
        draw.SimpleText("Arrows/PgUp/PgDn move  -  Ins/Del, Home/End, [ ] rotate  -  ENTER save  -  BACKSPACE reset", "DermaDefault", x, y + 54, Color(180, 190, 205), TEXT_ALIGN_CENTER)
    end)
end

function SWEP:GetViewModelPosition(position, angle)
    if not self.IronSightsPos then
        return position, angle
    end

    local target = (self:GetLSIronsights() or LS_ADS.Tuning) and 1 or 0

    self.LS_AdsBlend = Lerp(
        math.min(1, FrameTime() * (self.AdsBlendSpeed or 9)),
        self.LS_AdsBlend or 0,
        target
    )

    local blend = self.LS_AdsBlend

    if blend < 0.002 then
        return position, angle
    end

    -- Smoothstep so the weapon eases in and out of the sights.
    blend = blend * blend * (3 - 2 * blend)

    local pose = LS_ADS.GetPose(self)
    local offset = pose.Pos * blend

    position = position +
        offset.x * angle:Right() +
        offset.y * angle:Forward() +
        offset.z * angle:Up()

    local rotation = pose.Ang * blend

    angle:RotateAroundAxis(angle:Right(), rotation.x)
    angle:RotateAroundAxis(angle:Up(), rotation.y)
    angle:RotateAroundAxis(angle:Forward(), rotation.z)

    return position, angle
end

function SWEP:TranslateFOV(fov)
    if self.ScopeZoomFOV or not self.IronSightsPos then
        return fov
    end

    return Lerp(self.LS_AdsBlend or 0, fov, fov * (self.AdsFOVScale or 1))
end

if CLIENT then
    -- While aiming down sights the sights are the reticle; leave a small dot.
    function SWEP:DoDrawCrosshair(x, y)
        if (self.LS_AdsBlend or 0) > 0.3 then
            surface.SetDrawColor(255, 255, 255, 200)
            surface.DrawRect(x - 1, y - 1, 2, 2)
            return true
        end
    end

    function SWEP:DrawHUD()

        if not self.ScopeZoomFOV or not self:GetLSIronsights() then
            return
        end

        local x = ScrW() / 2
        local y = ScrH() / 2
        local radius = ScrH() / 2
        local sideWidth = math.max(0, x - radius)

        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, sideWidth, ScrH())
        surface.DrawRect(x + radius, 0, sideWidth, ScrH())

        surface.SetDrawColor(220, 220, 220, 200)
        surface.DrawLine(x - radius, y, x - 45, y)
        surface.DrawLine(x + 45, y, x + radius, y)
        surface.DrawLine(x, y - radius, x, y - 45)
        surface.DrawLine(x, y + 45, x, y + radius)

        surface.SetDrawColor(255, 90, 90, 255)
        surface.DrawRect(x - 1, y - 1, 3, 3)

    end

    function SWEP:AdjustMouseSensitivity()
        if self.ScopeZoomFOV and self:GetLSIronsights() then
            return self.ScopeMouseSensitivity or 0.2
        end
    end
end
