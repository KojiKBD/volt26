-- Screen-space sky behind the city, using the machine's local clock.
local width, height = SCREEN_WIDTH, SCREEN_HEIGHT
local performance = VOLT26.Performance.IsEnabled()
local starCount = performance and 36 or 72
local stops = {
    {hour=0,  top="#050A24", middle="#111C46", bottom="#263457", stars=1},
    {hour=5,  top="#101735", middle="#34345E", bottom="#936078", stars=0.85},
    {hour=7,  top="#657CBD", middle="#D59BB1", bottom="#FFD3AA", stars=0},
    {hour=10, top="#287CB6", middle="#70B7D8", bottom="#C7E5E8", stars=0},
    {hour=15, top="#256BA3", middle="#69A4C8", bottom="#D6DBDB", stars=0},
    {hour=18, top="#514B86", middle="#C07891", bottom="#FFB477", stars=0},
    {hour=20, top="#171A43", middle="#4B3D71", bottom="#AD6478", stars=0.55},
    {hour=22, top="#050A24", middle="#111C46", bottom="#263457", stars=1},
    {hour=24, top="#050A24", middle="#111C46", bottom="#263457", stars=1},
}

for _, stop in ipairs(stops) do
    stop.top, stop.middle, stop.bottom = color(stop.top), color(stop.middle), color(stop.bottom)
end

local function BlendColor(a, b, amount)
    local result = {}
    for i=1,4 do result[i] = a[i] + (b[i] - a[i]) * amount end
    return result
end

local function ReadSky()
    local hour = Hour() + Minute() / 60
    for i=1,#stops-1 do
        local a, b = stops[i], stops[i+1]
        if hour >= a.hour and hour < b.hour then
            local amount = (hour - a.hour) / (b.hour - a.hour)
            amount = amount * amount * (3 - 2 * amount)
            return BlendColor(a.top, b.top, amount),
                BlendColor(a.middle, b.middle, amount),
                BlendColor(a.bottom, b.bottom, amount),
                a.stars + (b.stars - a.stars) * amount
        end
    end
end

local starVisibility = 0
local function RefreshSky(frame)
    local top, middle, bottom, stars = ReadSky()
    frame:GetChild("UpperSky"):diffusetopedge(top):diffusebottomedge(middle)
    frame:GetChild("LowerSky"):diffusetopedge(middle):diffusebottomedge(bottom)
    starVisibility = stars
    frame:GetChild("Stars"):diffusealpha(stars):visible(stars > 0.001)
end

local sky = Def.ActorFrame{
    Name="VOLT26_TimeOfDaySky",
    OnCommand=function(self)
        RefreshSky(self)
        local refreshElapsed = 0
        self:SetUpdateFunction(function(frame, delta)
            refreshElapsed = refreshElapsed + (delta or 0)
            if refreshElapsed >= 15 then
                refreshElapsed = refreshElapsed % 15
                RefreshSky(frame)
            end
        end)
    end,
    OffCommand=function(self) self:SetUpdateFunction(nil) end,
    Def.Quad{
        Name="UpperSky",
        InitCommand=function(self)
            self:y(-height/4):zoomto(width, height/2)
        end,
    },
    Def.Quad{
        Name="LowerSky",
        InitCommand=function(self)
            self:y(height/4):zoomto(width, height/2)
        end,
    },
}

-- Deterministic placement leaves the game's random sequence untouched.
local stars, points = Def.ActorFrame{Name="Stars"}, {}
for i=1,starCount do
    local x = ((i * 0.61803398875) % 1 - 0.5) * width
    local normalizedY = (i * 0.41421356237) % 1
    local y = (normalizedY * 0.84 - 0.5) * height
    local size = (i % 5 == 0 and 2.6 or 1.3) * height / 480
    points[i] = {phase=i * 2.39996, speed=0.65 + (i % 7) * 0.12,
        brightness=0.9 - normalizedY * 0.45}
    stars[#stars+1] = Def.Quad{
        Name="Star"..i,
        InitCommand=function(self)
            self:xy(x,y):zoomto(size,size):rotationz(45)
                :diffuse(0.87,0.93,1,points[i].brightness)
        end,
    }
end

stars.OnCommand=function(self)
    local actors = {}
    for i=1,starCount do actors[i] = self:GetChild("Star"..i) end
    local elapsed, tick = 0, 0
    self:SetUpdateFunction(function(_, delta)
        elapsed, tick = elapsed + (delta or 0), tick + (delta or 0)
        if starVisibility <= 0.001 or tick < (performance and 0.15 or 0.05) then return end
        tick = 0
        for i, point in ipairs(points) do
            local shimmer = 0.64 + 0.36 * math.sin(elapsed * point.speed + point.phase)
            actors[i]:diffusealpha(point.brightness * shimmer)
        end
    end)
end
stars.OffCommand=function(self) self:SetUpdateFunction(nil) end
sky[#sky+1] = stars

return sky
