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
-- page shows the grade, the graph and the modifiers); its panes are the pages
-- after the WANTED page.  MenuLeft / MenuRight turn a side's page
-- (ScreenEvaluation common/PageInputHandler.lua); a pane is shown over that
-- side's judgment ladder until the panes get their own design.
--
-- All drawing is in artboard pixels (1920x1080) under one frame zoomed to the
-- screen's height and centred; the cutout lettering is in theme units.

local Art = LoadActor("./Wanted/Art.lua")
local T = LoadActor("./Wanted/Text.lua")
local S = SCREEN_HEIGHT / 1080
local OX = (SCREEN_WIDTH - 1920 * S) / 2

local players = GAMESTATE:GetHumanPlayers()
local casual = VOLT26.Gameplay.IsCasual()

-- The inherited actors this page replaces.
local replaced = { "TitleAndBanner", "SongFeatures" }
for _, player in ipairs({ PLAYER_1, PLAYER_2 }) do
	local pn = ToEnumShortString(player)
	replaced[#replaced+1] = pn .. "_AF_Upper"
	replaced[#replaced+1] = pn .. "_AF_Lower"
end

-- Where an inherited pane goes on a side: over the judgment ladder, in
-- artboard pixels, turned like the ladder's text.  A pane is laid out by
-- Simply Love about its frame's x and between these screen heights.
local PANE_BOX = { cx = 330, cy = 655, w = 470, h = 520, rot = 2 }
local PANE_SOURCE = { w = 310, top = _screen.cy - 80, bottom = _screen.cy + 225 }

local function fitPane(frame, side)
	local mirror = side == PLAYER_2
	local rot = mirror and -PANE_BOX.rot or PANE_BOX.rot
	local zoom = math.min(PANE_BOX.w * S / PANE_SOURCE.w, PANE_BOX.h * S / (PANE_SOURCE.bottom - PANE_SOURCE.top))
	local cx = OX + (mirror and 1920 - PANE_BOX.cx or PANE_BOX.cx) * S
	local cy = PANE_BOX.cy * S
	-- The source's centre (frame-local) lands on the box's centre.
	local qy = (PANE_SOURCE.top + PANE_SOURCE.bottom) / 2
	local c, s = math.cos(math.rad(rot)), math.sin(math.rad(rot))
	frame:xy(cx - (0 * c - qy * s) * zoom, cy - (0 * s + qy * c) * zoom):zoom(zoom):rotationz(rot)
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

-- The song title along the frame's bottom edge, cut by the screen as drawn.
-- It goes under the players' sides: with two players, player 2's covers it.
local title = titleText()
local covered = T.Covered(title)
page[#page+1] = LoadFont(covered and T.Font.Title or T.Font.Fallback)..{
	Name="Title",
	InitCommand=function(self)
		local a = Art.title
		local maxLength = 1100
		self:halign(0):valign(1):xy(a.x, a.y):rotationz(a.rot):diffuse(color("#f11600")):settext(title)
		local zoom = covered and a.size / T.EM.Title or a.size * T.CAP.Title / math.max(1, self:GetHeight())
		self:zoom(zoom)
		local width = self:GetZoomedWidth()
		if width > maxLength then
			-- Smaller down to 60 %, then narrower.  A smaller title keeps the
			-- top of its capitals where the full size has it, so it does not
			-- sink below the screen's edge.
			local fit = math.max(0.6, maxLength / width)
			self:zoom(zoom * fit)
			if width * fit > maxLength then self:zoomx(zoom * fit * maxLength / (width * fit)) end
			local lift, r = a.size * T.CAP.Title * (1 - fit), math.rad(a.rot)
			self:xy(a.x + lift * math.sin(r), a.y - lift * math.cos(r))
		end
	end,
	OnCommand=function(self)
		self:addy(140):decelerate(0.35):addy(-140)
	end,
}

for _, player in ipairs(players) do
	local side = LoadActor("./Wanted/Side.lua", { Art = Art, Text = T, player = player, side = player, S = S, OX = OX })
	local away = player == PLAYER_1 and -1 or 1
	side.art.OnCommand = function(self)
		self:addx(away * 260):decelerate(0.3):addx(-away * 260)
	end
	side.cutouts.OnCommand = function(self)
		self:addx(away * 260 * S):decelerate(0.3):addx(-away * 260 * S)
	end
	page[#page+1] = side.art
	cutouts[#cutouts+1] = side.cutouts
end

return Def.ActorFrame{
	OnCommand=function(self)
		local common = self:GetChild("ScreenEval Common")
		if common then
			for _, name in ipairs(replaced) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			local panes = common:GetChild("Panes")
			if panes then
				if casual then
					panes:visible(false)
				else
					for _, side in ipairs({ PLAYER_1, PLAYER_2 }) do
						for index = 1, VOLT26.EvaluationPage.InheritedPanes do
							local frame = panes:GetChild(("Pane%i_Side%s"):format(index, ToEnumShortString(side)))
							if frame then fitPane(frame, side) end
						end
					end
				end
			end
		end
		-- Modules and listeners that waited for the old result sequence.
		self:sleep(0.4):queuecommand("Revealed")
	end,
	RevealedCommand=function(self)
		MESSAGEMAN:Broadcast("VOLT26EvaluationSequenceFinished")
	end,
	page,
	cutouts,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common"), { WantedPage = true }),
}
