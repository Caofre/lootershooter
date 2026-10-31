LS_UI = LS_UI or {}

local themeColors = {
    undead = Color(120, 200, 95),
    antlion = Color(215, 175, 80),
    combine = Color(90, 155, 245),
    resistance = Color(230, 100, 90)
}

function LS_UI.OpenMissionBroker(broker, brokerName, offers)
    if IsValid(LS_UI.MissionBrokerFrame) then LS_UI.MissionBrokerFrame:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(650, 500)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, width, height)
        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(255, 155, 45, 210)
        surface.DrawRect(0, 0, 5, height)
    end
    LS_UI.MissionBrokerFrame = frame
    surface.PlaySound("buttons/button9.wav")

    local close = vgui.Create("DButton", frame)
    close:SetText("×")
    close:SetFont("Trebuchet24")
    close:SetTextColor(Color(225, 230, 235))
    close:SetPos(608, 11)
    close:SetSize(30, 26)
    close.DoClick = function() frame:Remove() end

    local title = vgui.Create("DLabel", frame)
    title:SetPos(28, 24)
    title:SetSize(550, 30)
    title:SetFont("Trebuchet24")
    title:SetTextColor(Color(245, 245, 248))
    title:SetText(brokerName or "Mission Broker")

    local subtitle = vgui.Create("DLabel", frame)
    subtitle:SetPos(30, 56)
    subtitle:SetSize(550, 18)
    subtitle:SetFont("DermaDefaultBold")
    subtitle:SetTextColor(Color(255, 155, 45))
    subtitle:SetText("AVAILABLE CONTRACTS")

    local dialogue = vgui.Create("DLabel", frame)
    dialogue:SetPos(30, 84)
    dialogue:SetSize(580, 36)
    dialogue:SetFont("DermaDefault")
    dialogue:SetTextColor(Color(190, 198, 212))
    dialogue:SetWrap(true)
    dialogue:SetText("Choose one operation. Complete it, then return here to close the contract.")

    if GetGlobalBool("LS_MissionActive", false) then
        subtitle:SetText("CONTRACT IN PROGRESS")
        dialogue:SetText("You already have an open contract. Finish it, or abandon it to take a new one.")
        offers = {}

        local abandon = vgui.Create("DButton", frame)
        abandon:SetText("")
        abandon:SetPos(30, 130)
        abandon:SetSize(590, 72)
        abandon.Paint = function(self, width, height)
            draw.RoundedBox(3, 0, 0, width, height, Color(200, 70, 60, self:IsHovered() and 235 or 170))
            draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, 238))
            draw.SimpleText("ABANDON CONTRACT", "Trebuchet18", 18, 18, Color(245, 245, 248), TEXT_ALIGN_LEFT)
            draw.SimpleText(GetGlobalString("LS_MissionName", ""), "DermaDefault", 18, 45, Color(185, 195, 210), TEXT_ALIGN_LEFT)
        end
        abandon.OnCursorEntered = function() surface.PlaySound("ui/buttonrollover.wav") end
        abandon.DoClick = function()
            surface.PlaySound("buttons/button10.wav")
            net.Start("LS_AbandonMission")
            net.SendToServer()
            frame:Remove()
        end
    elseif #offers == 0 then
        local missing = vgui.Create("DLabel", frame)
        missing:SetPos(30, 160)
        missing:SetSize(580, 50)
        missing:SetFont("Trebuchet18")
        missing:SetTextColor(Color(225, 170, 105))
        missing:SetText("No mission sites have been established yet.")
    end

    for index, offer in ipairs(offers) do
        local button = vgui.Create("DButton", frame)
        button:SetText("")
        button:SetPos(30, 130 + (index - 1) * 92)
        button:SetSize(590, 72)
        button.Paint = function(self, width, height)
            local alpha = self:IsHovered() and 235 or 170
            draw.RoundedBox(3, 0, 0, width, height, Color(255, 155, 45, alpha))
            draw.RoundedBox(2, 2, 2, width - 4, height - 4, Color(22, 25, 31, 238))
            local labelWidth = draw.SimpleText(offer.Label, "Trebuchet18", 18, 18, Color(245, 245, 248), TEXT_ALIGN_LEFT)
            if offer.ThemeName then
                local tint = themeColors[offer.Theme] or Color(185, 195, 210)
                draw.SimpleText(string.upper(offer.ThemeName), "DermaDefaultBold", 18 + labelWidth + 14, 21, tint, TEXT_ALIGN_LEFT)
            end
            draw.SimpleText(offer.Detail, "DermaDefault", 18, 45, Color(185, 195, 210), TEXT_ALIGN_LEFT)
            local tier = LS_Missions.Tiers[offer.Tier or 1]
            local reward = offer.Rewards and offer.Rewards[offer.Tier or 1] or offer.Reward

            if reward then
                draw.SimpleText("+" .. reward .. " CR", "Trebuchet18", width - 18, 22, Color(255, 205, 90), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            draw.SimpleText(tier.Name, "DermaDefaultBold", width - 18 - 3 * 38 - 8, 54, tier.Color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        offer.Tier = 1

        -- Tier selector: I / II / III. Clicking a tier only chooses it.
        for tierIndex, tier in ipairs(LS_Missions.Tiers) do
            local tierButton = vgui.Create("DButton", button)
            tierButton:SetText("")
            tierButton:SetPos(590 - 18 - (4 - tierIndex) * 38, 44)
            tierButton:SetSize(34, 20)
            tierButton:SetTooltip(tier.Name .. ": " .. tier.Description)
            tierButton.Paint = function(self, width, height)
                local selected = offer.Tier == tierIndex
                draw.RoundedBox(3, 0, 0, width, height, Color(tier.Color.r, tier.Color.g, tier.Color.b, selected and 230 or (self:IsHovered() and 120 or 55)))
                draw.SimpleText(string.rep("I", tierIndex), "DermaDefaultBold", width / 2, height / 2,
                    selected and Color(16, 19, 25) or tier.Color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            tierButton.DoClick = function()
                offer.Tier = tierIndex
                surface.PlaySound("buttons/button15.wav")
            end
        end

        button.OnCursorEntered = function() surface.PlaySound("ui/buttonrollover.wav") end
        button.DoClick = function()
            surface.PlaySound("buttons/button14.wav")
            net.Start("LS_AcceptMission")
                net.WriteString(offer.TypeID)
                net.WriteString(offer.SiteID or "")
                net.WriteString(offer.Theme or "")
                net.WriteUInt(offer.Tier or 1, 3)
            net.SendToServer()
            frame:Remove()
        end
    end

    local leave = vgui.Create("DButton", frame)
    leave:SetText("LEAVE")
    leave:SetFont("DermaDefaultBold")
    leave:SetTextColor(Color(235, 240, 245))
    leave:SetPos(435, 440)
    leave:SetSize(185, 35)
    leave.Paint = function(self, width, height)
        draw.RoundedBox(3, 0, 0, width, height, Color(80, 88, 104, self:IsHovered() and 230 or 170))
    end
    leave.DoClick = function() frame:Remove() end
end

net.Receive("LS_OpenMissionBroker", function()
    LS_UI.OpenMissionBroker(net.ReadEntity(), net.ReadString(), net.ReadTable())
end)


-- Mission site markers (toggle with ls_showmissionsites) ----------------------
LS_UI.SiteMarkers = LS_UI.SiteMarkers or {}

net.Receive("LS_ShowSites", function()
    LS_UI.SiteMarkers = net.ReadTable()
end)

local function drawCircle(center, radius, color)

    local previous

    for step = 0, 48 do
        local angle = math.rad(step * 360 / 48)
        local point = center + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)

        if previous then
            render.DrawLine(previous, point, color, false)
        end

        previous = point
    end

end

hook.Add("PostDrawTranslucentRenderables", "LS_SiteMarkers", function()

    for _, site in ipairs(LS_UI.SiteMarkers) do
        local base = site.Position + Vector(0, 0, 12)

        drawCircle(base, site.Radius, Color(255, 155, 45))
        drawCircle(base, site.Radius * 0.3, Color(255, 155, 45, 90))
        render.DrawLine(base, base + Vector(0, 0, 400), Color(255, 155, 45), false)
    end

end)

hook.Add("HUDPaint", "LS_SiteMarkerLabels", function()

    for _, site in ipairs(LS_UI.SiteMarkers) do
        local screen = (site.Position + Vector(0, 0, 420)):ToScreen()

        if screen.visible then
            local meters = math.floor(LocalPlayer():GetPos():Distance(site.Position) / 52.49)

            draw.SimpleTextOutlined(site.Name .. "  [" .. site.ID .. "]", "Trebuchet18", screen.x, screen.y, Color(255, 155, 45),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
            draw.SimpleTextOutlined("radius " .. math.floor(site.Radius) .. "  -  " .. meters .. "m away", "DermaDefault", screen.x, screen.y + 18,
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        end
    end

end)
