-- The inherited Simply Love results: letter grade, difficulty, records and the
-- two pane columns the players page through with MenuLeft / MenuRight.
--
-- Their actors keep the screen coordinates Simply Love lays them out in; once
-- the evaluation sequence has finished, the frames that draw them are scaled as
-- one block and centred in the space to the right of the song card.  Behind
-- them sits a VOLT26 panel per column (ink body, red header with the player's
-- name), drawn in the same coordinates.  Input and score state are live from
-- the start.  The song title, banner and BPM line stay hidden because the card
-- shows them; the event overlay, screenshot flash and favourite toast stay full
-- screen.

local players = GAMESTATE:GetHumanPlayers()
local ink = color(VOLT26.Brand.Surfaces.Ink)
local red = color("#FF0000")

-- Columns of the inherited layout, in screen units: two 300-unit columns 10
-- apart around the centre, or one 610-unit column for a single player.
local columnGap = 10
local headerHeight = 22
local headerTop = 18    -- above the record texts (y 50-60) and the grade (y 66+)
local bodyBottom = _screen.cy + 222   -- just below the modifiers strip

local function columns()
	if #players == 1 then
		return { {player = players[1], left = _screen.cx - 310, right = _screen.cx + 310} }
	end
	return {
		{player = PLAYER_1, left = _screen.cx - 310, right = _screen.cx - columnGap / 2},
		{player = PLAYER_2, left = _screen.cx + columnGap / 2, right = _screen.cx + 310},
	}
end

local source = {
	left = _screen.cx - 310, right = _screen.cx + 310,
	top = headerTop, bottom = bodyBottom,
}

-- Space to the right of the card, whose right edge is at 813 of 1920 pixels in
-- the sequence's last frame (see ScreenEvaluationStage background.lua).
local region = {
	left = 832 * SCREEN_WIDTH / 1920, right = SCREEN_WIDTH - 12,
	top = 12, bottom = SCREEN_HEIGHT - 12,
}

local sourceW, sourceH = source.right - source.left, source.bottom - source.top
local regionW, regionH = region.right - region.left, region.bottom - region.top
local zoom = math.min(regionW / sourceW, regionH / sourceH)
local originX = region.left + (regionW - sourceW * zoom) / 2 - source.left * zoom
local originY = region.top + (regionH - sourceH * zoom) / 2 - source.top * zoom

-- A frame drawn at (x, y) with children in screen units is moved so the whole
-- block lands in the region: screen point p maps to origin + p * zoom.
local function fit(frame)
	if not frame then return end
	frame:xy(originX + frame:GetX() * zoom, originY + frame:GetY() * zoom):zoom(zoom)
end

local function playerName(player)
	local name = PROFILEMAN:GetPlayerName(player)
	if not name or name == "" then name = ToEnumShortString(player) end
	return name:upper()
end

local backdrop = Def.ActorFrame{ Name="VOLT26Backdrop" }
for _, column in ipairs(columns()) do
	local width = column.right - column.left
	backdrop[#backdrop+1] = Def.ActorFrame{
		InitCommand=function(self) self:x(column.left) end,
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):y(headerTop):zoomto(width, bodyBottom - headerTop)
					:diffuse(ink):diffusealpha(0.94)
			end,
		},
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):y(headerTop):zoomto(width, headerHeight):diffuse(red)
			end,
		},
		LoadFont(VOLT26.Type.Label)..{
			InitCommand=function(self)
				self:align(0, 0.5):xy(10, headerTop + headerHeight / 2):diffuse(ink)
				VOLT26.Type.SetLabel(self, playerName(column.player), 13, width * 0.6)
			end,
		},
		LoadFont(VOLT26.Type.Label)..{
			InitCommand=function(self)
				self:align(1, 0.5):xy(width - 10, headerTop + headerHeight / 2):diffuse(ink)
				VOLT26.Type.SetLabel(self, "RESULTS", 13, width * 0.35)
			end,
		},
	}
end

local hidden = { TitleAndBanner = true, SongFeatures = true }

return Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
		fit(self:GetChild("VOLT26Backdrop"))
		local common = self:GetChild("ScreenEval Common")
		if common then
			for name in pairs(hidden) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			fit(common:GetChild("Panes"))
			for player in ivalues(players) do
				local pn = ToEnumShortString(player)
				fit(common:GetChild(pn .. "_AF_Upper"))
				fit(common:GetChild(pn .. "_AF_Lower"))
			end
		end
		self:visible(true):diffusealpha(0):decelerate(0.25):diffusealpha(1)
	end,
	backdrop,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common")),
}
