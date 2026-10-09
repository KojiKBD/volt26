-- ScreenSelectProfile backdrop: the "WANTED" layout.
--
-- The pieces are exported from the Illustrator design (1920x1080 artboard) into
-- Graphics/VOLT26/ProfileSelect: the red field with its star texture and the
-- black lightning bolt as one plate, then the white dots, the three sparkles and
-- the WANTED lettering, each cropped and placed at the position it had on the
-- artboard.  The player cards live in the underlay (PlayerFrame.lua).

local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080

local function art(name, box)
	return Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/ProfileSelect/" .. name .. ".png"),
		InitCommand=function(self)
			self:xy((box.x + box.w / 2) * sx, (box.y + box.h / 2) * sy):zoomto(box.w * sx, box.h * sy)
		end,
	}
end

-- Artboard boxes of the cropped pieces (x, y = top-left on the 1920x1080 board).
local boxes = {
	dots     = {x = 690,  y = 347, w = 615, h = 445},
	sparkle1 = {x = 617,  y = 136, w = 45,  h = 45},
	sparkle2 = {x = 1352, y = 136, w = 56,  h = 56},
	sparkle3 = {x = 1170, y = 0,   w = 45,  h = 37},
	wanted   = {x = 694,  y = 85,  w = 510, h = 191},
}

local t = Def.ActorFrame{
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/ProfileSelect/bg.png"),
		InitCommand=function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT) end,
	},
	art("dots", boxes.dots)..{
		OnCommand=function(self) self:bob():effectmagnitude(0, 3, 0):effectperiod(4) end,
	},
}

-- The sparkles twinkle out of step with each other.
for i = 1, 3 do
	t[#t+1] = art("sparkle" .. i, boxes["sparkle" .. i])..{
		OnCommand=function(self)
			self:pulse():effectmagnitude(0.75, 1.15, 1):effectperiod(1.6 + i * 0.35)
				:effectoffset(i * 0.4)
		end,
	}
end

-- WANTED drops in, then sways a little.
t[#t+1] = art("wanted", boxes.wanted)..{
	OnCommand=function(self)
		self:addy(-40):diffusealpha(0):decelerate(0.3):addy(40):diffusealpha(1)
			:queuecommand("Sway")
	end,
	SwayCommand=function(self)
		self:wag():effectmagnitude(0, 0, 1.5):effectperiod(3)
	end,
}

return t
