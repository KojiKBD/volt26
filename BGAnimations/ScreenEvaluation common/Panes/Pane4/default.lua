-- Pane4 displays a list of HighScores for the stepchart that was played.

local player = unpack(...)

local pane = Def.ActorFrame{
	InitCommand=function(self)
		self:y(_screen.cy - 62):zoom(0.8)
	end
}

-- -----------------------------------------------------------------------

local record = VOLT26.Results.GetRecordStatus(player)

-- -----------------------------------------------------------------------

-- Novice players frequently improve their own score while struggling to
-- break into an overall leaderboard.  The lack of *visible* leaderboard
-- progress can be frustrating/demoralizing, so let's do what we can to
-- alleviate that.
--
-- If this score is not high enough to be a machine record, but it *is*
-- good enough to be a top-2 personal record, show two HighScore lists:
-- 1-8 machine HighScores, then 1-2 personal HighScores
--
-- If the player isn't using a profile (local or USB), there won't be any
-- personal HighScores to compare against.
--
-- Also, this 8+2 shouldn't show up on privately owned machines where only
-- one person plays, which is a common scenario in 2020.
--
-- This idea of showing both machine and personal HighScores to help new players
-- track progress is based on my experiences maintaining a heavily-used
-- public SM5 machine for several years while away at school.


-- 22px RowHeight by default, which works for displaying 10 machine HighScores
local args = { Player=player, RoundsAgo=1, RowHeight=22}

if (not record.earnedMachine and record.earnedTopTwoPersonal) then

	-- less line spacing between HighScore rows to fit the horizontal line
	args.RowHeight = 20.25

	-- top 8 machine HighScores
	args.NumHighScores = math.min(8, PREFSMAN:GetPreference("MaxHighScoresPerListForMachine"))
	pane[#pane+1] = LoadActor(THEME:GetPathB("", "_modules/HighScoreList.lua"), args)

	-- horizontal line visually separating machine HighScores from player HighScores
	pane[#pane+1] = Def.Quad{ InitCommand=function(self) self:zoomto(100, 1):y(args.RowHeight*9):diffuse(1,1,1,0.33) end }

	-- top 2 player HighScores
	args.NumHighScores = math.min(2, PREFSMAN:GetPreference("MaxHighScoresPerListForPlayer"))
	args.Profile = PROFILEMAN:GetProfile(player)
	pane[#pane+1] = LoadActor(THEME:GetPathB("", "_modules/HighScoreList.lua"), args)..{
		InitCommand=function(self) self:y(args.RowHeight*9) end
	}

-- the player did not meet the conditions to show the 8+2 HighScores
-- Just show top 10 machine HighScores
-- We can also hijack the 10 rows of high scores to display those ones fetched from GrooveStats.
else
	-- top 10 machine HighScores
	args.NumHighScores = math.min(10, PREFSMAN:GetPreference("MaxHighScoresPerListForMachine"))
	pane[#pane+1] = LoadActor(THEME:GetPathB("", "_modules/HighScoreList.lua"), args)
end

return pane
