-- ScreenEvaluationStage overlay: the P5 "WANTED" results page.
--
-- The artwork is the owner's Illustrator page (tools/evaluation/, see
-- docs/evaluation-wanted.md).  The background layer draws what both players
-- share: the WANTED frame and the song's background in its window
-- (ScreenEvaluationStage background.lua).  This overlay draws each player's
-- side over it -- player 1 as drawn on the left, player 2 mirrored on the
-- right -- and the song title along the frame's bottom edge.
--
-- "ScreenEval Common" (the inherited Simply Love evaluation) is always loaded:
-- it owns input, score storage, screenshots, favourites, GrooveStats submission
-- and the event overlay.  Its own upper and lower halves are not shown (this
-- page shows the grade, the graph and the modifiers) and its panes are
-- hidden: the page has its own NOTES, timing and GrooveStats pages instead.
-- MenuLeft / MenuRight turn a side's page (ScreenEvaluation
-- common/PageInputHandler.lua; the pages are in Wanted/Side.lua).
--
-- All drawing is in artboard pixels (1920x1080) under one frame zoomed to the
-- screen's height and centred; the cutout lettering is in theme units.
--
-- Motion: the page waits while the victory / defeat transition plays
-- (ScreenEvaluationStage in/VOLT26.lua), which broadcasts
-- VOLT26EvaluationReveal as it starts to clear.  The overlay then broadcasts
-- VOLT26EvaluationWantedIntro once -- a red slash and a flash, the title band
-- rising, each side's plates sliding in (Wanted/Side.lua) -- and, for the
-- modules that waited for the results, VOLT26EvaluationSequenceFinished.  If
-- the transition never says so, the page comes in after REVEAL_FALLBACK
-- seconds.  Leaving the screen, every part goes back out (OffCommand) under
-- ScreenEvaluationStage out.lua.
local REVEAL_FALLBACK = 4.5

local Art = LoadActor("./Wanted/Art.lua")
local T = LoadActor("./Wanted/Text.lua")
local S = SCREEN_HEIGHT / 1080
local OX = (SCREEN_WIDTH - 1920 * S) / 2

local players = GAMESTATE:GetHumanPlayers()

-- The inherited actors this page replaces.
local replaced = { "TitleAndBanner", "SongFeatures" }
for _, player in ipairs({ PLAYER_1, PLAYER_2 }) do
	local pn = ToEnumShortString(player)
	replaced[#replaced+1] = pn .. "_AF_Upper"
	replaced[#replaced+1] = pn .. "_AF_Lower"
end

local function titleText()
	local course = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or nil
	local song = GAMESTATE:GetCurrentSong()
	local text = course and course:GetDisplayFullTitle() or song and song:GetDisplayMainTitle() or ""
	return T.Upper(text)
end

-- ---------------------------------------------------------------------------

local page = Def.ActorFrame{
	Name="WantedPage",
	InitCommand=function(self) self:xy(OX, 0):zoom(S) end,
}
local cutouts = Def.ActorFrame{ Name="WantedCutouts" }

-- The song title along the frame's bottom edge, centred on the artwork's
-- title.  A title longer than the band scrolls through it as a marquee,
-- clipped at the band's ends by two z-buffer masks.  It goes under the
-- players' sides: with two players, player 2's covers it.
local title = titleText()
local covered = T.Covered(title)
local TITLE_GAP = 160      -- between the marquee's copies, artboard pixels
local TITLE_SPEED = 140    -- artboard pixels per second

local function titleText_(name)
	return LoadFont(covered and T.Font.Title or T.Font.Fallback)..{
		Name=name,
		InitCommand=function(self)
			local a = Art.title
			self:halign(0.5):valign(1):diffuse(color("#f11600")):settext(title)
			local zoom = covered and a.size / T.EM.Title or a.size * T.CAP.Title / math.max(1, self:GetHeight())
			self:zoom(zoom)
		end,
	}
end

local band = Def.ActorFrame{
	Name="Title",
	InitCommand=function(self)
		local a = Art.title
		local r = math.rad(a.rot)
		self.baseY = a.y + a.centre * math.sin(r)
		self:xy(a.x + a.centre * math.cos(r), self.baseY + 150):rotationz(a.rot):diffusealpha(0)
	end,
	VOLT26EvaluationWantedIntroMessageCommand=function(self)
		self:finishtweening():y(self.baseY + 150):diffusealpha(0)
			:sleep(0.2):decelerate(0.3):y(self.baseY):diffusealpha(1)
		-- A long title starts scrolling once the band has settled.
		if self.period then self:sleep(1.2):queuecommand("Scroll") end
	end,
	OffCommand=function(self)
		self:stoptweening():accelerate(0.2):y(self.baseY + 150):diffusealpha(0)
	end,
	OnCommand=function(self)
		local first, second = self:GetChild("First"), self:GetChild("Second")
		local width = first:GetZoomedWidth()
		local length = Art.title.length
		if width <= length then
			second:visible(false)
			self:GetChild("MaskLeft"):visible(false)
			self:GetChild("MaskRight"):visible(false)
			return
		end
		-- Two copies one period apart, starting with the title's start at the
		-- band's left end, moving left forever.
		local period = width + TITLE_GAP
		self.start = -length / 2 + width / 2
		self.period = period
		first:MaskDest():x(self.start)
		second:MaskDest():x(self.start + period)
	end,
	ScrollCommand=function(self)
		local seconds = self.period / TITLE_SPEED
		for _, name in ipairs({ "First", "Second" }) do
			local text = self:GetChild(name)
			text:linear(seconds):addx(-self.period)
		end
		self:sleep(seconds):queuecommand("Wrap")
	end,
	WrapCommand=function(self)
		self:GetChild("First"):x(self.start)
		self:GetChild("Second"):x(self.start + self.period)
		self:queuecommand("Scroll")
	end,
	-- Masks first: they hide what is outside the band from the copies.
	Def.Quad{
		Name="MaskLeft",
		InitCommand=function(self)
			self:halign(1):valign(0.5):x(-Art.title.length / 2):zoomto(3000, 600):MaskSource(true)
		end,
	},
	Def.Quad{
		Name="MaskRight",
		InitCommand=function(self)
			self:halign(0):valign(0.5):x(Art.title.length / 2):zoomto(3000, 600):MaskSource()
		end,
	},
	titleText_("First"),
	titleText_("Second"),
}
page[#page+1] = band


-- A single player's side is always the left one, whichever side they joined
-- on; with two players each has their own.
for _, player in ipairs(players) do
	local where = #players == 1 and PLAYER_1 or player
	local side = LoadActor("./Wanted/Side.lua", { Art = Art, Text = T, player = player, side = where, S = S, OX = OX })
	page[#page+1] = side.art
	cutouts[#cutouts+1] = side.cutouts
end

-- The song name plate under "WANTED", over the sides (Wanted/SongName.lua).
page[#page+1] = LoadActor("./Wanted/SongName.lua", { Text = T })

return Def.ActorFrame{
	OnCommand=function(self)
		local common = self:GetChild("ScreenEval Common")
		if common then
			for _, name in ipairs(replaced) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			-- The panes stay loaded (GrooveStats submission writes into them)
			-- but are never shown.
			local panes = common:GetChild("Panes")
			if panes then panes:visible(false) end
		end
		-- In case the transition never says it is clearing.
		self:sleep(REVEAL_FALLBACK):queuecommand("VOLT26WantedReveal")
	end,
	VOLT26EvaluationRevealMessageCommand=function(self)
		self:playcommand("VOLT26WantedReveal")
	end,
	VOLT26WantedRevealCommand=function(self)
		if self.revealed then return end
		self.revealed = true
		MESSAGEMAN:Broadcast("VOLT26EvaluationWantedIntro")
		-- Modules and listeners that wait for the results (the five-star cat).
		MESSAGEMAN:Broadcast("VOLT26EvaluationSequenceFinished")
	end,
	-- A red slash across the screen as the page comes in, under the sides.
	Def.Quad{
		Name="WantedSlash",
		InitCommand=function(self)
			self:zoomto(SCREEN_WIDTH * 0.32, SCREEN_HEIGHT * 2.4):rotationz(16)
				:xy(-SCREEN_WIDTH * 0.3, SCREEN_CENTER_Y):diffuse(color("#f11600")):visible(false)
		end,
		VOLT26EvaluationWantedIntroMessageCommand=function(self)
			self:finishtweening():visible(true):x(-SCREEN_WIDTH * 0.3)
				:linear(0.3):x(SCREEN_WIDTH * 1.3):queuecommand("Hide")
		end,
		HideCommand=function(self) self:visible(false) end,
	},
	page,
	cutouts,
	-- A white flash over everything as the page lands.
	Def.Quad{
		Name="WantedFlash",
		InitCommand=function(self) self:FullScreen():diffuse(color("#ffffff")):diffusealpha(0) end,
		VOLT26EvaluationWantedIntroMessageCommand=function(self)
			self:finishtweening():diffusealpha(0):sleep(0.32):diffusealpha(0.45):linear(0.25):diffusealpha(0)
		end,
	},
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common"), { WantedPage = true }),
}
