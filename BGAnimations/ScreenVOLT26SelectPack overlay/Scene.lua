-- The pack step's set dressing, after the owner's "Choose your pack" mockup
-- (Illustrator art exported by tools/pack-select/export_pack_select_art.jsx and
-- cut up by build_pack_select_art.py into Graphics/VOLT26/PackSelect).
--
-- Returns the pieces, each placed by its own screen layer:
--   Back    red ground, the faded VOLT26 logo, the zig-zag stripes; drawn by
--           the background layer (ScreenVOLT26SelectPack background.lua) so
--           the screen's decorations, such as the menu timer, stay on top
--   Splash  the black torn frame the focused jacket sits in; drawn inside the
--           overlay's carousel, in front of the neighbouring jackets and
--           behind the focused one
--   Front   the "CHOOSE YOUR PACK" lettering, sparkles and loose stars
--   Focus   where the focused jacket goes: the splash's window
--
-- All positions are the mockup's, in 1920x1080 design pixels.
--
-- Commands (the overlay plays them on its root; Back, in another layer,
-- gets them through the VOLT26PackScene message, {Phase="Enter"|"Leave"}):
--   SceneEnter {FromSongWheel=bool}  bring the set in
--   SceneLeave                       clear the set off for the song wheel,
--                                    which has its own (shared) backdrop
--   Bump                             a pack change: the frame jolts
-- Idle motion (pulsing sparkles, turning stars, a bobbing title) is left out
-- in PerformanceMode; entrances, exits and the bump stay.
local p = ...
local K = p.K

-- The splash's white window is the focused jacket's frame: the jacket is
-- drawn inside it, square and only slightly turned, so the window's skew
-- shows around it.  The back of the jacket (the song list) is drawn larger,
-- filling the window.
local Focus = { X = 948, Y = 517, Size = 420, ListSize = 460, Tilt = -2 }

local lively = not VOLT26.Performance.IsEnabled()
local LEAVE_SECONDS = 0.22      -- must finish within K.HandoffHold

local function art(name)
	return THEME:GetPathG("", "VOLT26/PackSelect/" .. name .. ".png")
end

-- Back -----------------------------------------------------------------------

local back = Def.ActorFrame{
	Name="SceneBack",
	VOLT26PackSceneMessageCommand=function(self, params)
		self:playcommand(params and params.Phase == "Leave" and "SceneLeave" or "SceneEnter", params)
	end,
	SceneEnterCommand=function(self, params)
		-- Fresh in, the ground is up from the first frame; back from the song
		-- wheel, it comes up over the shared backdrop.
		self:stoptweening():diffusealpha(1)
		if params and params.FromSongWheel then
			self:diffusealpha(0):linear(0.2):diffusealpha(1)
		end
	end,
	SceneLeaveCommand=function(self)
		self:stoptweening():sleep(0.06):linear(LEAVE_SECONDS - 0.06):diffusealpha(0)
	end,
	-- Past the design rectangle in the ground's own red, for non-16:9 screens.
	Def.Quad{
		InitCommand=function(self)
			self:align(0,0):xy(-K.W, -K.H):zoomto(K.W*3, K.H*3):diffuse(color("#a60206"))
		end,
	},
	Def.Sprite{
		Name="Ground", Texture=art("bg"),
		InitCommand=function(self) self:align(0,0):xy(0,0):zoomto(K.W, K.H) end,
	},
	-- A fixed decoration: mostly hidden behind the splash, it shows only
	-- under its bottom edge, behind the pack name.
	Def.Sprite{
		Name="Logo", Texture=art("logo"),
		InitCommand=function(self) self:xy(961, 540) end,
	},
	Def.Sprite{
		Name="Stripes", Texture=art("stripes"),
		InitCommand=function(self) self:xy(1002.5, 540) end,
		SceneEnterCommand=function(self)
			self:stoptweening():addx(-160):decelerate(0.3):addx(160)
		end,
		SceneLeaveCommand=function(self)
			self:stoptweening():accelerate(LEAVE_SECONDS):addx(160)
		end,
	},
}

-- Splash ---------------------------------------------------------------------

local splash = Def.Sprite{
	Name="Splash", Texture=art("splash"),
	InitCommand=function(self)
		self.homeY = 540.5 - Focus.Y   -- inside the carousel, which stands at Focus.Y
		self:xy(961, self.homeY):draworder(0)
	end,
	SceneEnterCommand=function(self)
		self:stoptweening():xy(961, self.homeY):zoom(0.7):rotationz(-8):diffusealpha(0)
			:decelerate(0.18):zoom(1.04):rotationz(1):diffusealpha(1)
			:decelerate(0.1):zoom(1):rotationz(0)
	end,
	SceneLeaveCommand=function(self)
		self:stoptweening():accelerate(LEAVE_SECONDS):zoom(0.85):rotationz(-4):diffusealpha(0)
	end,
	BumpCommand=function(self)
		-- A pack change mid-bump starts over from rest rather than stacking.
		self:stoptweening():zoom(1):rotationz(0):diffusealpha(1)
			:decelerate(0.05):zoom(1.035):rotationz(math.random() < 0.5 and -1.2 or 1.2)
			:decelerate(0.12):zoom(1):rotationz(0)
	end,
}

-- Front ----------------------------------------------------------------------

-- Four-point sparkles: the title's and two over the frame's top corners.
local sparkles = {
	{ 500, 126 }, { 914, 173 }, { 1525, 184 }, { 722.5, 249 }, { 1179.5, 269 },
}
-- Loose outlined stars; the two small ones are the same star at 43 px.
local stars = {
	{ 447, 399, 1 }, { 500.5, 442.5, 0.63 }, { 1417, 571, 1 }, { 1453.5, 721, 0.63 },
}

local front = Def.ActorFrame{
	Name="SceneFront",
	SceneEnterCommand=function(self)
		self:stoptweening():diffusealpha(1)
	end,
	SceneLeaveCommand=function(self)
		self:stoptweening():linear(LEAVE_SECONDS * 0.6):diffusealpha(0)
	end,
}

front[#front+1] = Def.ActorFrame{
	Name="TitleFrame",
	InitCommand=function(self)
		self:xy(967, 205)
		if lively then
			self:bob():effectmagnitude(0, 5, 0):effectperiod(2.6)
		end
	end,
	Def.Sprite{
		Name="Title", Texture=art("title"),
		SceneEnterCommand=function(self, params)
			if params and params.FromSongWheel then
				self:stoptweening():zoom(1):rotationz(0):diffusealpha(0):addy(-30)
					:decelerate(0.2):diffusealpha(1):addy(30)
				return
			end
			-- A slam: in large and tilted, overshoot, settle.
			self:stoptweening():zoom(1.6):rotationz(-10):diffusealpha(0)
				:sleep(0.08):accelerate(0.12):zoom(0.94):rotationz(2):diffusealpha(1)
				:decelerate(0.1):zoom(1.03):rotationz(-1)
				:decelerate(0.08):zoom(1):rotationz(0)
		end,
		SceneLeaveCommand=function(self)
			self:stoptweening():accelerate(LEAVE_SECONDS * 0.6):addy(-40)
				:sleep(0):addy(40)
		end,
	},
}

for i, at in ipairs(sparkles) do
	front[#front+1] = Def.Sprite{
		Name="Sparkle" .. i, Texture=art("sparkle"),
		InitCommand=function(self)
			self:xy(at[1], at[2])
			if lively then
				self:pulse():effectmagnitude(1.15, 0.55, 1):effectperiod(1.1 + 0.17 * i)
					:effectoffset(0.37 * i)
			end
		end,
		SceneEnterCommand=function(self)
			self:stoptweening():diffusealpha(0):sleep(0.22 + 0.05 * i):linear(0.08):diffusealpha(1)
		end,
	}
end

for i, at in ipairs(stars) do
	-- The outer frame places and pops the star; the sprite turns.
	front[#front+1] = Def.ActorFrame{
		Name="Star" .. i,
		InitCommand=function(self) self:xy(at[1], at[2]):zoom(at[3]) end,
		SceneEnterCommand=function(self)
			self:stoptweening():zoom(0):sleep(0.18 + 0.06 * i)
				:decelerate(0.14):zoom(at[3] * 1.3):accelerate(0.08):zoom(at[3])
		end,
		BumpCommand=function(self)
			self:finishtweening():zoom(at[3] * 1.18):decelerate(0.16):zoom(at[3])
		end,
		Def.Sprite{
			Texture=art("star"),
			InitCommand=function(self)
				if lively then
					self:spin():effectmagnitude(0, 0, (i % 2 == 0) and -28 or 22)
				end
			end,
		},
	}
end

return { Back = back, Splash = splash, Front = front, Focus = Focus }
