local audio_file = "fold.ogg"

local style = ThemePrefs.Get("VisualStyle")
if style == "SRPG10" then
	audio_file = "VOLT26-GameOver.ogg"
end

if style == "VOLT26" then
	audio_file = "VOLT26-GameOver.ogg"
end

return THEME:GetPathS("", audio_file)
