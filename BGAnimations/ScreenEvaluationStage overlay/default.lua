-- ScreenEvaluationStage overlay.
--
-- "ScreenEval Common" (the inherited Simply Love evaluation) is always loaded:
-- it owns input, score storage, screenshots, favourites, GrooveStats submission
-- and the event overlay.  What it draws is shown in one of two views:
--
--   * Summary.lua -- the VOLT26 results (score panels, judgment table, timing),
--     shown first;
--   * Details.lua -- the inherited panes (GrooveStats QR, high scores,
--     scatter plot...), fitted beside the card.
--
-- The summary is the only view players see; MenuLeft / MenuRight do not switch
-- to the inherited one.  The inherited view is shown only when the summary
-- cannot be built (casual play, or helpers missing after a hot reload).
--
-- Nothing is shown until the evaluation sequence has finished.  The song title,
-- banner and BPM line stay hidden because the card shows them.

local details = LoadActor("./Details.lua")
-- Scripts/ are only read when ITGmania starts, so a screen reload after a theme
-- update can run this file against older helpers.  Without the summary's data
-- helpers, show the inherited view instead of raising an error.
local summaryAvailable = VOLT26.Results.GetSummary ~= nil and VOLT26.Analysis.BuildHistogram ~= nil
local summary = summaryAvailable and LoadActor("./Summary.lua") or Def.ActorFrame{ Name="VOLT26Summary" }
local casual = VOLT26.Gameplay.IsCasual() or not summaryAvailable

local alwaysHidden = { "TitleAndBanner", "SongFeatures" }
local detailsShown = casual

local function applyView(overlay)
	local common = overlay:GetChild("ScreenEval Common")
	overlay:GetChild("VOLT26Summary"):visible(not detailsShown)
	if common then details.SetVisible(overlay, common, detailsShown) end
end

return Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
		local common = self:GetChild("ScreenEval Common")
		if common then
			for _, name in ipairs(alwaysHidden) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			details.Fit(self, common)
		end
		applyView(self)
		self:visible(true)
	end,
	summary,
	details.Backdrop,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common")),
}
