-- One choice on ScreenSelectPlayMode / ScreenSelectPlayMode2.
--
-- ScreenSelectMaster owns the cursor and places these actors at the
-- IconChoice<name> coordinates in metrics.ini; each one draws itself as a row
-- in the choice column and answers the engine's GainFocus/LoseFocus.  The panel
-- that describes the focused choice lives in the screen's underlay.

local Chrome = LoadActor(THEME:GetPathB("", "_volt26 select chrome"))

local gc = Var("GameCommand")
local name = gc:GetName()

local card = { w = 400, h = 56 }

-- Choice names are shared by both play-mode screens, so both read their strings
-- out of the one section rather than relying on the screens' metric fallback.
local function String(key, fallback)
	if THEME:HasString("ScreenSelectPlayMode", key) then
		return THEME:GetString("ScreenSelectPlayMode", key)
	end
	return fallback or ""
end

local accent = Chrome.Accent()

local af = Chrome.Box{ name="Choice"..name, w=card.w, h=card.h }

af.InitCommand=function(self)
	-- The engine positions this actor; everything inside it is drawn from its
	-- top-left corner.
	self:queuecommand("LoseFocus")
end
af.GainFocusCommand=function(self)
	Chrome.SetBoxFocus(self, true, accent)
	self:GetChild("Name"):stoptweening():linear(0.08):diffuse(Chrome.Color.Text)
	self:GetChild("Subtitle"):stoptweening():linear(0.08):diffuse(Chrome.Color.Dim)
	self:GetChild("Marker"):stoptweening():linear(0.08):diffusealpha(1)
end
af.LoseFocusCommand=function(self)
	Chrome.SetBoxFocus(self, false, accent)
	self:GetChild("Name"):stoptweening():linear(0.08):diffuse(Chrome.Color.Dim)
	self:GetChild("Subtitle"):stoptweening():linear(0.08):diffuse(Chrome.Color.Faint)
	self:GetChild("Marker"):stoptweening():linear(0.08):diffusealpha(0)
end
af.OffCommand=function(self) self:linear(0.15):diffusealpha(0) end

-- the accent rule that marks the focused row
af[#af+1] = Def.Quad{
	Name="Marker",
	InitCommand=function(self)
		self:align(0,0):xy(1,1):zoomto(3, card.h-2):diffuse(accent):diffusealpha(0)
	end,
}

af[#af+1] = Chrome.Display{
	name="Name", text=String(name, name):upper(), px=24,
	x=20, y=11, width=card.w-40,
}

af[#af+1] = Chrome.Label{
	name="Subtitle", text=String(name.."Subtitle"), px=9,
	x=21, y=36, width=card.w-42, color=Chrome.Color.Faint,
}

return af
