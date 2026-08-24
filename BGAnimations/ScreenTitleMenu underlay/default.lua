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
    local startNum = 0
    local endNum = 29 
    local fDelay = 1 / 20 
    local currentFrame = startNum

    -- FIX 1: Use string.format so it actually finds "star_00000.png"
    local function framePath(n)
        return THEME:GetPathG("", string.format("VOLT26/Stars/star_%05d.png", n))
    end

    local starAnim = Def.Sprite{
        Texture=framePath(startNum),
        InitCommand=function(self)
            self:zoomto(_screen.w, _screen.h) 
            self:z(1) 
        end,
        OnCommand=function(self)
            self:sleep(fDelay):queuecommand("Animate")
        end,
        
        -- FIX 2: One single, unbreakable looping command
        AnimateCommand=function(self)
            currentFrame = currentFrame + 1
            
            -- If we hit the end, wrap back to 0
            if currentFrame > endNum then
                currentFrame = startNum
            end
            
            -- Load the next image and queue the next frame
            self:Load(framePath(currentFrame))
            self:sleep(fDelay):queuecommand("Animate")
        end
    }

    af[#af+1] = starAnim
end

-- ==========================================
-- VOLT26 LAYER 2: THE SLIDING TEXT TRACK
-- ==========================================
do
    local text_images = {
        THEME:GetPathG("", "VOLT26/gameplay_text.png"),
        THEME:GetPathG("", "VOLT26/mementos_text.png"),
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
        end
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
                self:zoomto(_screen.w + 50, _screen.h + 50)
            end
        }
    }
end

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
                RefreshCommand=function(self)
                    local value = string.format("%03d", DaysUntilRespark())
                    local digit_count = #value
                    local is_used = slot <= digit_count
                    self:visible(is_used)
                    if is_used then
                        self:settext(value:sub(slot, slot))
                            :x(-77 + (slot - (digit_count + 1) / 2) * 34)
                    end
                    self:sleep(60):queuecommand("Refresh")
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
-- VOLT26 LIVE CALENDAR
-- ==========================================
do
    local calendar_root = "VOLT26/Calendar/"
    local weekdays = {
        "sunday", "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday"
    }

    local function WeekdayPath()
        return THEME:GetPathG("", calendar_root .. "Days/"
            .. weekdays[Weekday() + 1] .. ".png")
    end

    local function TimeOfDayName()
        local hour = Hour()
        if hour >= 6 and hour < 17 then
            return "Daytime"
        elseif hour >= 17 then
            return "Evening"
        end
        return "Night"
    end

    local function TimeOfDayPath()
        return THEME:GetPathG("", calendar_root .. "ToD/"
            .. TimeOfDayName() .. ".png")
    end

    local refresh_elapsed = 0
    local calendar = Def.ActorFrame{
        Name="VOLT26_Calendar",
        InitCommand=function(self)
            self:xy(-_screen.w/2 + 18, -_screen.h/2 + 15)
                :zoom(0.75)
        end,
        OnCommand=function(self)
            self:addx(-18):diffusealpha(0)
                :decelerate(0.22):addx(18):diffusealpha(1)
            self:SetUpdateFunction(function(frame, delta)
                refresh_elapsed = refresh_elapsed + delta
                if refresh_elapsed >= 30 then
                    refresh_elapsed = refresh_elapsed - 30
                    MESSAGEMAN:Broadcast("VOLT26_CalendarRefresh")
                end
            end)
        end,
        OffCommand=function(self)
            self:SetUpdateFunction(nil)
        end
    }

    calendar[#calendar+1] = LoadActor(
        THEME:GetPathG("", calendar_root .. "Background.png")
    )..{
        InitCommand=function(self)
            self:xy(85, 40):zoom(0.1):shadowlength(2):draworder(2):rotationz(0)
        end
    }

    calendar[#calendar+1] = LoadActor(
        THEME:GetPathG("", calendar_root .. "ToD/Slash.png")
    )..{
        InitCommand=function(self)
            self:xy(50, 51):zoom(0.1):shadowlength(2):draworder(2):rotationz(0)
        end
    }

    calendar[#calendar+1] = LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
        Name="CalendarMonth",
        Text=tostring(MonthOfYear() + 1),
        InitCommand=function(self)
            self:xy(45, 25):zoom(0.9):diffuse(1, 1, 1, 1):rotationz(15)
                :strokecolor({0, 0, 0, 1}):shadowlength(3):draworder(2)
        end,
        VOLT26_CalendarRefreshMessageCommand=function(self)
            self:settext(tostring(MonthOfYear() + 1))
        end
    }

    -- Day of month: separate combo-font actors provide larger, wider digits.
    for slot = 1, 2 do
        calendar[#calendar+1] = LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
            Name="CalendarDayDigit" .. slot,
            InitCommand=function(self)
                self:y(35):zoom(1.40):diffuse(1, 1, 1, 1)
                    :strokecolor({0, 0, 0, 1}):shadowlength(3):draworder(2)
            end,
            OnCommand=function(self) self:playcommand("RefreshCalendar") end,
            VOLT26_CalendarRefreshMessageCommand=function(self)
                self:playcommand("RefreshCalendar")
            end,
            RefreshCalendarCommand=function(self)
                local day = string.format("%02d", DayOfMonth())
                local count = #day
                local used = slot <= count
                self:visible(used)
                if used then
                    self:settext(day:sub(slot, slot))
                        :x(112 + (slot - (count + 1) / 2) * 38)
                end
            end
        }
    end

    calendar[#calendar+1] = Def.Sprite{
        Name="CalendarWeekday",
        Texture=WeekdayPath(),
        InitCommand=function(self)
            self:xy(110, 83):zoom(0.18):shadowlength(2):draworder(4)
        end,
        VOLT26_CalendarRefreshMessageCommand=function(self)
            self:Load(WeekdayPath())
        end
    }

    calendar[#calendar+1] = Def.Sprite{
        Name="CalendarTimeOfDay",
        Texture=TimeOfDayPath(),
        InitCommand=function(self)
            self:xy(50, 125):zoom(0.12):shadowlength(2):draworder(5)
        end,
        VOLT26_CalendarRefreshMessageCommand=function(self)
            self:Load(TimeOfDayPath())
        end
    }

    af[#af+1] = calendar
end


-- ==========================================
-- VOLT26 LAYER 4: INVISIBLE CONTROLLER BRAIN
-- ==========================================
do
    local current_idx = 0
    local controller = Def.ActorFrame{
        Name="VOLT26Menu",
        OnCommand=function(self)
            local screen = SCREENMAN:GetTopScreen()
            if not screen then return end

            screen:AddInputCallback(function(event)
                if event.type == "InputEventType_FirstPress"
                and event.GameButton == "Start" then
                    self.ConfirmIndex = current_idx
                    MESSAGEMAN:Broadcast("VOLT26_Confirm", {idx=current_idx})
                    -- The knife reaches its target after 0.03 + 0.18 seconds.
                    self:stoptweening():sleep(0.21)
                        :queuecommand("PlayKnifeImpactSound")
                end
            end)
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
            or focused_idx < 0 or focused_idx >= 5 then
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

        return Def.ActorFrame{
            Name=name,
            OnCommand=function(self)
                local sound = self:GetChild("Playback")
                if not sound then return end
                length = sound:get():get_length()
                elapsed = 0
                sound:play()
                if length and length > 0 then
                    -- Track playback without sleep/tweens, which would make the
                    -- screen wait for the sound before accepting a selection.
                    self:SetUpdateFunction(function(frame, delta)
                        elapsed = elapsed + delta
                        if elapsed >= length then
                            elapsed = elapsed - length
                            local sound = frame:GetChild("Playback")
                            if not sound then return end
                            sound:stop()
                            sound:play()
                        end
                    end)
                end
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

return af
