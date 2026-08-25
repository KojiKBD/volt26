local player = ...

local summary = VOLT26.Session.GetSummary(player)
local duration = VOLT26.Session.FormatDuration(summary.active_seconds)

local lines = {
	ScreenString("SongsPlayedThisGame") .. "\n" .. summary.songs_played,
	ScreenString("NotesHitThisGame") .. "\n" .. summary.tap_hits,
	ScreenString("TimeSpentThisGame") .. "\n" .. duration.minutes .. THEME:GetString("ScreenGameOver", "Minutes") .. " " .. duration.seconds .. THEME:GetString("ScreenGameOver", "Seconds")
}

if duration.hours > 0 then
	lines[3] = ScreenString("TimeSpentThisGame") .. "\n"..
		duration.hours .. ScreenString("Hours") .. " " ..
		duration.minutes .. ScreenString("Minutes") .. " " ..
		duration.seconds .. ScreenString("Seconds")
end

return lines
