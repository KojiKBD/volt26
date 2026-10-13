-- Native ribbon geometry from Graphics/VOLT26/line.svg.
-- Keep the supplied SVG as the editable source for this mesh.
local sourceWidth, sourceHeight = 2293.38, 1055.48
local points = {
    {0,357.32}, {1176.91,0}, {1077.45,406.34}, {2162.54,101.42},
    {1697.37,635.74}, {2293.38,513.29}, {2036.87,1055.48},
    {2130.61,601.15}, {1523.37,772.9}, {1868.55,297.23},
    {653.27,759.14}, {1050.9,175.77}, {56.28,610.86},
}
-- Pair the two edges at each bend, walking from the left tail to the bottom tip.
-- Revealing consecutive cross-sections forms the ribbon along its zigzag path.
local sections = {{1,13}, {2,12}, {3,11}, {4,10}, {5,9}, {6,8}, {7,7}}
local scale = math.max(SCREEN_WIDTH * 1.25 / sourceWidth, SCREEN_HEIGHT / sourceHeight)
local tint = color("#FF000D")

local function Midpoint(section)
    local a, b = points[section[1]], points[section[2]]
    return {(a[1]+b[1])/2, (a[2]+b[2])/2}
end

local lengths, totalLength = {}, 0
for i=1,#sections-1 do
    local a, b = Midpoint(sections[i]), Midpoint(sections[i+1])
    lengths[i] = math.sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
    totalLength = totalLength + lengths[i]
end

local function Vertex(point)
    return {{(point[1]-sourceWidth/2)*scale, (point[2]-sourceHeight/2)*scale, 0}, tint}
end

local function Interpolate(a, b, amount)
    return {a[1]+(b[1]-a[1])*amount, a[2]+(b[2]-a[2])*amount}
end

local function RevealVertices(progress, direction)
    local remaining, vertices = progress * totalLength, {}
    for step=1,#sections-1 do
        local index = direction == -1 and #sections-step or step
        local from = direction == -1 and sections[index+1] or sections[index]
        local to = direction == -1 and sections[index] or sections[index+1]
        local amount = math.min(1, math.max(0, remaining / lengths[index]))
        local a, b = points[from[1]], points[from[2]]
        local c = Interpolate(b, points[to[2]], amount)
        local d = Interpolate(a, points[to[1]], amount)
        for _, point in ipairs({a,d,c, a,c,b}) do
            vertices[#vertices+1] = Vertex(point)
        end
        remaining = math.max(0, remaining - lengths[index])
        if amount < 1 then break end
    end
    return vertices
end

return Def.ActorFrame{
    Name="LineTransition",
    InitCommand=function(self) self:Center():visible(false):draworder(-1) end,
    RevealCommand=function(self, params)
        local direction = params and params.direction == -1 and -1 or 1
        local drawDuration = params and params.confirm and 0.28 or 0.48
        local holdDuration, fadeDuration = 0.04, 0.10
        local elapsed, mesh = 0, self:GetChild("Ribbon")
        -- Replace an interrupted reveal, without queued tweens or moving artwork.
        self:stoptweening():visible(true):diffusealpha(1)
        mesh:SetVertices(RevealVertices(0, direction))
        self:SetUpdateFunction(function(frame, delta)
            elapsed = elapsed + (delta or 0)
            if elapsed <= drawDuration then
                mesh:SetVertices(RevealVertices(elapsed / drawDuration, direction))
            elseif elapsed < drawDuration + holdDuration + fadeDuration then
                mesh:SetVertices(RevealVertices(1, direction))
                frame:diffusealpha(1 - math.max(0, elapsed-drawDuration-holdDuration) / fadeDuration)
            else
                frame:visible(false):SetUpdateFunction(nil)
            end
        end)
    end,
    Def.ActorMultiVertex{
        Name="Ribbon",
        InitCommand=function(self)
            self:SetDrawState{Mode="DrawMode_Triangles"}
            self:SetVertices(RevealVertices(0, 1))
        end,
    },
}
