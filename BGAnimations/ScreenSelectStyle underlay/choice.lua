-- One choice of ScreenSelectStyle, drawn as a full-screen face from the
-- owner's Illustrator mockups (Graphics/VOLT26/StyleSelect, 1920x1080 faces):
-- the red field with the character art, the cutout label, and two arrows that
-- point to the previous and next choice.  Only the focused face is visible.
--
-- default.lua owns the choices, credits and input and drives this file through
-- GainFocus / LoseFocus / Enable / Chosen / NotChosen; `shared.direction` tells
-- a face which way the cursor moved so it can slide in from that side.

local args = ...
local choiceName = args[1].name
local shared = args[3] or { direction = 1 }

local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080

local function asset(name)
	return THEME:GetPathG("", "VOLT26/StyleSelect/" .. name .. ".png")
end

-- Artboard geometry of each face (pixels on its 1920x1080 face).  Solo has no
-- mockup: it borrows the single face and sets its label in cutout lettering.
local labels = {
	single = {x = 117, y = 653, w = 773, h = 339},
	versus = {x = 98,  y = 561, w = 796, h = 399},
	double = {x = 216, y = 671, w = 633, h = 277},
}
local face = labels[choiceName] and choiceName or "single"
local label = labels[face]
local labelX, labelY = (label.x + label.w / 2) * sx, (label.y + label.h / 2) * sy

-- The arrows, as drawn on every face: "next" below right, "previous" above
-- left.  Each bobs along the way it points.
local arrows = {
	{points = {626.81, 916.93, 558.56, 949.35, 647.1, 1011.71}, dir = {1, 1}},
	{points = {411.89, 686.96, 478.95, 652.16, 388.27, 592.95}, dir = {-1, -1}},
}

local function arrow(spec)
	local p = spec.points
	local black, white = {0, 0, 0, 1}, {1, 1, 1, 1}
	local function v(i, c) return {{p[i] * sx, p[i + 1] * sy, 0}, c} end
	return Def.ActorFrame{
		OnCommand=function(self)
			self:bob():effectmagnitude(spec.dir[1] * 5 * sx, spec.dir[2] * 5 * sy, 0):effectperiod(0.9)
		end,
		Def.ActorMultiVertex{
			InitCommand=function(self)
				self:SetDrawState{Mode="DrawMode_Triangles"}
				self:SetVertices{ v(1, black), v(3, black), v(5, black) }
			end,
		},
		Def.ActorMultiVertex{
			InitCommand=function(self)
				self:SetDrawState{Mode="DrawMode_LineStrip"}:SetLineWidth(2)
				self:SetVertices{ v(1, white), v(3, white), v(5, white), v(1, white) }
			end,
		},
	}
end

local slide = 120 * sx

local labelActor
if labels[choiceName] then
	labelActor = Def.Sprite{
		Name="Label",
		Texture=asset("label_" .. face),
		InitCommand=function(self)
			self:xy(labelX, labelY):zoomto(label.w * sx, label.h * sy)
		end,
	}
else
	labelActor = VOLT26.Cutout.CreateSlot{
		x = labelX, y = labelY, maxW = label.w * sx, maxH = label.h * sy,
		halign = 0.5, valign = 0.5, opts = { base = 120 * sy, tiltDeg = -12 },
	}..{
		Name="Label",
		OnCommand=function(self)
			self:playcommand("CutoutSet", {text = THEME:GetString("ScreenSelectStyle",
				choiceName:gsub("^%l", string.upper))})
		end,
	}
end

return Def.ActorFrame{
	InitCommand=function(self)
		self:aux(0):visible(false)
	end,

	-- The new face slides in from the side the cursor moved towards; its art
	-- travels further than the label for a little parallax, and the label slams
	-- down into place.
	GainFocusCommand=function(self)
		local dir = shared.direction or 1
		self:finishtweening():visible(true):diffusealpha(1)
		local art, lab = self:GetChild("Art"), self:GetChild("Label")
		art:finishtweening():x(SCREEN_WIDTH / 2 + dir * slide * 2):decelerate(0.25):x(SCREEN_WIDTH / 2)
		lab:finishtweening():zoom(1.35):rotationz(-dir * 8):diffusealpha(0)
			:sleep(0.08):decelerate(0.16):zoom(1):rotationz(0):diffusealpha(1)
	end,
	LoseFocusCommand=function(self)
		if not self:GetVisible() then return end
		local dir = shared.direction or 1
		self:finishtweening():linear(0.18):diffusealpha(0):queuecommand("Hide")
		self:GetChild("Art"):finishtweening():linear(0.18):x(SCREEN_WIDTH / 2 - dir * slide)
	end,
	HideCommand=function(self) self:visible(false) end,

	EnableCommand=function(self) end,

	ChosenCommand=function(self)
		self:GetChild("Label"):finishtweening():decelerate(0.12):zoom(1.15):accelerate(0.2):zoom(1)
		self:finishtweening():sleep(0.3):linear(0.12):diffusealpha(0)
	end,
	NotChosenCommand=function(self)
		self:finishtweening():visible(false)
	end,

	Def.Sprite{
		Name="Art",
		Texture=asset("face_" .. face),
		InitCommand=function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT) end,
	},
	arrow(arrows[1]),
	arrow(arrows[2]),
	labelActor,
}
