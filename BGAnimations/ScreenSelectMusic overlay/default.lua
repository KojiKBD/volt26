local af = Def.ActorFrame{
	-- GameplayReloadCheck is a kludgy global variable used in ScreenGameplay in.lua to check
	-- if ScreenGameplay is being entered "properly" or being reloaded by a scripted mod-chart.
	-- If we're here in SelectMusic, set GameplayReloadCheck to false, signifying that the next
	-- time ScreenGameplay loads, it should have a properly animated entrance.
	InitCommand=function(self)
		VOLT26.MusicSelection.PrepareScreen()
	end,

	PlayerProfileSetMessageCommand=function(self, params)
		VOLT26.MusicSelection.RefreshPlayer(params.Player, true)
	end,

	PlayerJoinedMessageCommand=function(self, params)
		VOLT26.MusicSelection.RefreshPlayer(params.Player, false)
	end,
	CodeMessageCommand=function(self, params)
		if params.Name == "Favorite1" or params.Name == "Favorite2" then
			addOrRemoveFavorite(params.PlayerNumber)
		elseif params.Name == "EscapeFromEventMode" then
			SCREENMAN:GetTopScreen():Cancel()
		end
	end,
	ReloadScreenForMemoryCardsMessageCommand=function(self, params)
		-- Wait some time for the profile screen to finish transitioning
		-- before reloading the screen.
		self:sleep(0.10):queuecommand("Reload")
	end,
	ReloadCommand=function(self)
		SCREENMAN:GetTopScreen():SetNextScreenName("ScreenReloadSSM")
		SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	end,
	-- ---------------------------------------------------
	--  first, load files that contain no visual elements, just code that needs to run

	-- MenuTimer code for preserving SSM's timer value when going 
	-- from SSM to a different screen and back to SSM (i.e. returning from PlayerOptions).
	LoadActor("./PreserveMenuTimer.lua"),
	-- Apply player modifiers from profile
	LoadActor("./PlayerModifiers.lua"),

	-- allow stepcharts from multiple styles (single, double, routine) to coexist
	-- in the same music wheel
	LoadActor("./AutoSetStyle.lua"),
}

af[#af+1] = LoadActor("./VOLT26/default.lua")

-- Shared overlays retain their original draw order.
af[#af+1] = LoadActor("./SortMenu/default.lua")
af[#af+1] = LoadActor("./TestInput.lua")
af[#af+1] = LoadActor("./Leaderboard.lua")
af[#af+1] = LoadActor("./SongSearch/default.lua")

return af
