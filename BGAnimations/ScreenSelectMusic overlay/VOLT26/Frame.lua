local H = ...

local af = Def.ActorFrame{Name="Frame"}

for i=1,34 do
	local x = 385 + (i%17)*12
	local y = 8 + math.floor((i-1)/17)*11 + (i%3)*2
	af[#af+1] = Def.Quad{
		InitCommand=function(self) self:xy(x,y):zoomto(3+(i%3),3+(i%2)):rotationz((i%5)*9):diffuse(i%4==0 and H.P1 or H.Black) end,
	}
end

for i=1,10 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:align(0,0):xy(8+i*18,115+(i%3)*4):zoomto(10+(i%4)*5,2):rotationz(-7+(i%4)*3)
				:diffuse(i%3==0 and H.P1 or H.White):diffusealpha(0.7)
		end,
	}
end

-- Dedicated VOLT26 title artwork, authored with its own skew and subtitle.
af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("", "VOLT26/select_song_wheel.png"),
	InitCommand=function(self) self:align(0,0):xy(18,8):setsize(235,93) end,
}

af[#af+1] = Def.BitmapText{
	Font=H.Font, Text="VOLT//26",
	InitCommand=function(self) self:xy(788,28):zoom(0.08):diffuse(H.Black):rotationz(3) end,
}

-- Broken divider strokes: short independent segments rather than enclosing boxes.
for i=0,5 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self) self:align(0,0):xy(278+i*57,150+(i%2)*2):zoomto(42,2):rotationz((i%3)-1):diffuse(H.White):diffusealpha(0.55) end,
	}
end

return af
