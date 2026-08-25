-- If both players are joined, change the opacity of their score BitmapText actors to
-- visually indicate who is winning at a given moment during gameplay.
------------------------------------------------------------

-- if there is only one player, don't bother
if #GAMESTATE:GetHumanPlayers() < 2 then return end

-- if displaying different scoring mechanisms, don't bother.
local p1Modifiers = VOLT26.Options.GetPlayerModifiers(PLAYER_1)
local p2Modifiers = VOLT26.Options.GetPlayerModifiers(PLAYER_2)
if not VOLT26.Versus.CanCompare(p1Modifiers, p2Modifiers) then return end

local p1_score, p2_score
local scores = VOLT26.Versus.NewScoreState()
local p1_pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
local p2_pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_2)
local IsEX = p1Modifiers.ShowExScore

-- allow for HideScore, which outright removes score actors
local try_diffusealpha = function(af, alpha)
	if not af or not (af.diffusealpha) then return end
	af:diffusealpha(alpha)
end

return Def.Actor{
	OnCommand=function(self)
		local underlay = SCREENMAN:GetTopScreen():GetChild("Underlay")
		p1_score = underlay:GetChild("P1Score")
		p2_score = underlay:GetChild("P2Score")
	end,
	JudgmentMessageCommand=function(self, params)
		if not IsEX then
			local score
			if params.Player == PLAYER_1 then
				score = VOLT26.Versus.CalculateDancePointRatio(
					p1_pss:GetActualDancePoints(), p1_pss:GetPossibleDancePoints()
				)
			elseif params.Player == PLAYER_2 then
				score = VOLT26.Versus.CalculateDancePointRatio(
					p2_pss:GetActualDancePoints(), p2_pss:GetPossibleDancePoints()
				)
			end
			if score then self:playcommand("Winning", {Leader=VOLT26.Versus.UpdateScore(scores, params.Player, score)}) end
		end
	end,
	VOLT26ScoreChangedMessageCommand=function(self, params)
		if IsEX then
			self:playcommand("Winning", {
				Leader=VOLT26.Versus.UpdateScore(scores, params.Player, params.ExScore)
			})
		end
	end,
	WinningCommand=function(self, params)
		if params.Leader == "Tie" then
			try_diffusealpha(p1_score, 1)
			try_diffusealpha(p2_score, 1)
		elseif params.Leader == PLAYER_1 then
			try_diffusealpha(p1_score, 1)
			try_diffusealpha(p2_score, 0.65)
		elseif params.Leader == PLAYER_2 then
			try_diffusealpha(p1_score, 0.65)
			try_diffusealpha(p2_score, 1)
		end
	end
}
