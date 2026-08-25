-- ScreenInit is the first screen to load, as defined in Metrics.ini under [Common]
--
-- we want to ensure that the current game (dance, pump, techno, kb7, etc.)
-- is supported by VOLT26 and will not cause Lua errors that could result
-- in players getting stuck within the theme.
--
-- If the player is in the operator menu and tries to switch to, say, kickbox
-- the engine will change the game, the theme will reload, this screen will load,
-- we'll detect that kickbox isn't supported, and bounce them right back to choosing a different game.
--
-- The same thing basically happens if StepMania starts up in an unsupported game
-- or if the player switches into VOLT26 from another theme in an unsupported game.

return Def.Actor{
	OnCommand=function()
		local supported, message = VOLT26.Compatibility.CheckCurrent()
		if supported then return end
		SM(message)
		SCREENMAN:SetNewScreen("ScreenSystemOptions")
	end
}
