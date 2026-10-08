-- The inherited Simply Love results: letter grade, difficulty, records and the
-- two pane columns the players page through with MenuLeft / MenuRight.
--
-- Their actors keep the screen coordinates Simply Love lays them out in; once
-- the evaluation sequence has finished, the frames that draw them are scaled as
-- one block into the space to the right of the song card.  Input and score
-- state are live from the start.  The song title, banner and BPM line are left
-- hidden because the card shows them, and the event overlay, screenshot flash
-- and favourite toast stay full screen.

-- Bounds of the inherited layout, in screen units (two 300-unit pane columns
-- 10 apart around the screen centre, from the letter grade to the pane bottom).
local source = {
	left = _screen.cx - 310, right = _screen.cx + 310,
	top = 40, bottom = _screen.cy + 130,
}

-- Space to the right of the card, whose right edge is at 813 of 1920 pixels in
-- the sequence's last frame (see ScreenEvaluationStage background.lua).
local region = {
	left = 840 * SCREEN_WIDTH / 1920, right = SCREEN_WIDTH - 12,
	top = 24, bottom = SCREEN_HEIGHT - 24,
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

local hidden = { TitleAndBanner = true, SongFeatures = true }

return Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
		local common = self:GetChild("ScreenEval Common")
		if common then
			for name in pairs(hidden) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			fit(common:GetChild("Panes"))
			for player in ivalues(GAMESTATE:GetHumanPlayers()) do
				local pn = ToEnumShortString(player)
				fit(common:GetChild(pn .. "_AF_Upper"))
				fit(common:GetChild(pn .. "_AF_Lower"))
			end
		end
		self:visible(true):diffusealpha(0):decelerate(0.25):diffusealpha(1)
	end,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common")),
}
