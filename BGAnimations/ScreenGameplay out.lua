return Def.Quad{
	InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0) end,
	OnCommand=function(self) self:sleep(0.5):linear(1):diffusealpha(1) end,
	OffCommand=function(self)
		if VOLT26.Gameplay.GetMode() == "ITG" then
			local song = GAMESTATE:GetCurrentSong()
			local totalWhites = 0
			for player in ivalues( GAMESTATE:GetHumanPlayers() ) do
				local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
				local number = pss:GetTapNoteScores("TapNoteScore_W1")
				local exCounts = VOLT26.Scoring.GetExCounts(player) or {}
				local faPlus = exCounts.W0_total or 0
				-- Subtract FA+ count from the overall fantastic window count.
				local whites = number - faPlus
				totalWhites = totalWhites + whites
				-- This will save the white count to Stats.xml, so we can later recover
				-- it when we deprecate FA+ mode and introduce W0.
				--
				-- The Score field is completely unused in Simply Love, and the ability
				-- to set the field is exposed to lua so we can hijack it for our own\
				-- purposes.
				local bestWhites = whites
				if PROFILEMAN:IsPersistentProfile(player) then
					local steps = GAMESTATE:GetCurrentSteps(player)
					local scores = PROFILEMAN:GetProfile(player):GetHighScoreList(song, steps):GetHighScores()
					for hs in ivalues(scores) do
						-- If the player previously quadded the song, retain the better white count.
						-- Technically this is a workaround because the date would be wrong, but
						-- it's still worth to keep the score around
						if (pss:GetPercentDancePoints() == hs:GetPercentDP() and hs:GetPercentDP() == 1.0) then
							bestWhites = math.min(bestWhites, hs:GetScore())
						end
					end
				end
				pss:SetScore(bestWhites)
			end
			if IsRoutine() then
				local routineStats = STATSMAN:GetCurStageStats():GetRoutineStageStats()
				local bestWhites = totalWhites
				if PROFILEMAN:IsPersistentProfile(GAMESTATE:GetMasterPlayerNumber()) then
					local steps = GAMESTATE:GetCurrentSteps(GAMESTATE:GetMasterPlayerNumber())
					local scores = PROFILEMAN:GetProfile(GAMESTATE:GetMasterPlayerNumber()):GetHighScoreList(song, steps):GetHighScores()
					for hs in ivalues(scores) do
						-- If the player previously quadded the song, retain the better white count.
						-- Technically this is a workaround because the date would be wrong, but
						-- it's still worth to keep the score around
						if (routineStats:GetPercentDancePoints() == hs:GetPercentDP() and hs:GetPercentDP() == 1.0) then
							bestWhites = math.min(bestWhites, hs:GetScore())
						end
					end
				end
				routineStats:SetScore(bestWhites)
			end
		end
	end
}
