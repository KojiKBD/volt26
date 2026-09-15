-- Full-screen city. Native ScreenTitleMenu owns selection and action routes.
local modelUnits = 35 -- baked into the meshes by tools/import-title-obj.py
local modelParts = 4  -- must match `model_parts` in import-info.json
local fov = 65
local duration = 1.1
local introDuration = VOLT26.TitleMenu.GetIntroDurationSeconds()
-- Preserve the original 2.25-second landing while the closing logo is visible.
local introLandingStart = introDuration - 2.25

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
    -- A final navigation-only stop reveals the credits laid flat on the road.  The
    -- higher, tighter overhead pose is local to this stop so both portrait textures
    -- fit in frame without changing the established banner camera language.
    {x =  0.000, y = 82.500, z =  0.080, nx =  0, ny =  0, nz = 1, tx = 0, ty =  1,
     side = -1, roll = 3, standOff = 21, streetOffset = 2.5},
}

local positions, dives = {}, {}
for i, banner in ipairs(banners) do
    local bannerStandOff = banner.standOff or standOff
    local bannerStreetOffset = banner.streetOffset or streetOffset
    local eyeX = banner.x + banner.nx*bannerStandOff
        + banner.tx*banner.side*bannerStreetOffset
    local eyeY = banner.y + banner.ny*bannerStandOff
        + banner.ty*banner.side*bannerStreetOffset
    local eyeZ = banner.z + banner.nz*bannerStandOff
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

-- These are genuine world-space sprites rather than a screen overlay.  At every
-- earlier stop the portrait is foreshortened into the distant road; only the final
-- overhead pose makes it legible.  Both PNGs have transparent backgrounds, so the
-- asphalt backing hides the crosswalk underneath them.  This small group is drawn
-- without depth testing after the city: that makes the road decal deterministic
-- instead of depending on the four model chunks' depth precision.
local thanksSurface = {
    x = 0.0, y = 0.08, z = -82.5,
    width = 7.4,
}

local function CreateThanksRoadElement()
    local seriousWidth, seriousHeight = 1578, 2169
    local memeWidth, memeHeight = 1578, 2607

    return Def.ActorFrame{
        Name="VOLT26_ThanksRoadElement",
        InitCommand=function(self)
            self:xy(thanksSurface.x * modelUnits, -thanksSurface.y * modelUnits)
                :z(thanksSurface.z * modelUnits)
                :rotationx(-90)
        end,
        Def.Quad{
            Name="ThanksRoadBacking",
            InitCommand=function(self)
                local height = thanksSurface.width * memeHeight / memeWidth + 0.3
                self:zoomto((thanksSurface.width + 0.3) * modelUnits, height * modelUnits)
                    :diffuse(color("#484A4D")):ztest(false):zwrite(false)
            end,
        },
        Def.Sprite{
            Name="SeriousThanks",
            Texture=THEME:GetPathG("", "VOLT26/Serious_Thanks.png"),
            InitCommand=function(self)
                local height = thanksSurface.width * seriousHeight / seriousWidth
                self:zoomto(thanksSurface.width * modelUnits, height * modelUnits)
                    :ztest(false):zwrite(false)
            end,
            VOLT26_ThanksTextureMessageCommand=function(self, params)
                self:visible(not params.showMeme)
            end,
        },
        Def.Sprite{
            Name="ThanksMeme",
            Texture=THEME:GetPathG("", "VOLT26/Thanks_Meme.png"),
            InitCommand=function(self)
                local height = thanksSurface.width * memeHeight / memeWidth
                self:zoomto(thanksSurface.width * modelUnits, height * modelUnits)
                    :visible(false):ztest(false):zwrite(false)
            end,
            VOLT26_ThanksTextureMessageCommand=function(self, params)
                self:visible(params.showMeme)
            end,
        },
    }
end

-- Two road arrows flank the Options banner, placed where the owner marked them on
-- the Options stop screenshot (positions recovered by casting those marks onto the
-- road plane from that camera pose).  Blender X/Y, so OBJ Z is -y.  The far arrow,
-- up the street, points up the screen; the near one points down.  Both lie flat on
-- the road like painted markings, a hair above the crosswalk paint (0.068 m).
local roadArrows = {
    {name = "Up",   x =  2.60, y = 51.95, width = 2.4, rotation =   0},
    {name = "Down", x = -2.75, y = 44.90, width = 1.6, rotation = 180},
}
local arrowLift = 0.08

local function CreateRoadArrows()
    local texture = THEME:GetPathG("", "VOLT26/arrow3d.png")
    local arrowWidth, arrowHeight = 359, 344
    local frame = Def.ActorFrame{Name="VOLT26_RoadArrows"}
    for _, arrow in ipairs(roadArrows) do
        local w = arrow.width * modelUnits
        local h = arrow.width * arrowHeight / arrowWidth * modelUnits
        frame[#frame+1] = Def.ActorFrame{
            Name="RoadArrow"..arrow.name,
            InitCommand=function(self)
                self:xy(arrow.x * modelUnits, -arrowLift * modelUnits)
                    :z(-arrow.y * modelUnits)
                    :rotationx(-90)
            end,
            Def.Sprite{
                Texture=texture,
                InitCommand=function(self)
                    self:zoomto(w, h):rotationz(arrow.rotation):zbuffer(true)
                end,
            },
        }
    end
    return frame
end

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
_G.Volt26TitleIntroActive = introActive
-- Begin above the skyline and descend almost vertically while the screen-space vow
-- remains readable over a strong black dim. The final leg settles on Gameplay.
local skyPose = {0, 125*modelUnits, -30*modelUnits, 0, 0, 12}
local overviewPose = {0, 28*modelUnits, -30*modelUnits, 3, -2, 10}
local current = introActive and skyPose or positions[1]
local start, target = current, positions[1]
local activeDuration = introActive and introDuration or duration
local elapsed = introActive and 0 or activeDuration
local arrivalDelay = 0
local selected = 0
local bankDirection = 1
local clock = 0
local diving = false
local restartingIntro = false
local thanksMemeVisible = false

local function InteractWithNavigationOnlyItem()
    if diving then return end
    if selected == 4 then
        MESSAGEMAN:Broadcast("VOLT26_CountdownNextPhrase")
    elseif selected == 5 then
        thanksMemeVisible = not thanksMemeVisible
        MESSAGEMAN:Broadcast("VOLT26_ThanksTexture", {showMeme=thanksMemeVisible})
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
-- The cat stands on the upper-right edge of the Gameplay banner.  It shares the
-- banner's facade orientation rather than living on the screen, so camera travel,
-- perspective and depth remain consistent with the city.
do
    local height = 2.0
    local width = height * 576 / 744
    room[#room+1] = Def.Sprite{
        Name="GameplayBannerCat",
        Texture=THEME:GetPathG("", "VOLT26/TitleTravelCity/cat_silhouette.png"),
        InitCommand=function(self)
            self:xy(-6.58 * modelUnits, -9.04 * modelUnits)
                :z(-2.60 * modelUnits)
                :rotationy(90)
                :zoomto(width * modelUnits, height * modelUnits)
                :zoomx(-self:GetZoomX())
                :zbuffer(true)
        end,
    }
end
-- The supplied high-resolution silhouette is a zero-thickness plane in the 3D
-- scene. Its feet meet the roof ledge immediately to the right of the Edit banner;
-- depth testing keeps it naturally behind the projecting cornice.
do
    local height = 3.0
    local width = height * 628 / 1065
    room[#room+1] = Def.Sprite{
        Name="Silhouette02",
        Texture=THEME:GetPathG("", "VOLT26/TitleTravelCity/silhouette_02.png"),
        InitCommand=function(self)
            self:xy(19.0 * modelUnits, -13.45 * modelUnits)
                :z(-19.98 * modelUnits)
                :zoomto(width * modelUnits, height * modelUnits)
                :diffuse(color("#FF0000"))
                :zbuffer(true)
        end,
    }
end
-- Second supplied silhouette, crouched on the street-side roof ledge of the Exit
-- building (MAIN_04: facade plane X 6.38, parapet top Y 28.15-28.47). It faces the
-- street like the Exit banner (ry 90) but is not mirrored (owner choice); the
-- parapet hides its lowest edge through the depth buffer.
do
    local width = 5.4
    local height = width * 243 / 632
    local roofY, planeX, centreZ = 28.15, 6.9, -74.0
    room[#room+1] = Def.Sprite{
        Name="SilhouetteExit",
        Texture=THEME:GetPathG("", "VOLT26/TitleTravelCity/silhouette_exit.png"),
        InitCommand=function(self)
            self:xy(planeX * modelUnits, -(roofY + height/2) * modelUnits)
                :z(centreZ * modelUnits)
                :rotationy(90)
                :zoomto(width * modelUnits, height * modelUnits)
                :diffuse(color("#000000"))
                :zbuffer(true)
        end,
    }
end
room[#room+1] = CreateCountdownBillboard()
room[#room+1] = CreateThanksRoadElement()
room[#room+1] = CreateRoadArrows()
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
        if type(idx) ~= "number" or idx%1 ~= 0
        or idx < 0 or idx >= #positions or idx == selected then return end
        bankDirection = idx > selected and 1 or -1
        selected = idx
        start, target, elapsed = current, positions[idx+1], 0
        activeDuration, arrivalDelay = duration, 0
        introActive = false
    end,
    MenuStartP1MessageCommand=InteractWithNavigationOnlyItem,
    MenuStartP2MessageCommand=InteractWithNavigationOnlyItem,
    OnCommand=function(self)
        _G.Volt26CityIntroPlayed = true
        local screen = SCREENMAN:GetTopScreen()
        if screen then
            screen:AddInputCallback(function(event)
                if event and event.type == "InputEventType_FirstPress"
                and event.GameButton == "Back" then
                    restartingIntro = true
                    _G.Volt26CityIntroPlayed = nil
                    _G.Volt26InitHandoff = false
                    RedirectIntroInput(false)
                    Trace("[VOLT26 3D] Back requested; restarting opening vow")
                    screen:SetPrevScreenName("ScreenTitleMenu"):begin_backing_out()
                    return true
                end
                return false
            end)
        end
        if introActive then
            RedirectIntroInput(true)
            Trace("[VOLT26 3D] Opening vow started")
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
                _G.Volt26TitleIntroActive = false
                RedirectIntroInput(false)
                MESSAGEMAN:Broadcast("VOLT26_TitleIntroComplete")
                Trace("[VOLT26 3D] Opening vow completed")
            end
        end)
    end,
    -- The screen plays Off on its children the moment it starts transitioning out, so
    -- this is where choosing an entry lands. The update function keeps running: the
    -- screen is alive until its wipe finishes, and the dive has to play under it.
    OffCommand=function(self)
        if introActive then RedirectIntroInput(false) end
        if restartingIntro then
            self:SetUpdateFunction(nil)
            return
        end
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
}
