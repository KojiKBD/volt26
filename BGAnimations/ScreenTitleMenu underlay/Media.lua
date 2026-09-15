-- Music and idle presentation shared by the 3D title menu.
-- train.ogg intentionally remains excluded from this composition.

local menuMusicPath = THEME:GetPathG("", "VOLT26/menuost.ogg")
local introMusicPath = THEME:GetPathS("", "intro.ogg")
local videoPath = THEME:GetPathG("", "VOLT26/afk.mp4")
local audioPath = THEME:GetPathG("", "VOLT26/afk.ogg")
local blankPath = THEME:GetPathG("", "_blank.png")

local shouldUseAFK = VOLT26.TitleMenu.ShouldUseAFK()
local hasAFKAssets = shouldUseAFK
    and FILEMAN:DoesFileExist(videoPath)
    and FILEMAN:DoesFileExist(audioPath)
local waitForIntro = not _G.Volt26CityIntroPlayed

local function RedirectMenuInput(redirected)
    for player in ivalues(PlayerNumber) do
        SCREENMAN:set_input_redirected(player, redirected)
    end
end

local function LoopingSound(name, path, startImmediately)
    local elapsed = 0
    local length = 0

    local function StartPlayback(frame)
        local sound = frame:GetChild("Playback")
        if not sound then return end
        frame:SetUpdateFunction(nil)
        sound:stop()
        length = sound:get():get_length()
        elapsed = 0
        sound:play()
        if length and length > 0 then
            frame:SetUpdateFunction(function(actor, delta)
                elapsed = elapsed + (delta or 0)
                if elapsed >= length then
                    elapsed = elapsed - length
                    local playback = actor:GetChild("Playback")
                    if not playback then return end
                    playback:stop()
                    playback:play()
                end
            end)
        end
    end

    return Def.ActorFrame{
        Name=name,
        OnCommand=function(self)
            if startImmediately then StartPlayback(self) end
        end,
        VOLT26_StartMenuAudioMessageCommand=function(self) StartPlayback(self) end,
        VOLT26_StopMenuAudioMessageCommand=function(self)
            self:SetUpdateFunction(nil)
            local sound = self:GetChild("Playback")
            if sound then sound:stop() end
        end,
        OffCommand=function(self)
            self:SetUpdateFunction(nil)
            local sound = self:GetChild("Playback")
            if sound then sound:stop() end
        end,
        Def.Sound{
            Name="Playback",
            File=path,
        },
    }
end

local media = Def.ActorFrame{
    Name="VOLT26_TitleMedia",
    InitCommand=function(self)
        self:Center():draworder(10000)
    end,
}

if FILEMAN:DoesFileExist(menuMusicPath) then
    media[#media+1] = LoopingSound(
        "VOLT26_MenuOSTLoop", menuMusicPath, not waitForIntro
    )
end

if waitForIntro and FILEMAN:DoesFileExist(introMusicPath) then
    media[#media+1] = Def.Sound{
        Name="VOLT26_IntroMusic",
        File=introMusicPath,
        OnCommand=function(self)
            self:stop()
            self:play()
        end,
        VOLT26_TitleIntroCompleteMessageCommand=function(self)
            self:stop()
        end,
        OffCommand=function(self)
            self:stop()
        end,
    }
end

do
    local idleElapsed = 0
    local pollElapsed = 0
    local pollInterval = 0.25
    local afkArmed = false
    local afkActive = false

    media[#media+1] = Def.ActorFrame{
        Name="VOLT26_AFKController",
        OnCommand=function(self)
            local screen = SCREENMAN:GetTopScreen()
            if not screen then return end

            screen:AddInputCallback(function(event)
                if not event or event.type ~= "InputEventType_FirstPress" then
                    return false
                end

                idleElapsed = 0
                pollElapsed = 0
                if afkActive then
                    afkActive = false
                    MESSAGEMAN:Broadcast("VOLT26_HideAFK")
                    MESSAGEMAN:Broadcast("VOLT26_StartMenuAudio")
                    -- Consume the dismissal press and release redirected input on
                    -- the next actor command, after this event has finished.
                    self:queuecommand("ReleaseAFKInput")
                    return true
                end
                return false
            end)

            if hasAFKAssets and not waitForIntro then
                self:queuecommand("ArmAFKTimer")
            end
        end,
        VOLT26_TitleIntroCompleteMessageCommand=function(self)
            waitForIntro = false
            MESSAGEMAN:Broadcast("VOLT26_StartMenuAudio")
            if hasAFKAssets then self:queuecommand("ArmAFKTimer") end
        end,
        ArmAFKTimerCommand=function(self)
            idleElapsed = 0
            pollElapsed = 0
            afkArmed = true
            self:SetUpdateFunction(function(frame, delta)
                if not afkArmed or afkActive then return end
                pollElapsed = pollElapsed + (delta or 0)
                if pollElapsed < pollInterval then return end
                idleElapsed = idleElapsed + pollElapsed
                pollElapsed = 0
                if idleElapsed >= VOLT26.TitleMenu.GetAFKTimeoutSeconds() then
                    idleElapsed = 0
                    afkActive = true
                    RedirectMenuInput(true)
                    MESSAGEMAN:Broadcast("VOLT26_StopMenuAudio")
                    MESSAGEMAN:Broadcast("VOLT26_ShowAFK")
                end
            end)
        end,
        ReleaseAFKInputCommand=function(self)
            RedirectMenuInput(false)
        end,
        OffCommand=function(self)
            afkArmed = false
            self:SetUpdateFunction(nil)
            if afkActive then RedirectMenuInput(false) end
        end,
    }
end

if hasAFKAssets then
    local elapsed = 0
    local length = 0

    local function StartAFK(frame)
        local video = frame:GetChild("Video")
        local audio = frame:GetChild("Audio")
        if not video or not audio then return end

        frame:SetUpdateFunction(nil)
        video:Load(videoPath):loop(true):setsize(_screen.w, _screen.h)
        audio:stop()
        length = audio:get():get_length()
        elapsed = 0
        audio:play()

        if length and length > 0 then
            frame:SetUpdateFunction(function(actor, delta)
                elapsed = elapsed + (delta or 0)
                if elapsed >= length then
                    elapsed = elapsed - length
                    local loopVideo = actor:GetChild("Video")
                    local loopAudio = actor:GetChild("Audio")
                    if not loopVideo or not loopAudio then return end
                    loopVideo:Load(videoPath):loop(true):setsize(_screen.w, _screen.h)
                    loopAudio:stop()
                    loopAudio:play()
                end
            end)
        end
    end

    local function StopAFK(frame)
        frame:SetUpdateFunction(nil)
        local video = frame:GetChild("Video")
        local audio = frame:GetChild("Audio")
        if audio then audio:stop() end
        if video then video:Load(blankPath) end
    end

    media[#media+1] = Def.ActorFrame{
        Name="VOLT26_AFK",
        InitCommand=function(self)
            self:xy(0, 0):draworder(10000):visible(false):diffusealpha(0)
        end,
        VOLT26_ShowAFKMessageCommand=function(self)
            StartAFK(self)
            self:stoptweening():visible(true):diffusealpha(0)
                :linear(0.15):diffusealpha(1)
        end,
        VOLT26_HideAFKMessageCommand=function(self)
            StopAFK(self)
            self:stoptweening():visible(false):diffusealpha(0)
        end,
        OffCommand=function(self)
            StopAFK(self)
            self:stoptweening():visible(false)
        end,
        Def.Sprite{
            Name="Video",
            Texture=blankPath,
            InitCommand=function(self)
                self:xy(0, 0):setsize(_screen.w, _screen.h)
            end,
        },
        Def.Sound{
            Name="Audio",
            File=audioPath,
        },
    }
end

return media
