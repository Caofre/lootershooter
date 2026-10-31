-- Mission soundtrack: crossfades between tracks as the mission state changes,
-- using the Half-Life 2 / Half-Life 1 music that ships with Garry's Mod.
-- The server publishes the current state in the global "LS_MusicState"
-- (hub, travel, combat, boss, victory, fail); each state has an assigned track.
-- Open the jukebox with ls_music to audition tracks and assign them.

LS_Music = LS_Music or {}
LS_Music.Active = LS_Music.Active or {}
LS_Music.Token = LS_Music.Token or 0

local enabledVar = CreateClientConVar("ls_music_enabled", "1", true, false, "Play the mission soundtrack")
local volumeVar = CreateClientConVar("ls_music_volume", "0.45", true, false, "Soundtrack volume (0-1)")

local FADE_SECONDS = 2
local dataFile = "lootershooter_music.txt"

LS_Music.States = {"hub", "travel", "combat", "boss", "victory", "fail"}

LS_Music.StateLabels = {
    hub = "Hub (idle)",
    travel = "Travel / return",
    combat = "Combat",
    boss = "Boss / Alpha",
    victory = "Victory sting",
    fail = "Failure sting"
}

-- One-shot states play once and are not looped.
local oneShot = {victory = true, fail = true}

-- {name, folder, extension, size in bytes, group}
local catalog = {
    {"hl2_intro", "music", "mp3", 1357430, "HL2"},
    {"hl2_song0", "music", "mp3", 636450, "HL2"},
    {"hl2_song1", "music", "mp3", 1573744, "HL2"},
    {"hl2_song2", "music", "mp3", 2764510, "HL2"},
    {"hl2_song3", "music", "mp3", 1452118, "HL2"},
    {"hl2_song4", "music", "mp3", 1048370, "HL2"},
    {"hl2_song6", "music", "mp3", 725057, "HL2"},
    {"hl2_song7", "music", "mp3", 812223, "HL2"},
    {"hl2_song8", "music", "mp3", 955771, "HL2"},
    {"hl2_song10", "music", "mp3", 465735, "HL2"},
    {"hl2_song11", "music", "mp3", 553924, "HL2"},
    {"hl2_song12_long", "music", "mp3", 1169160, "HL2"},
    {"hl2_song13", "music", "mp3", 857968, "HL2"},
    {"hl2_song14", "music", "mp3", 2548425, "HL2"},
    {"hl2_song15", "music", "mp3", 1108744, "HL2"},
    {"hl2_song16", "music", "mp3", 2726246, "HL2"},
    {"hl2_song17", "music", "mp3", 979594, "HL2"},
    {"hl2_song19", "music", "mp3", 1853965, "HL2"},
    {"hl2_song20_submix0", "music", "mp3", 1656270, "HL2"},
    {"hl2_song20_submix4", "music", "mp3", 2234726, "HL2"},
    {"hl2_song23_suitsong3", "music", "mp3", 695800, "HL2"},
    {"hl2_song25_teleporter", "music", "mp3", 741358, "HL2"},
    {"hl2_song26", "music", "mp3", 1116685, "HL2"},
    {"hl2_song26_trainstation1", "music", "mp3", 1451470, "HL2"},
    {"hl2_song27_trainstation2", "music", "mp3", 1154719, "HL2"},
    {"hl2_song28", "music", "mp3", 213893, "HL2"},
    {"hl2_song29", "music", "mp3", 2172450, "HL2"},
    {"hl2_song30", "music", "mp3", 1665465, "HL2"},
    {"hl2_song31", "music", "mp3", 1581456, "HL2"},
    {"hl2_song32", "music", "mp3", 684097, "HL2"},
    {"hl2_song33", "music", "mp3", 1345309, "HL2"},
    {"ravenholm_1", "music", "mp3", 497499, "HL2"},
    {"radio1", "music", "mp3", 637704, "HL2"},
    {"hl2_ambient_1", "music", "wav", 700614, "Ambient"},
    {"industrial_suspense1", "music/stingers", "wav", 1073270, "Ambient"},
    {"industrial_suspense2", "music/stingers", "wav", 481438, "Ambient"},
    {"hl1_song3", "music", "mp3", 2110174, "HL1"},
    {"hl1_song5", "music", "mp3", 1540496, "HL1"},
    {"hl1_song6", "music", "mp3", 1601100, "HL1"},
    {"hl1_song9", "music", "mp3", 1493266, "HL1"},
    {"hl1_song10", "music", "mp3", 1673825, "HL1"},
    {"hl1_song11", "music", "mp3", 554948, "HL1"},
    {"hl1_song14", "music", "mp3", 1448963, "HL1"},
    {"hl1_song15", "music", "mp3", 1930034, "HL1"},
    {"hl1_song17", "music", "mp3", 1984786, "HL1"},
    {"hl1_song19", "music", "mp3", 1851875, "HL1"},
    {"hl1_song20", "music", "mp3", 1360773, "HL1"},
    {"hl1_song21", "music", "mp3", 1354922, "HL1"},
    {"hl1_song24", "music", "mp3", 1239983, "HL1"},
    {"hl1_song25_remix3", "music", "mp3", 977923, "HL1"},
    {"hl1_song26", "music", "mp3", 601759, "HL1"},
    {"hl1_stinger_song7", "music/stingers", "mp3", 373136, "Stinger"},
    {"hl1_stinger_song8", "music/stingers", "mp3", 142840, "Stinger"},
    {"hl1_stinger_song16", "music/stingers", "mp3", 261541, "Stinger"},
    {"hl1_stinger_song27", "music/stingers", "mp3", 279931, "Stinger"},
    {"hl1_stinger_song28", "music/stingers", "mp3", 114001, "Stinger"}
}

LS_Music.Tracks = {}
LS_Music.ByName = {}

for _, entry in ipairs(catalog) do

    local track = {
        Name = entry[1],
        File = "sound/" .. entry[2] .. "/" .. entry[1] .. "." .. entry[3],
        Group = entry[5],
        -- MP3s run roughly 16 KB per second; WAVs are larger, so this is only a guide.
        Seconds = entry[3] == "mp3" and math.floor(entry[4] / 16000) or math.floor(entry[4] / 88000)
    }

    table.insert(LS_Music.Tracks, track)
    LS_Music.ByName[track.Name] = track

end

-- These are starting guesses; audition in the jukebox and reassign freely.
LS_Music.Defaults = {
    hub = "hl2_song26_trainstation1",
    travel = "industrial_suspense1",
    combat = "hl2_song20_submix4",
    boss = "hl2_song14",
    victory = "hl1_stinger_song28",
    fail = "hl1_stinger_song8"
}

LS_Music.Assignments = table.Copy(LS_Music.Defaults)

function LS_Music.LoadAssignments()

    LS_Music.Assignments = table.Copy(LS_Music.Defaults)

    if not file.Exists(dataFile, "DATA") then
        return
    end

    local saved = util.JSONToTable(file.Read(dataFile, "DATA") or "") or {}

    for _, state in ipairs(LS_Music.States) do
        if saved[state] and LS_Music.ByName[saved[state]] then
            LS_Music.Assignments[state] = saved[state]
        end
    end

end

function LS_Music.SaveAssignments()
    file.Write(dataFile, util.TableToJSON(LS_Music.Assignments, true))
end

function LS_Music.Assign(state, trackName)

    if not LS_Music.StateLabels[state] or not LS_Music.ByName[trackName] then
        return false
    end

    LS_Music.Assignments[state] = trackName
    LS_Music.SaveAssignments()
    LS_Music.Refresh = true

    return true

end

LS_Music.LoadAssignments()

----------------------------------------------------------------------
-- Playback
----------------------------------------------------------------------

local function startTrack(track, loop)

    LS_Music.Token = LS_Music.Token + 1

    local token = LS_Music.Token

    for _, entry in ipairs(LS_Music.Active) do
        entry.Target = 0
    end

    LS_Music.CurrentTrack = track and track.Name or nil

    if not track then
        return
    end

    sound.PlayFile(track.File, "noplay", function(channel, errorCode, errorName)

        if LS_Music.Token ~= token then
            if IsValid(channel) then channel:Stop() end
            return
        end

        if not IsValid(channel) then
            print("[LS] Music could not play " .. track.Name .. " (" .. tostring(errorName) .. ")")
            return
        end

        channel:EnableLooping(loop and true or false)
        channel:SetVolume(0)
        channel:Play()

        table.insert(LS_Music.Active, {Channel = channel, Track = track.Name, Volume = 0, Target = 1})

    end)

end

function LS_Music.Preview(trackName)
    LS_Music.PreviewTrack = trackName
end

function LS_Music.StopPreview()
    LS_Music.PreviewTrack = nil
end

local nextCheck = 0

hook.Add("Think", "LS_MusicThink", function()

    local now = CurTime()

    -- Decide what should be playing.
    if now >= nextCheck or LS_Music.Refresh then

        nextCheck = now + 0.25
        LS_Music.Refresh = nil

        local state = GetGlobalString("LS_MusicState", "hub")
        local desired

        if enabledVar:GetBool() then
            desired = LS_Music.PreviewTrack or LS_Music.Assignments[state]
        end

        local previewing = LS_Music.PreviewTrack ~= nil
        local stateChanged = state ~= LS_Music.LastState and not previewing

        if desired ~= LS_Music.CurrentTrack or
            (oneShot[state] and stateChanged and desired) then

            local loop = previewing or not oneShot[state]
            startTrack(LS_Music.ByName[desired or ""], loop)

        end

        if not previewing then
            LS_Music.LastState = state
        end

    end

    -- Fade channels in and out.
    local master = math.Clamp(volumeVar:GetFloat(), 0, 1)
    local step = FrameTime() / FADE_SECONDS

    for index = #LS_Music.Active, 1, -1 do

        local entry = LS_Music.Active[index]

        if entry.Volume < entry.Target then
            entry.Volume = math.min(entry.Target, entry.Volume + step)
        else
            entry.Volume = math.max(entry.Target, entry.Volume - step)
        end

        if not IsValid(entry.Channel) or
            (entry.Target <= 0 and entry.Volume <= 0) or
            entry.Channel:GetState() == GMOD_CHANNEL_STOPPED then

            if IsValid(entry.Channel) then
                entry.Channel:Stop()
            end

            table.remove(LS_Music.Active, index)

        else
            entry.Channel:SetVolume(entry.Volume * master)
        end

    end

end)

----------------------------------------------------------------------
-- Console commands
----------------------------------------------------------------------

concommand.Add("ls_music_list", function(_, _, args)

    local filter = string.lower(args[1] or "")

    print("[LS] Soundtrack (" .. #LS_Music.Tracks .. " tracks). Use ls_music_play <name>.")

    for _, track in ipairs(LS_Music.Tracks) do
        if filter == "" or string.find(string.lower(track.Name .. " " .. track.Group), filter, 1, true) then
            print(string.format("  %-26s %-8s ~%d:%02d", track.Name, track.Group, math.floor(track.Seconds / 60), track.Seconds % 60))
        end
    end

end)

concommand.Add("ls_music_play", function(_, _, args)

    if args[1] and LS_Music.ByName[args[1]] then
        LS_Music.Preview(args[1])
        print("[LS] Previewing " .. args[1] .. ". ls_music_stop returns to the mission music.")
    else
        print("Usage: ls_music_play <track name>   (see ls_music_list)")
    end

end)

concommand.Add("ls_music_stop", function()
    LS_Music.StopPreview()
end)

concommand.Add("ls_music_set", function(_, _, args)

    if LS_Music.Assign(args[1] or "", args[2] or "") then
        print("[LS] " .. args[1] .. " music is now " .. args[2])
    else
        print("Usage: ls_music_set <" .. table.concat(LS_Music.States, "|") .. "> <track name>")
    end

end)

concommand.Add("ls_music_assignments", function()

    for _, state in ipairs(LS_Music.States) do
        print(string.format("  %-8s %s", state, LS_Music.Assignments[state]))
    end

end)

concommand.Add("ls_music_reset", function()

    LS_Music.Assignments = table.Copy(LS_Music.Defaults)
    LS_Music.SaveAssignments()
    LS_Music.Refresh = true

end)

----------------------------------------------------------------------
-- Jukebox window (ls_music)
----------------------------------------------------------------------

function LS_Music.OpenJukebox()

    if IsValid(LS_Music.Frame) then
        LS_Music.Frame:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(860, ScrW() - 60), math.min(560, ScrH() - 60))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(self, width, height)
        draw.RoundedBox(6, 0, 0, width, height, Color(16, 19, 25, 250))
        draw.RoundedBox(4, 3, 3, width - 6, height - 6, Color(31, 36, 45, 250))
        surface.SetDrawColor(255, 155, 45, 210)
        surface.DrawRect(0, 0, 5, height)
        draw.SimpleText("SOUNDTRACK", "Trebuchet24", 24, 18, Color(245, 245, 248))
        draw.SimpleText("Select a track, preview it, then assign it to a mission state.", "DermaDefault", 26, 48, Color(160, 170, 185))
    end
    LS_Music.Frame = frame

    local close = vgui.Create("DButton", frame)
    close:SetText("×")
    close:SetFont("Trebuchet24")
    close:SetTextColor(Color(225, 230, 235))
    close:SetPos(frame:GetWide() - 46, 10)
    close:SetSize(30, 26)
    close.Paint = function(self, width, height)
        if self:IsHovered() then draw.RoundedBox(3, 0, 0, width, height, Color(170, 65, 65, 180)) end
    end
    close.DoClick = function()
        LS_Music.StopPreview()
        frame:Remove()
    end

    local list = vgui.Create("DListView", frame)
    list:SetPos(20, 76)
    list:SetSize(frame:GetWide() * 0.5 - 30, frame:GetTall() - 96)
    list:SetMultiSelect(false)
    list:AddColumn("Track")
    list:AddColumn("Group"):SetFixedWidth(60)
    list:AddColumn("~Length"):SetFixedWidth(60)

    for _, track in ipairs(LS_Music.Tracks) do
        local line = list:AddLine(track.Name, track.Group, string.format("%d:%02d", math.floor(track.Seconds / 60), track.Seconds % 60))
        line.TrackName = track.Name
    end

    local function selectedTrack()
        local line = list:GetSelectedLine() and list:GetLine(list:GetSelectedLine())
        return line and line.TrackName
    end

    list.DoDoubleClick = function(_, _, line)
        LS_Music.Preview(line.TrackName)
    end

    local right = vgui.Create("DPanel", frame)
    right:SetPos(frame:GetWide() * 0.5 + 10, 76)
    right:SetSize(frame:GetWide() * 0.5 - 30, frame:GetTall() - 96)
    right.Paint = function() end

    local function button(parent, text, x, y, width, onClick)
        local b = vgui.Create("DButton", parent)
        b:SetText(text)
        b:SetPos(x, y)
        b:SetSize(width, 28)
        b.DoClick = onClick
        return b
    end

    local half = (right:GetWide() - 8) / 2

    button(right, "PREVIEW SELECTED", 0, 0, half, function()
        local name = selectedTrack()
        if name then LS_Music.Preview(name) end
    end)

    button(right, "STOP PREVIEW", half + 8, 0, half, function()
        LS_Music.StopPreview()
    end)

    local nowPlaying = vgui.Create("DLabel", right)
    nowPlaying:SetPos(0, 36)
    nowPlaying:SetSize(right:GetWide(), 18)
    nowPlaying:SetTextColor(Color(255, 205, 90))
    nowPlaying.Think = function(self)
        self:SetText("Now playing: " .. (LS_Music.CurrentTrack or "(nothing)") ..
            (LS_Music.PreviewTrack and "   [preview]" or ""))
    end

    local volume = vgui.Create("DNumSlider", right)
    volume:SetPos(0, 58)
    volume:SetSize(right:GetWide(), 24)
    volume:SetText("Volume")
    volume:SetMin(0)
    volume:SetMax(1)
    volume:SetDecimals(2)
    volume:SetConVar("ls_music_volume")

    local enabled = vgui.Create("DCheckBoxLabel", right)
    enabled:SetPos(0, 88)
    enabled:SetText("Music enabled")
    enabled:SetConVar("ls_music_enabled")
    enabled:SizeToContents()

    local heading = vgui.Create("DLabel", right)
    heading:SetPos(0, 118)
    heading:SetSize(right:GetWide(), 18)
    heading:SetFont("DermaDefaultBold")
    heading:SetTextColor(Color(255, 155, 45))
    heading:SetText("ASSIGN SELECTED TRACK TO:")

    local labels = {}

    for index, state in ipairs(LS_Music.States) do

        local y = 142 + (index - 1) * 36

        button(right, LS_Music.StateLabels[state], 0, y, 150, function()
            local name = selectedTrack()

            if name then
                LS_Music.Assign(state, name)
            end
        end)

        local label = vgui.Create("DLabel", right)
        label:SetPos(160, y + 5)
        label:SetSize(right:GetWide() - 160, 18)
        label:SetTextColor(Color(215, 220, 230))
        label.Think = function(self)
            self:SetText(LS_Music.Assignments[state])
        end

        labels[state] = label

    end

    local hint = vgui.Create("DLabel", right)
    hint:SetPos(0, 142 + #LS_Music.States * 36 + 8)
    hint:SetSize(right:GetWide(), 18)
    hint:SetTextColor(Color(150, 160, 175))
    hint:SetText("Tip: double-click a track to preview it.")

    button(right, "RESET ALL TO DEFAULTS", 0, 142 + #LS_Music.States * 36 + 42, right:GetWide(), function()
        RunConsoleCommand("ls_music_reset")
    end)

end

concommand.Add("ls_music", function()
    LS_Music.OpenJukebox()
end)
