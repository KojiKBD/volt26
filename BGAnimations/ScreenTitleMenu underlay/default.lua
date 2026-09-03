-- - - - - - - - - - - - - - - - - - - - -
-- Reset game-cycle state through the VOLT26 CORE API.
VOLT26.Core.ResetSession()

-- -----------------------------------------------------------------------
-- preliminary Lua setup is done
-- now define actors to be passed back to the SM engine

local af = Def.ActorFrame{}
af.InitCommand=function(self) self:Center() end



-- ==========================================
-- VOLT26 LAYER 1: PHANTOM RED BACKGROUND
-- ==========================================
do
    af[#af+1] = Def.Quad{
        Name="VOLT26_RedBG",
        InitCommand=function(self)
            self:zoomto(_screen.w, _screen.h)
            self:xy(0, 0)
            -- BRIGHTENED RED: This punches through the dark train overlay 
            -- to result in true Phantom Red on screen.
            -- Try #FF4444 or #FF5555 if it's still too dark.
            self:diffuse(color("#FF0000")) 
        end
    }
end

-- ==========================================
-- VOLT26 LAYER 1.5: AFTER EFFECTS STAR BURST
-- ==========================================
do
    local performance = VOLT26.Performance.IsEnabled()
    local startNum = 0
    local endNum = 29
    local fDelay = 1 / 20 
    local currentFrame = startNum

    -- FIX 1: Use string.format so it actually finds "star_00000.png"
    local function framePath(n)
        return THEME:GetPathG("", string.format("VOLT26/Stars/star_%05d.png", n))
    end

    -- Loading a new Full HD PNG on every animation tick stalls the screen's
    -- input processing. Keep the same artwork and timing, but warm every
    -- texture before the loop begins so frame changes are cache lookups.
    if performance then
        -- Keep one correctly indexed transparent frame in low-end mode.
        -- This preserves the static star burst without decoding/swapping
        -- thirty Full HD textures during the title screen.
        af[#af+1] = Def.Sprite{
            Name="VOLT26_StaticStars",
            Texture=framePath(startNum),
            InitCommand=function(self)
                self:zoomto(_screen.w, _screen.h)
                self:z(1)
            end,
        }
    else
        local framePaths = {}
        for frame = startNum, endNum do
            framePaths[frame] = framePath(frame)
            if PREFETCHMAN then PREFETCHMAN:Add(framePaths[frame]) end
        end

        local starAnim = Def.Sprite{
            Texture=framePaths[startNum],
            InitCommand=function(self)
                self:zoomto(_screen.w, _screen.h)
                self:z(1)
            end,
        }

        starAnim.OnCommand=function(self)
            self:sleep(fDelay):queuecommand("Animate")
        end
        
        starAnim.AnimateCommand=function(self)
            currentFrame = currentFrame + 1
            
            -- If we hit the end, wrap back to 0
            if currentFrame > endNum then
                currentFrame = startNum
            end
            
            -- Load the next image and queue the next frame
            self:Load(framePaths[currentFrame])
            self:sleep(fDelay):queuecommand("Animate")
        end

        af[#af+1] = starAnim
    end
end

-- ==========================================
-- VOLT26 LAYER 2: THE SLIDING TEXT TRACK
-- ==========================================
do
    local text_images = {
        THEME:GetPathG("", "VOLT26/gameplay_text.png"),
        THEME:GetPathG("", "VOLT26/edit_text.png"),
        THEME:GetPathG("", "VOLT26/options_text.png"),
        THEME:GetPathG("", "VOLT26/exit_text.png")
    }

    local spacing = _screen.w * 0.6 

    local track = Def.ActorFrame{
        Name="VOLT26_Track",
        OnCommand=function(self)
            self:x(0) 
            self:y(-10) -- <--- ADDED THIS: Moves the whole track up by 50 pixels
        end,
        OffCommand=function(self)
            -- The lightweight transition is deliberately text-free. Enhanced
            -- mode retains the existing menu-art exit composition.
            if VOLT26.Performance.IsEnabled() then self:visible(false) end
        end,
    }

    for i, img_path in ipairs(text_images) do
        local menu_index = i - 1
        track[#track+1] = Def.ActorFrame{
            Name="VOLT26_MenuImage_"..menu_index,
            OnCommand=function(self)
                self:x(menu_index * spacing)
                if menu_index == 0 then
                    self:zoom(1.025):diffusealpha(1)
                else
                    self:zoom(0.985):diffusealpha(0.72)
                end
            end,
            VOLT26_HoverMessageCommand=function(self, params)
                self:stoptweening():stopeffect()
                if params.idx == menu_index then
                    -- Quick squash/pop as the new image slams into focus.
                    self:zoom(0.96):diffusealpha(1)
                        :accelerate(0.06):zoom(1.06)
                        :decelerate(0.10):zoom(1.025)
                else
                    self:decelerate(0.12)
                        :zoom(0.985):diffusealpha(0.72)
                end
            end,
            VOLT26_ImpactMessageCommand=function(self, params)
                if params.idx ~= menu_index then return end
                self:stoptweening():stopeffect()
                    :accelerate(0.055):zoom(0.94)
                    :glow(1, 1, 1, 0.65)
                    :decelerate(0.13):zoom(1.06)
                    :glow(1, 1, 1, 0)
            end,
            Def.Sprite{
                Texture=img_path,
                InitCommand=function(self)
                    self:zoomto(_screen.w, _screen.h)
                end
            }
        }
    end

    -- This is a child of the moving text track so the same knife remains
    -- aligned with whichever menu image is selected. Since it is appended
    -- after the images but the train is appended after the whole track, its
    -- layer is: menu images < knife < train.
    track[#track+1] = Def.Sprite{
        Name="VOLT26_Knife",
        Texture=THEME:GetPathG("", "VOLT26/Knife.png"),
        InitCommand=function(self)
            self:visible(false):diffusealpha(0)
        end,
        VOLT26_ConfirmMessageCommand=function(self, params)
            local menu_index = params.idx
            if type(menu_index) ~= "number"
            or menu_index < 0 or menu_index >= #text_images then return end

            self:finishtweening():stopeffect():visible(false)
            self.KnifeMenuIndex = menu_index
            self:queuecommand("SlashKnife")
        end,
        SlashKnifeCommand=function(self)
            local center_x = self.KnifeMenuIndex * spacing
            self:stopeffect()
                :visible(true)
                -- Begin just beyond the upper-right edge of the screen.
                :x(center_x + _screen.w * 0.55)
                :y(-_screen.h * 0.55)
                :rotationz(0)
                :zoom(0.1125)
                :diffuse(1, 1, 1, 1)
                :diffusealpha(0)
                :glow(1, 1, 1, 0.22)
                :linear(0.03):diffusealpha(1)
                -- Land 50px right and 75px above the selected image center.
                :accelerate(0.18)
                :x(center_x + 50)
                -- The parent track sits at y=-10, making this center minus 75.
                :y(-65)
                :zoom(0.1575)
                :decelerate(0.07):zoom(0.144)
                :glow(1, 1, 1, 0)
        end,
        HideKnifeCommand=function(self) self:visible(false) end
    }

    af[#af+1] = track
end

-- ==========================================
-- VOLT26 LAYER 3: THE TRAIN OVERLAY
-- ==========================================
do
    af[#af+1] = Def.ActorFrame{
        Name="VOLT26_Train",
        InitCommand=function(self)
            self:bob()
            self:effectmagnitude(1, 1.5, 0)
            self:effectperiod(1)
        end,
        Def.Sprite{
            Texture=THEME:GetPathG("", "VOLT26/trainoverlay.png"),
            InitCommand=function(self)
                self:scaletoclipped(_screen.w + 32, _screen.h + 32)
            end
        }
    }

    -- Keep the letterbox independent from the train bob so its edges remain
    -- locked to the display while still drawing above the train artwork.
    af[#af+1] = Def.Sprite{
        Name="VOLT26_Letterbox",
        Texture=THEME:GetPathG("", "VOLT26/black_bars.png"),
        InitCommand=function(self)
            self:scaletoclipped(_screen.w + 32, _screen.h + 32)
        end,
    }
end

-- Prepare the profile/color/style flow and Song Select while the player is
-- idle on the title menu. This actor never renders visible content.
af[#af+1] = VOLT26.Warmup.CreateActor("Selection", {
    Delay=VOLT26.Performance.IsEnabled() and 0.75 or 0.35,
    Interval=VOLT26.Performance.IsEnabled() and 0.16 or 0.10,
})

-- ==========================================
-- VOLT26 SOUND ACTOR
-- ==========================================
do
    -- Removed IsAction and SupportPan so ITGmania doesn't block it
    af[#af+1] = LoadActor(THEME:GetPathG("", "VOLT26/changeoption.ogg"))..{
        Name="VOLT26_ChangeSound"
    }
end

-- ==========================================
-- VOLT26 EVENT COUNTDOWN
-- ==========================================
do
    -- Convert a Gregorian date to an integer day. Doing this ourselves avoids
    -- time-of-day and daylight-saving errors from timestamp subtraction.
    local function CivilDay(year, month, day)
        if month <= 2 then year = year - 1 end
        local era = math.floor(year / 400)
        local year_of_era = year - era * 400
        local adjusted_month = month + (month > 2 and -3 or 9)
        local day_of_year = math.floor((153 * adjusted_month + 2) / 5) + day - 1
        local day_of_era = year_of_era * 365
            + math.floor(year_of_era / 4)
            - math.floor(year_of_era / 100)
            + day_of_year
        return era * 146097 + day_of_era
    end

    local function DaysUntilRespark()
        local target = CivilDay(2026, 12, 5)
        local today = CivilDay(Year(), MonthOfYear() + 1, DayOfMonth())
        return math.max(0, target - today)
    end

    local countdown_refresh_elapsed = 60
    local countdown = Def.ActorFrame{
        Name="VOLT26_Countdown",
        InitCommand=function(self)
            -- af is centered, so these coordinates anchor this 470x140
            -- widget to the top-right corner with screen-edge padding.
            self:xy(_screen.w/2 - 20, -_screen.h/2 + 18)
                :zoom(0.55)
        end,
        OnCommand=function(self)
            self:addx(25):diffusealpha(0)
                :decelerate(0.22):addx(-25):diffusealpha(1)
            self:SetUpdateFunction(function(frame, delta)
                countdown_refresh_elapsed = countdown_refresh_elapsed + (delta or 0)
                if countdown_refresh_elapsed >= 60 then
                    countdown_refresh_elapsed = 0
                    MESSAGEMAN:Broadcast("VOLT26_CountdownRefresh")
                end
            end)
        end,
        OffCommand=function(self)
            self:SetUpdateFunction(nil)
        end
    }

    countdown[#countdown+1] = LoadActor(
        THEME:GetPathG("", "VOLT26/daysuntil.png")
    )..{
        InitCommand=function(self)
            -- Render the replacement high-resolution artwork at its design size.
            self:halign(1):valign(0):zoomto(456, 136)
        end
    }

    -- Draw each number separately so the sprite-font digits can have wider,
    -- deliberate spacing without changing the font everywhere else.
    for slot = 1, 3 do
        countdown[#countdown+1] =
            LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
                Name="DaysRemaining" .. slot,
                InitCommand=function(self)
                    self:y(53):zoom(1.18)
                        :diffuse(0, 0, 0, 1):shadowlength(0)
                end,
                OnCommand=function(self) self:queuecommand("Refresh") end,
                VOLT26_CountdownRefreshMessageCommand=function(self)
                    self:playcommand("Refresh")
                end,
                RefreshCommand=function(self)
                    local value = string.format("%03d", DaysUntilRespark())
                    local digit_count = #value
                    local is_used = slot <= digit_count
                    self:visible(is_used)
                    if is_used then
                        self:settext(value:sub(slot, slot))
                            :x(-77 + (slot - (digit_count + 1) / 2) * 34)
                    end
                end
            }
    end

    countdown[#countdown+1] = LoadFont("Persona")..{
        Name="EventPhrase",
        Text=VOLT26.Brand.RandomTagline(),
        InitCommand=function(self)
            self:xy(-235, 102):zoom(0.82):maxwidth(405)
                :diffuse(0, 0, 0, 1):shadowlength(0)
        end
    }

    af[#af+1] = countdown
end

-- ==========================================
-- VOLT26 LAYER 4: INVISIBLE CONTROLLER BRAIN
-- ==========================================
do
    local current_idx = 0
    local menu_item_count = 4
    local idle_elapsed = 0
    local afk_poll_interval = 0.25
    local afk_poll_elapsed = 0
    local afk_armed = false
    local afk_active = false

    local function RedirectMenuInput(redirected)
        for player in ivalues(PlayerNumber) do
            SCREENMAN:set_input_redirected(player, redirected)
        end
    end

    local controller = Def.ActorFrame{
        Name="VOLT26Menu",
        OnCommand=function(self)
            local screen = SCREENMAN:GetTopScreen()
            if not screen then return end

            screen:AddInputCallback(function(event)
                if not event or event.type ~= "InputEventType_FirstPress" then
                    return false
                end

                idle_elapsed = 0
                afk_poll_elapsed = 0
                if afk_active then
                    afk_active = false
                    MESSAGEMAN:Broadcast("VOLT26_HideAFK")
                    MESSAGEMAN:Broadcast("VOLT26_StartMenuAudio")
                    -- Keep redirection active for the dismissal press itself;
                    -- release it on the following actor command/frame.
                    self:queuecommand("ReleaseAFKInput")
                    return false
                end

                if event.GameButton == "Start" then
                    self.ConfirmIndex = current_idx
                    MESSAGEMAN:Broadcast("VOLT26_Confirm", {idx=current_idx})
                    -- The knife reaches its target after 0.03 + 0.18 seconds.
                    self:stoptweening():sleep(0.21)
                        :queuecommand("PlayKnifeImpactSound")
                end

                -- ScreenTitleMenu owns directional navigation. This callback
                -- only synchronizes VOLT26's visual and audio feedback.
                return false
            end)

            -- ScreenInit is a separate screen and never contributes to this
            -- timer. When its visual handoff is present, wait for that final
            -- dissolve before considering the title menu idle.
            if VOLT26.TitleMenu.ShouldUseAFK() then
                local arrival_delay = _G.Volt26InitHandoff == true and 0.90 or 0
                self:sleep(arrival_delay):queuecommand("ArmAFKTimer")
            end
        end,
        ArmAFKTimerCommand=function(self)
            idle_elapsed = 0
            afk_poll_elapsed = 0
            afk_armed = true
            self:SetUpdateFunction(function(frame, delta)
                if not afk_armed or afk_active then return end
                afk_poll_elapsed = afk_poll_elapsed + (delta or 0)
                if afk_poll_elapsed < afk_poll_interval then return end
                idle_elapsed = idle_elapsed + afk_poll_elapsed
                afk_poll_elapsed = 0
                if idle_elapsed >= VOLT26.TitleMenu.GetAFKTimeoutSeconds() then
                    idle_elapsed = 0
                    afk_active = true
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
            afk_armed = false
            self:SetUpdateFunction(nil)
            if afk_active then RedirectMenuInput(false) end
        end,
        PlayKnifeImpactSoundCommand=function(self)
            -- The selected image flashes on the exact frame the knife lands.
            -- The two menu-only loops stop here and cannot follow the next screen.
            MESSAGEMAN:Broadcast("VOLT26_StopMenuAudio")
            MESSAGEMAN:Broadcast("VOLT26_Impact", {idx=self.ConfirmIndex})
            local knife_sound = THEME:GetCurrentThemeDirectory()
                .."Graphics/VOLT26/knife.ogg"
            if FILEMAN:DoesFileExist(knife_sound) then
                SOUND:PlayOnce(knife_sound)
            end
        end,
        VOLT26_HoverMessageCommand=function(self, params)
            local focused_idx = params.idx
            -- LoseFocus broadcasts -999 immediately before the next item
            -- gains focus. Ignore it so movement and audio occur only once.
            if type(focused_idx) ~= "number"
            or focused_idx < 0 or focused_idx >= menu_item_count then
                return
            end

            local previous_idx = current_idx
            current_idx = focused_idx

            -- Directional overshoot gives the track a short P5-style impact.
            local track = self:GetParent():GetChild("VOLT26_Track")
            if track then
                local spacing = _screen.w * 0.6
                local target_x = focused_idx * -(spacing)
                local direction = focused_idx > previous_idx and -1 or 1
                track:stoptweening()
                    :accelerate(0.07)
                    :x(target_x + direction * 30)
                    :zoomx(1.045):rotationz(direction * -1.2)
                    :decelerate(0.09)
                    :x(target_x):zoomx(1):rotationz(0)
            end
            
            -- Stop first so rapid navigation cleanly retriggers the sound.
            local snd = self:GetParent():GetChild("VOLT26_ChangeSound")
            if snd then
                snd:stop()
                snd:play()
            end
        end,
    }

    af[#af+1] = controller
end

-- ==========================================
-- VOLT26 LOOPING SOUNDS
-- ==========================================
do
    local function LoopingSound(name, path)
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
                -- Track playback without sleep/tweens, which would make the
                -- screen wait for the sound before accepting a selection.
                frame:SetUpdateFunction(function(actor, delta)
                    elapsed = elapsed + delta
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
                StartPlayback(self)
            end,
            VOLT26_StartMenuAudioMessageCommand=function(self)
                StartPlayback(self)
            end,
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

    local train_path = THEME:GetPathG("", "VOLT26/train.ogg")
    if FILEMAN:DoesFileExist(train_path) then
        af[#af+1] = LoopingSound("VOLT26_TrainLoop", train_path)
    end

    local menuost_path = THEME:GetPathG("", "VOLT26/menuost.ogg")
    if FILEMAN:DoesFileExist(menuost_path) then
        af[#af+1] = LoopingSound("VOLT26_MenuOSTLoop", menuost_path)
    end
end

-- ==========================================
-- VOLT26 AFK EASTER EGG
-- ==========================================
do
    local video_path = THEME:GetPathG("", "VOLT26/afk.mp4")
    local audio_path = THEME:GetPathG("", "VOLT26/afk.ogg")
    local blank_path = THEME:GetPathG("", "_blank.png")
    if VOLT26.TitleMenu.ShouldUseAFK()
    and FILEMAN:DoesFileExist(video_path) and FILEMAN:DoesFileExist(audio_path) then
        local elapsed = 0
        local length = 0

        local function StartAFK(frame)
            local video = frame:GetChild("Video")
            local audio = frame:GetChild("Audio")
            if not video or not audio then return end

            frame:SetUpdateFunction(nil)
            video:Load(video_path):loop(true):setsize(_screen.w, _screen.h)
            audio:stop()
            length = audio:get():get_length()
            elapsed = 0
            audio:play()

            if length and length > 0 then
                frame:SetUpdateFunction(function(actor, delta)
                    elapsed = elapsed + delta
                    if elapsed >= length then
                        elapsed = elapsed - length
                        local loop_video = actor:GetChild("Video")
                        local loop_audio = actor:GetChild("Audio")
                        if not loop_video or not loop_audio then return end
                        -- Restart both streams together at the loop boundary
                        -- so the extracted audio cannot drift from the movie.
                        loop_video:Load(video_path):loop(true)
                            :setsize(_screen.w, _screen.h)
                        loop_audio:stop()
                        loop_audio:play()
                    end
                end)
            end
        end

        local function StopAFK(frame)
            frame:SetUpdateFunction(nil)
            local video = frame:GetChild("Video")
            local audio = frame:GetChild("Audio")
            if audio then audio:stop() end
            if video then video:Load(blank_path) end
        end

        af[#af+1] = Def.ActorFrame{
            Name="VOLT26_AFK",
            InitCommand=function(self)
                self:xy(0, 0):draworder(10000)
                    :visible(false):diffusealpha(0)
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
                Texture=blank_path,
                InitCommand=function(self)
                    self:xy(0, 0):setsize(_screen.w, _screen.h)
                end,
            },
            Def.Sound{
                Name="Audio",
                File=audio_path,
            },
        }
    end
end

return af
