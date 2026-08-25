local player = ...
local summary = VOLT26.Session.GetProfileSummary(player)

local lines = {
	summary.display_name,
	summary.calories and (ScreenString("CaloriesBurned") .. "\n" .. summary.calories) or "",
	ScreenString("TotalSongsPlayed") .. "\n"..summary.total_songs,
}

return lines
