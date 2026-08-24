local isVOLT26 = ThemePrefs.Get("VisualStyle") == "VOLT26"

local af = Def.ActorFrame{
	-- GameplayReloadCheck is a kludgy global variable used in ScreenGameplay in.lua to check
	-- if ScreenGameplay is being entered "properly" or being reloaded by a scripted mod-chart.
	-- If we're here in SelectMusic, set GameplayReloadCheck to false, signifying that the next
	-- time ScreenGameplay loads, it should have a properly animated entrance.
	InitCommand=function(self)
		SL.Global.GameplayReloadCheck = false
		generateFavoritesForMusicWheel()
		-- While other SM versions don't need this, Outfox resets the
		-- the music rate to 1 between songs, but we want to be using
		-- the preselected music rate.
		local songOptions = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
		songOptions:MusicRate(SL.Global.ActiveModifiers.MusicRate)
	end,

	PlayerProfileSetMessageCommand=function(self, params)
		if not PROFILEMAN:IsPersistentProfile(params.Player) then
			LoadGuest(params.Player)
		end
		generateFavoritesForMusicWheel()
		ApplyMods(params.Player)
	end,

	PlayerJoinedMessageCommand=function(self, params)
		if not PROFILEMAN:IsPersistentProfile(params.Player) then
			LoadGuest(params.Player)
		end
		ApplyMods(params.Player)
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

-- Keep the stock visual actors as direct children for every other visual style.
-- Their original hierarchy and message propagation must not change.
if isVOLT26 then
	af[#af+1] = LoadActor("./VOLT26/default.lua")
else
	af[#af+1] = LoadActor("./MusicWheelAnimation.lua")
	af[#af+1] = LoadActor("./PaneDisplay.lua")
	af[#af+1] = LoadActor("./PerPlayer/default.lua")
	af[#af+1] = LoadActor("./StepsDisplayList/default.lua")
	af[#af+1] = LoadActor("./SongDescription/SongDescription.lua")
	af[#af+1] = LoadActor("./Banner.lua")
end

-- Shared overlays retain their original draw order.
af[#af+1] = LoadActor("./SortMenu/default.lua")
af[#af+1] = LoadActor("./TestInput.lua")
af[#af+1] = LoadActor("./Leaderboard.lua")
af[#af+1] = LoadActor("./SongSearch/default.lua")

return af
