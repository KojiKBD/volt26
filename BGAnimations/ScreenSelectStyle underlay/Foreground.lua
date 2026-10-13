-- Draw the existing face texture only over its foreground, above the red ribbon.
local face = ...
local geometry = LoadActor(THEME:GetPathB("ScreenSelectStyle", "underlay/ForegroundGeometry.lua"))
local rectangles = geometry[face]
local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080
local vertices, white = {}, {1,1,1,1}
for _, rect in ipairs(rectangles) do
    local x, y, w, h = unpack(rect)
    for _, point in ipairs({{x,y}, {x+w,y}, {x+w,y+h}, {x,y+h}}) do
        vertices[#vertices+1] = {
            {(point[1]-960)*sx, (point[2]-540)*sy, 0},
            white, {point[1]/1920, point[2]/1080},
        }
    end
end

local art = Def.ActorFrame{
    Name="Art",
    InitCommand=function(self) self:Center() end,
}
if #vertices > 0 then
    art[#art+1] = Def.Sprite{
        Name="TextureSource",
        Texture=THEME:GetPathG("", "VOLT26/StyleSelect/face_"..face..".png"),
        InitCommand=function(self) self:visible(false) end,
    }
    art[#art+1] = Def.ActorMultiVertex{
        OnCommand=function(self)
            local texture = self:GetParent():GetChild("TextureSource"):GetTexture()
            local u = texture:GetImageWidth() / texture:GetTextureWidth()
            local v = texture:GetImageHeight() / texture:GetTextureHeight()
            local mapped = {}
            for i, vertex in ipairs(vertices) do
                mapped[i] = {vertex[1], vertex[2], {vertex[3][1]*u, vertex[3][2]*v}}
            end
            self:SetTexture(texture):SetDrawState{Mode="DrawMode_Quads"}
            self:SetVertices(mapped)
        end,
    }
end
return art
