-- The song wheel's highlight: drawn by the engine over the row at the wheel's
-- centre.  It is a frame and a translucent wash rather than a solid plate, so
-- the row's own text stays readable underneath.  Figures are the design units
-- of VOLT26.MusicSelection.Wheel; rows start at the wheel origin.
local G = VOLT26.MusicSelection.Wheel
local width = G.Width
local height = G.ItemHeight
local stroke = 3
local accent = color("#e03a2f")

local function rule(x, y, w, h, alpha)
	return Def.Quad{
		InitCommand=function(self)
			self:align(0, 0):xy(x, y):zoomto(w, h):diffuse(accent):diffusealpha(alpha or 1)
		end,
	}
end

return Def.ActorFrame{
	Def.Quad{
		Name="Wash",
		InitCommand=function(self)
			self:align(0, 0.5):zoomto(width, height):diffuse(accent)
				:diffuseshift():effectclock("beatnooffset"):effectperiod(2)
				:effectcolor1(color("#e03a2f33")):effectcolor2(color("#e03a2f14"))
		end,
	},
	rule(0, -height/2, width, stroke),
	rule(0, height/2 - stroke, width, stroke),
	rule(width - stroke, -height/2, stroke, height),
	rule(0, -height/2, 10, height),
}
