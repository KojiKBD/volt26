-- The title screen's music.  While the opening cinematic is still to play, the
-- title is silent and Media.lua starts the menu theme when the camera lands;
-- on later visits the theme simply carries on (see "_volt26 menu theme").
if not _G.Volt26CityIntroPlayed then
	return THEME:GetPathS("", "_silent")
end
return THEME:GetPathG("", "VOLT26/menuost.ogg")
