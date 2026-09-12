-- Full-screen city. Native ScreenTitleMenu owns selection and action routes.
local modelUnits = 35 -- baked into the meshes by tools/import-title-obj.py
local modelParts = 4  -- must match `model_parts` in import-info.json
local fov = 65
local duration = 1.1
local introDuration = 2.8

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
-- converter writes palette-only UVs, so the 90 frame loop rides on a separate actor
-- pinned to those bounds. Def.Model flips Y and a Sprite does not, hence the negated
-- centre height.
local playBanner = {
    name = "play", rx = 0, ry = 90, nx = 1, ny = 0, nz = 0,
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

-- OBJ positions are Y-up; Sprite positions negate height, preserving OBJ Z.
-- Each surface gets its own normal offset and orientation. Width follows the
-- camera's right vector, so Edit/Options read along +X and Exit along -Z.
local movieBanners = {
    playBanner,
    {name = "edit", x = 10.9534255, y = 13.896204, z = -19.341549,
     width = 8.203149, height = 2.654254, rx = 0, ry = 0,
     nx = 0, ny = 0, nz = 1},
    {name = "options", x = -0.012378, y = 0.405, z = -48,
     width = 7.735, height = 2.650002, rx = -90, ry = 0,
     nx = 0, ny = -1, nz = 0},
    {name = "exit", x = 6.615, y = 21.157425, z = -72,
     width = 8.190002, height = 2.650002, rx = 0, ry = 90,
     nx = -1, ny = 0, nz = 0},
}

local introActive = not _G.Volt26CityIntroPlayed
local openingPose = {0, 9.5*modelUnits, -25*modelUnits, 10, -6, 0}
local current = introActive and openingPose or positions[1]
local start, target = current, positions[1]
local activeDuration = introActive and introDuration or duration
local elapsed = introActive and 0 or activeDuration
local arrivalDelay = introActive and _G.Volt26InitHandoff == true and 0.9 or 0
local selected = 0
local bankDirection = 1
local clock = 0
local diving = false

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
for _, banner in ipairs(movieBanners) do
room[#room+1] = Def.Sprite{
    Name="Banner_"..banner.name,
    Texture=THEME:GetPathG("", "VOLT26/TitleTravelCity/banner_"..banner.name..".avi"),
    InitCommand=function(self)
        local overscan, lift = banner.overscan or 1.01, banner.lift or 0.02
        local width = banner.width * overscan * modelUnits
        self:zoomto(banner.mirrored and -width or width,
                    banner.height * overscan * modelUnits)
            :xy((banner.x+banner.nx*lift)*modelUnits, (-banner.y+banner.ny*lift)*modelUnits)
            :z((banner.z+banner.nz*lift)*modelUnits)
            :rotationx(banner.rx):rotationy(banner.ry)
            :zbuffer(true) -- otherwise it draws through the facade from other stops
        local texture = self:GetTexture()
        if texture and texture.SetLooping then texture:SetLooping(true) end
    end,
}
end

return Def.ActorFrame{
    Name="VOLT26_3DPrototype",
    InitCommand=function(self) self:Center() end,
    VOLT26_HoverMessageCommand=function(self, params)
        local idx = params and params.idx
        if diving then return end
        if type(idx) ~= "number" or idx%1 ~= 0 or idx < 0 or idx > 3 or idx == selected then return end
        bankDirection = idx > selected and 1 or -1
        selected = idx
        start, target, elapsed = current, positions[idx+1], 0
        activeDuration, arrivalDelay = duration, 0
        introActive = false
    end,
    OnCommand=function(self)
        _G.Volt26CityIntroPlayed = true
        if introActive then Trace("[VOLT26 3D] Opening camera flight started") end
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
            -- Travel eases in and out; the dive only accelerates, so it reads as a rush.
            local smooth = diving and t*t or t*t*t*(t*(t*6-15)+10)
            local blended = {}
            for i=1,4 do blended[i] = start[i] + (target[i]-start[i])*smooth end
            blended[6] = start[6] + (target[6]-start[6])*smooth
            -- Preserve the settled Dutch angle and blend interrupted roll continuously.
            blended[5] = start[5] + (target[5]-start[5])*smooth
                + (diving and 0 or bankDirection*(introActive and 3 or 7))*math.sin(math.pi*t)^2
            current = blended
            -- Idle motion rides on top of the pose so it never fights the transition.
            roll:rotationz(blended[5] + sway.roll)
            pitch:rotationx(blended[6] + sway.pitch)
            yaw:rotationy(blended[4] + sway.yaw)
            place:xy(blended[1] - sway.x*modelUnits, blended[2] + sway.y*modelUnits)
                 :z(blended[3] + sway.z*modelUnits)
            if introActive and elapsed >= activeDuration then
                introActive = false
                Trace("[VOLT26 3D] Opening camera flight completed")
            end
        end)
    end,
    -- The screen plays Off on its children the moment it starts transitioning out, so
    -- this is where choosing an entry lands. The update function keeps running: the
    -- screen is alive until its wipe finishes, and the dive has to play under it.
    OffCommand=function(self)
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
