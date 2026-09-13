-- Full-screen city. Native ScreenTitleMenu owns selection and action routes.
local modelUnits = 35 -- baked into the meshes by tools/import-title-obj.py
local modelParts = 4  -- must match `model_parts` in import-info.json
local fov = 65
local duration = 1.1
local introDuration = 10.6
local introLandingStart = 8.25

-- RageDisplay::LoadMenuPerspective builds GetFrustumMatrix(..., 1, eyeDistance+1000)
-- and puts the eye at world z = eyeDistance, so the far plane always lands on world
-- z = -1000 whatever the FOV. At 35 units per meter that clipped everything beyond
-- about 28 meters, and the rest of the city sliced into view as the camera advanced.
-- Scaling the whole rig down buys depth without changing the image: a true
-- perspective camera projects size*eyeDistance/depth, which is independent of world
-- scale. The previous SCREEN_HEIGHT/480 zoom was visually neutral for the same reason.
local sceneDepth = 130 -- meters from the opening pose to the far skyline
local worldScale = 1000 / (sceneDepth * modelUnits)

-- Camera framing. standOff and streetOffset are measured from the banner along its
-- own normal and its own tangent, so every stop lands at the same 31 degrees off a
-- frontal view however the banner is turned. Raise streetOffset for a more oblique
-- shot, raise standOff for a flatter one.
local standOff = 10
local streetOffset = 6
local nominalHeight, heightFollow = 7, 0.45
local minEyeHeight, maxEyeHeight = 4, 13
local pitchSign = 1 -- flip to -1 if the camera tilts away from the high banners

-- Choosing an entry flies the camera into the banner it is parked on. The screen's
-- own wipe, `BGAnimations/ScreenTitleMenu out.lua`, holds for one second, so the dive
-- has to land inside that or it is cut off mid-flight.
local diveDuration = 0.9
local diveStop = 1.2 -- meters short of the banner, close enough to fill the frame
local diveRoll = 1.8 -- multiplier on the settled Dutch angle, a twist on the way in

-- Blender coordinates: x across the street, y along it, z height. n is the outward
-- face normal from the model and t is the direction stepped along for the oblique
-- offset, both taken in that space. Banner_options lies flat on the road with its
-- normal straight up, so standing off along the normal lifts the eye above the
-- tarmac and it is read looking down, stepped back along the street.
local banners = {
    {x = -6.615, y =  0.000, z =  6.800, nx =  1, ny =  0, nz = 0, tx = 0, ty =  1, side = -1, roll = -3},
    {x = 10.953, y = 19.342, z = 13.896, nx =  0, ny = -1, nz = 0, tx = 1, ty =  0, side = -1, roll =  3},
    {x = -0.012, y = 48.000, z =  0.405, nx =  0, ny =  0, nz = 1, tx = 0, ty =  1, side = -1, roll = -3},
    {x =  6.615, y = 72.000, z = 21.157, nx = -1, ny =  0, nz = 0, tx = 0, ty = -1, side =  1, roll =  3},
    -- Navigation-only countdown on the central building at the end of the street.
    {x =  0.000, y = 91.875, z = 20.000, nx =  0, ny = -1, nz = 0, tx = 1, ty =  0, side = -1, roll = -3},
}

local positions, dives = {}, {}
for i, banner in ipairs(banners) do
    local eyeX = banner.x + banner.nx*standOff + banner.tx*banner.side*streetOffset
    local eyeY = banner.y + banner.ny*standOff + banner.ty*banner.side*streetOffset
    local eyeZ = banner.z + banner.nz*standOff
    -- A banner on a facade can sit anywhere from head height to 21 meters up, so the
    -- eye only follows part of the way and pitch closes the gap. One lying on the road
    -- already has its height set by the stand off above it, so leave that alone.
    if banner.nz == 0 then
        eyeZ = math.min(maxEyeHeight, math.max(minEyeHeight,
            nominalHeight + (banner.z - nominalHeight)*heightFollow))
    end
    local dx, dy, dz = banner.x-eyeX, banner.y-eyeY, banner.z-eyeZ
    local yaw = -math.deg(math.atan2(dx, dy))
    local pitch = -pitchSign*math.deg(math.atan2(dz, math.sqrt(dx*dx + dy*dy)))
    -- The room carries the inverse of the eye position.
    positions[i] = {-eyeX*modelUnits, eyeZ*modelUnits, eyeY*modelUnits, yaw, banner.roll, pitch}
    -- The dive keeps the same aim and slides the eye up the view ray, so the camera
    -- rushes straight in without swinging.
    local remaining = diveStop / math.sqrt(dx*dx + dy*dy + dz*dz)
    positions[i].dive = {
        -(banner.x - dx*remaining)*modelUnits,
         (banner.z - dz*remaining)*modelUnits,
         (banner.y - dy*remaining)*modelUnits,
        yaw, banner.roll*diveRoll, pitch,
    }
end

-- Banner_play is one quad in the OBJ, bounds X -6.615, Y 5.475 to 8.125, Z -3.64 to
-- 3.64, with a full 0-1 UV square. Its `gameplay` material carries no map and the mesh
-- converter writes palette-only UVs, so the animated banner rides on a separate actor
-- pinned to those bounds. Def.Model flips Y and a Sprite does not, hence the negated
-- centre height.
local playBanner = {
    name = "play", caption = "gameplay", rx = 0, ry = 90, nx = 1, ny = 0, nz = 0,
    x = -6.615, y = 6.8, z = 0,
    width = 7.28, height = 2.65,
    lift = 0.02, -- meters toward the street, clear of the quad behind it
    -- The lift is seen at an angle, so it shifts the sprite sideways by
    -- lift*tan(incidence) and leaves the quad behind it showing along one edge. The
    -- real fix is the palette: the `gameplay` slot is repainted to P5_INK, so the
    -- sliver is now frame-black instead of white. This margin is belt and braces.
    overscan = 1.01,
    mirrored = true, -- confirmed in engine: the sprite faces the street mirrored
}

-- OBJ positions are Y-up; banner layer positions negate height, preserving OBJ Z.
-- Each surface gets its own normal offset and orientation. Width follows the
-- camera's right vector, so Edit/Options read along +X and Exit along -Z.
local bannerSurfaces = {
    playBanner,
    {name = "edit", caption = "edit", x = 10.9534255, y = 13.896204, z = -19.341549,
     width = 8.203149, height = 2.654254, rx = 0, ry = 0,
     nx = 0, ny = 0, nz = 1},
    {name = "options", caption = "options", x = -0.012378, y = 0.405, z = -48,
     width = 7.735, height = 2.650002, rx = -90, ry = 0,
     nx = 0, ny = -1, nz = 0},
    {name = "exit", caption = "exit", x = 6.615, y = 21.157425, z = -72,
     width = 8.190002, height = 2.650002, rx = 0, ry = 90,
     nx = -1, ny = 0, nz = 0},
}

-- Navigation stop five mounts the countdown on the street-facing facade of the
-- tall central END_BLOCK_01 building.  OBJ coordinates are X across the street,
-- Y up and Z along it; the small positive Z lift clears the facade skin.
local countdownSurface = {
    x = 0.0, y = 20.0, z = -91.875,
    width = 7.5, lift = 0.03,
}

local function CivilDay(year, month, day)
    if month <= 2 then year = year - 1 end
    local era = math.floor(year / 400)
    local yearOfEra = year - era * 400
    local adjustedMonth = month + (month > 2 and -3 or 9)
    local dayOfYear = math.floor((153 * adjustedMonth + 2) / 5) + day - 1
    return era * 146097 + yearOfEra * 365
        + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
end

local function DaysUntilRespark()
    local target = CivilDay(2026, 12, 5)
    local today = CivilDay(Year(), MonthOfYear() + 1, DayOfMonth())
    return math.max(0, target - today)
end

local function FitCountdownText(actor, text, start, width)
    local last = start - 1
    for i = start, #text do
        actor:settext(text:sub(start, i))
        if actor:GetWidth() > width then break end
        last = i
    end
    return text:sub(start, math.max(start, last))
end

local function CreateCountdownBillboard()
    local designWidth, designHeight = 456, 136
    local phraseWidth = 405
    local refreshElapsed = 60
    local function SetPhrase(actor, fullText)
        actor.VOLT26_FullText = fullText
        actor.VOLT26_MarqueeMaxStart = nil
        actor.VOLT26_MarqueeText = nil
        actor:settext(fullText)
        if actor:GetWidth() <= phraseWidth or #fullText == 0 then return end

        local maxStart = #fullText
        for start = #fullText, 1, -1 do
            actor:settext(fullText:sub(start))
            if actor:GetWidth() > phraseWidth then break end
            maxStart = start
        end
        actor.VOLT26_MarqueeText = fullText
        actor.VOLT26_MarqueeMaxStart = maxStart
        actor.VOLT26_MarqueeStart = 1
        actor.VOLT26_MarqueeDirection = 1
        actor.VOLT26_MarqueeTimer = -1.6
        actor.VOLT26_MarqueeHoldTime = 1.6
        actor.VOLT26_MarqueeStepTime = 0.12
        actor:settext(FitCountdownText(actor, fullText, 1, phraseWidth))
    end

    local countdown = Def.ActorFrame{
        Name = "VOLT26_CountdownBillboard",
        InitCommand=function(self)
            local zoom = countdownSurface.width * modelUnits / designWidth
            self:xy(countdownSurface.x * modelUnits, -countdownSurface.y * modelUnits)
                :z((countdownSurface.z + countdownSurface.lift) * modelUnits)
                :zoom(zoom)
        end,
        OnCommand=function(self)
            if VOLT26.PlayerMessages then VOLT26.PlayerMessages.Load() end
            self:SetUpdateFunction(function(frame, delta)
                refreshElapsed = refreshElapsed + (delta or 0)
                if refreshElapsed >= 60 then
                    refreshElapsed = 0
                    MESSAGEMAN:Broadcast("VOLT26_CountdownRefresh")
                end

                local phrase = frame:GetChild("EventPhrase")
                if not phrase or not phrase.VOLT26_MarqueeMaxStart then return end
                phrase.VOLT26_MarqueeTimer = phrase.VOLT26_MarqueeTimer + (delta or 0)
                if phrase.VOLT26_MarqueeTimer < phrase.VOLT26_MarqueeStepTime then return end
                phrase.VOLT26_MarqueeTimer = 0

                phrase.VOLT26_MarqueeStart = phrase.VOLT26_MarqueeStart
                    + phrase.VOLT26_MarqueeDirection
                if phrase.VOLT26_MarqueeStart >= phrase.VOLT26_MarqueeMaxStart then
                    phrase.VOLT26_MarqueeStart = phrase.VOLT26_MarqueeMaxStart
                    phrase.VOLT26_MarqueeDirection = -1
                    phrase.VOLT26_MarqueeTimer = -phrase.VOLT26_MarqueeHoldTime
                elseif phrase.VOLT26_MarqueeStart <= 1 then
                    phrase.VOLT26_MarqueeStart = 1
                    phrase.VOLT26_MarqueeDirection = 1
                    phrase.VOLT26_MarqueeTimer = -phrase.VOLT26_MarqueeHoldTime
                end
                phrase:settext(FitCountdownText(phrase, phrase.VOLT26_MarqueeText,
                    phrase.VOLT26_MarqueeStart, phraseWidth))
            end)
        end,
        OffCommand=function(self) self:SetUpdateFunction(nil) end,
    }

    countdown[#countdown+1] = LoadActor(THEME:GetPathG("", "VOLT26/daysuntil.png"))..{
        InitCommand=function(self)
            self:halign(0.5):valign(0.5):zoomto(designWidth, designHeight)
        end,
    }

    for slot = 1, 3 do
        countdown[#countdown+1] = LoadFont("_Combo Fonts/VOLT26/VOLT26")..{
            Name="DaysRemaining"..slot,
            InitCommand=function(self)
                self:y(-15):zoom(1.18):diffuse(0, 0, 0, 1):shadowlength(0)
            end,
            OnCommand=function(self) self:queuecommand("Refresh") end,
            VOLT26_CountdownRefreshMessageCommand=function(self) self:playcommand("Refresh") end,
            RefreshCommand=function(self)
                local value = string.format("%03d", DaysUntilRespark())
                self:settext(value:sub(slot, slot)):x(151 + (slot - 2) * 34)
            end,
        }
    end

    countdown[#countdown+1] = LoadFont("Persona")..{
        Name="EventPhrase",
        Text=VOLT26.Brand.RandomTagline(),
        InitCommand=function(self)
            self:xy(-7, 34):zoom(0.82):diffuse(0, 0, 0, 1):shadowlength(0)
            SetPhrase(self, self:GetText())
        end,
        VOLT26_CountdownNextPhraseMessageCommand=function(self)
            local nextText = VOLT26.Brand.RandomTagline(self.VOLT26_FullText)
            SetPhrase(self, nextText)
            self:stoptweening():diffusealpha(0):linear(0.12):diffusealpha(1)
        end,
    }

    return countdown
end

local introActive = not _G.Volt26CityIntroPlayed
-- The room stores the inverse eye position. Begin 70 m above the approach road,
-- looking down at the city; pause at an elevated overview after the logo, then
-- make the final descent to Gameplay.
local skyPose = {0, 70*modelUnits, -30*modelUnits, 0, -2, 58}
local overviewPose = {0, 18*modelUnits, -25*modelUnits, 10, -6, 18}
local current = introActive and skyPose or positions[1]
local start, target = current, positions[1]
local activeDuration = introActive and introDuration or duration
local elapsed = introActive and 0 or activeDuration
local arrivalDelay = 0
local selected = 0
local bankDirection = 1
local clock = 0
local diving = false

local function InteractWithCountdown()
    if selected == 4 and not diving then
        MESSAGEMAN:Broadcast("VOLT26_CountdownNextPhrase")
    end
end

local function RedirectIntroInput(redirected)
    for player in ivalues(PlayerNumber) do
        SCREENMAN:set_input_redirected(player, redirected)
    end
end

local function SmootherStep(t)
    return t*t*t*(t*(t*6 - 15) + 10)
end

local function BlendPose(from, to, amount)
    local pose = {}
    for i = 1, 6 do pose[i] = from[i] + (to[i] - from[i]) * amount end
    return pose
end

local function CreateOpeningCredits()
    local credits = {
        { heading="CONCEPT & DESIGN", name="VOLT Team" },
        { heading="VISUALS & ART", name="Koji" },
        { heading="PROGRAMMING", name="Koji, Mrs GLM 5.2, Sir GPT" },
        { heading="SPECIAL THANKS", name="Dando and the VOLT Team", sub="for testing, ideation, and QA" },
    }
    local creditStart, creditStep = 0.35, 1.45
    local logoHit, logoFade = 6.45, 8.05
    local overlay = Def.ActorFrame{
        Name="VOLT26_OpeningCredits",
        InitCommand=function(self) self:visible(introActive) end,
    }

    for i, credit in ipairs(credits) do
        local startTime = creditStart + (i - 1) * creditStep
        local card = Def.ActorFrame{
            Name="Credit"..i,
            InitCommand=function(self) self:y(14):diffusealpha(0) end,
            OnCommand=function(self)
                if not introActive then return end
                self:sleep(startTime)
                    :decelerate(0.20):y(0):diffusealpha(1)
                    :sleep(0.78)
                    :accelerate(0.22):y(-18):diffusealpha(0)
            end,
        }
        card[#card+1] = LoadFont("Common Normal")..{
            Text=credit.heading,
            InitCommand=function(self)
                self:y(-22):zoom(0.68):maxwidth(_screen.w * 1.25)
                    :diffuse(color("#FF3030")):shadowlength(2)
            end,
        }
        card[#card+1] = LoadFont("Common Normal")..{
            Text=credit.name,
            InitCommand=function(self)
                self:y(12):zoom(0.82):maxwidth(_screen.w * 1.05)
                    :diffuse(Color.White):shadowlength(2)
            end,
        }
        if credit.sub then
            card[#card+1] = LoadFont("Common Normal")..{
                Text=credit.sub,
                InitCommand=function(self)
                    self:y(43):zoom(0.58):maxwidth(_screen.w * 1.4)
                        :diffuse(color("#D0D0D0")):shadowlength(2)
                end,
            }
        end
        overlay[#overlay+1] = card
    end

    overlay[#overlay+1] = LoadFont("Common Normal")..{
        Name="VOLT26Disclaimer",
        Text="This is an unofficial, non-profit fan-made theme created strictly for personal enjoyment. All music, logos, art direction, and references to the Persona series\nbelong entirely to ATLUS / SEGA. This project is not affiliated with, endorsed by, or monetized in any way by ATLUS. All rights reserved to their respective owners.",
        InitCommand=function(self)
            self:y(_screen.h/2 - 24):valign(1):horizalign(center)
                :zoom(0.34):wrapwidthpixels((_screen.w * 0.94) / 0.34)
                :diffuse(color("#D0D0D0")):shadowlength(2)
        end,
        OnCommand=function(self)
            if not introActive then self:visible(false) return end
            self:sleep(logoHit - 0.20):linear(0.20):diffusealpha(0)
        end,
    }

    overlay[#overlay+1] = Def.Sprite{
        Name="VOLT26IntroLogo",
        Texture=THEME:GetPathG("", "VOLT26/logo_main (doubleres).png"),
        InitCommand=function(self) self:zoom(2.2):diffusealpha(0) end,
        OnCommand=function(self)
            if not introActive then self:visible(false) return end
            self:sleep(logoHit - 0.62)
                :diffusealpha(1):accelerate(0.42):zoom(0.26)
                :decelerate(0.20):zoom(0.30)
                :glow(1, 1, 1, 0.65):linear(0.18):glow(1, 1, 1, 0)
                :sleep(logoFade - logoHit - 0.18):linear(0.20):diffusealpha(0)
        end,
    }

    overlay[#overlay+1] = Def.Sound{
        Name="VOLT26IntroKnifeSound",
        File=THEME:GetPathG("", "VOLT26/knife.ogg"),
        OnCommand=function(self)
            if introActive then self:sleep(logoHit):queuecommand("PlayImpact") end
        end,
        PlayImpactCommand=function(self) self:play() end,
    }

    return overlay
end

-- Handheld idle motion. Pairs of incommensurate sines never settle into a visible
-- repeat within a title session, so the parked shot keeps breathing. Amplitudes are
-- in meters for the eye offsets and degrees for the angles.
local sway = {}
local function UpdateSway(t)
    sway.x     = (math.sin(t*0.37) * 0.6 + math.sin(t*0.83 + 1.7) * 0.4) * 0.14
    sway.y     = (math.sin(t*0.51 + 0.6) * 0.6 + math.sin(t*1.13 + 2.3) * 0.4) * 0.10
    sway.z     = math.sin(t*0.29 + 2.1) * 0.30
    sway.yaw   = (math.sin(t*0.41 + 0.9) * 0.6 + math.sin(t*0.97 + 2.8) * 0.4) * 0.5
    sway.pitch = (math.sin(t*0.47 + 1.4) * 0.6 + math.sin(t*1.07 + 0.3) * 0.4) * 0.4
    sway.roll  = (math.sin(t*0.33 + 2.4) * 0.6 + math.sin(t*0.79 + 1.1) * 0.4) * 0.7
end
UpdateSway(0)

local room = Def.ActorFrame{
    Name="Room",
    InitCommand=function(self) self:xy(current[1],current[2]):z(current[3]) end,
}
for part=0,modelParts-1 do
    local filename = part==0 and "city.txt" or ("city-"..part..".txt")
    local path = THEME:GetPathG("", "VOLT26/TitleTravelCity/"..filename)
    room[#room+1] = Def.Model{
        Meshes=path, Materials=path, Bones=path,
        InitCommand=function(self) self:cullmode("CullMode_None"):zbuffer(true) end,
    }
end
room[#room+1] = CreateCountdownBillboard()
local starBannerPath = THEME:GetPathB("ScreenTitleMenu", "underlay/StarBanner.lua")
for _, banner in ipairs(bannerSurfaces) do
    local artwork = LoadActor(starBannerPath, banner.caption)
    local overscan = banner.overscan or 1.01
    local zoomX = banner.width * overscan * modelUnits / artwork.Width
    local zoomY = banner.height * overscan * modelUnits / artwork.Height
    for layer, actor in ipairs(artwork.Layers) do
        -- Each layer steps one more lift toward the street; coplanar layers would z-fight.
        local lift = (banner.lift or 0.02) * layer
        room[#room+1] = Def.ActorFrame{
            Name="Banner_"..banner.name.."_"..layer,
            InitCommand=function(self)
                self:xy((banner.x+banner.nx*lift)*modelUnits, (-banner.y+banner.ny*lift)*modelUnits)
                    :z((banner.z+banner.nz*lift)*modelUnits)
                    :rotationx(banner.rx):rotationy(banner.ry)
                    :zoomx(banner.mirrored and -zoomX or zoomX):zoomy(zoomY)
            end,
            actor,
        }
    end
end

return Def.ActorFrame{
    Name="VOLT26_3DPrototype",
    InitCommand=function(self) self:Center() end,
    VOLT26_HoverMessageCommand=function(self, params)
        local idx = params and params.idx
        if diving then return end
        if type(idx) ~= "number" or idx%1 ~= 0 or idx < 0 or idx > 4 or idx == selected then return end
        bankDirection = idx > selected and 1 or -1
        selected = idx
        start, target, elapsed = current, positions[idx+1], 0
        activeDuration, arrivalDelay = duration, 0
        introActive = false
    end,
    MenuStartP1MessageCommand=InteractWithCountdown,
    MenuStartP2MessageCommand=InteractWithCountdown,
    OnCommand=function(self)
        _G.Volt26CityIntroPlayed = true
        if introActive then
            RedirectIntroInput(true)
            Trace("[VOLT26 3D] Sky opening with credits started")
        end
        local roll = self:GetChild("Perspective"):GetChild("CameraRoll")
        local pitch = roll:GetChild("CameraEye"):GetChild("CameraPitch")
        local yaw = pitch:GetChild("CameraYaw")
        local place = yaw:GetChild("Room")
        self:SetUpdateFunction(function(frame, dt)
            if arrivalDelay > 0 then
                local consumed = math.min(arrivalDelay, dt)
                arrivalDelay, dt = arrivalDelay-consumed, dt-consumed
            end
            clock = clock + dt
            UpdateSway(clock)
            elapsed = math.min(activeDuration, elapsed + dt)
            local t = elapsed / activeDuration
            local smooth = diving and t*t or SmootherStep(t)
            local blended
            if introActive then
                if elapsed < introLandingStart then
                    local introT = SmootherStep(elapsed / introLandingStart)
                    blended = BlendPose(skyPose, overviewPose, introT)
                else
                    local landingT = SmootherStep((elapsed - introLandingStart)
                        / (introDuration - introLandingStart))
                    blended = BlendPose(overviewPose, positions[1], landingT)
                end
            else
                blended = BlendPose(start, target, smooth)
                -- Preserve the settled Dutch angle and blend interrupted roll continuously.
                blended[5] = blended[5]
                    + (diving and 0 or bankDirection*7)*math.sin(math.pi*t)^2
            end
            current = blended
            -- Idle motion rides on top of the pose so it never fights the transition.
            roll:rotationz(blended[5] + sway.roll)
            pitch:rotationx(blended[6] + sway.pitch)
            yaw:rotationy(blended[4] + sway.yaw)
            place:xy(blended[1] - sway.x*modelUnits, blended[2] + sway.y*modelUnits)
                 :z(blended[3] + sway.z*modelUnits)
            if introActive and elapsed >= activeDuration then
                introActive = false
                RedirectIntroInput(false)
                Trace("[VOLT26 3D] Sky opening with credits completed")
            end
        end)
    end,
    -- The screen plays Off on its children the moment it starts transitioning out, so
    -- this is where choosing an entry lands. The update function keeps running: the
    -- screen is alive until its wipe finishes, and the dive has to play under it.
    OffCommand=function(self)
        if introActive then RedirectIntroInput(false) end
        if diving then return end
        diving, introActive = true, false
        start, target, elapsed = current, positions[selected+1].dive, 0
        activeDuration, arrivalDelay = diveDuration, 0
        Trace("[VOLT26 3D] Dive into banner "..(selected+1))
    end,
    Def.Quad{
        InitCommand=function(self) self:zoomto(SCREEN_WIDTH,SCREEN_HEIGHT):diffuse(color("#FF0000")) end,
    },
    Def.ActorFrame{
        Name="Perspective",
        InitCommand=function(self) self:fov(fov):vanishpoint(SCREEN_CENTER_X,SCREEN_CENTER_Y) end,
        Def.ActorFrame{
            -- Roll is a screen-plane tilt, so it stays outside the eye offset.
            Name="CameraRoll",
            InitCommand=function(self) self:rotationz(current[5] + sway.roll) end,
            Def.ActorFrame{
                -- Menu FOV is horizontal, so this lands the origin of everything below
                -- exactly on the engine eye point, and worldScale shrinks the city into
                -- the fixed far-plane budget. Yaw and pitch live inside it and
                -- therefore rotate around the eye instead of orbiting the screen plane.
                Name="CameraEye",
                InitCommand=function(self)
                    self:zoom(worldScale):z(SCREEN_WIDTH/(2*math.tan(math.rad(fov/2))))
                end,
                Def.ActorFrame{
                    -- Separate frames, innermost first: the room is yawed, then
                    -- pitched. One frame carrying both would leave the order to the
                    -- engine's rotation sequence.
                    Name="CameraPitch",
                    InitCommand=function(self) self:rotationx(current[6] + sway.pitch) end,
                    Def.ActorFrame{
                        Name="CameraYaw",
                        InitCommand=function(self) self:rotationy(current[4] + sway.yaw) end,
                        room,
                    },
                },
            },
        },
    },
    CreateOpeningCredits(),
}
