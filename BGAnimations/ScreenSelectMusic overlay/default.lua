-- ScreenSelectMusic (and ScreenSelectCourse): the song wheel.
--
-- The second step of music selection.  ScreenVOLT26SelectPack has already
-- chosen the pack and made one of its songs current, and the [VOLT26SongWheel]
-- wheel lists that pack alone.  Back (or the close-folder buttons) returns to
-- the pack step through VOLT26.Navigation.
--
-- The layout follows Simply Love's: the engine MusicWheel fills the right side
-- of the screen and the left side shows the selected song, its charts and one
-- pane per player.  The engine keeps ownership of the wheel, chart selection,
-- sample music and the flow to options and gameplay; this overlay presents
-- them.  Everything is laid out in the 1920x1080 design space of the shared
-- music kit and scaled to the real screen.

local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local S = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/State.lua"), K)
local G = VOLT26.MusicSelection.Wheel

local modalOpen = false

local function part(file, params)
	return LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/" .. file), params)
end

local function leaveMusicSelection()
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return end
	pcall(function() screen:SetPrevScreenName(VOLT26.Navigation.LeaveMusicSelection()) end)
	screen:Cancel()
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		VOLT26.MusicSelection.PrepareScreen()
	end,
	OnCommand=function(self)
		local wheel = K.Wheel()
		if wheel then
			-- The pack step works on the group sort: the wheel opens the section
			-- of the song it made current.
			if not GAMESTATE:IsCourseMode() and GAMESTATE:GetSortOrder() ~= "SortOrder_Group" then
				wheel:ChangeSort("SortOrder_Group")
			end
			-- The wheel is the screen's own actor rather than a child of this
			-- overlay, so it gets the design scale here; its origin is the
			-- left edge of the rows, on the row the selection sits on.
			wheel:xy(K.Left + G.X * K.Scale, K.Top + G.CenterY * K.Scale):zoom(K.Scale)
		end
	end,

	PlayerProfileSetMessageCommand=function(self, params)
		VOLT26.MusicSelection.RefreshPlayer(params.Player, true)
	end,
	PlayerJoinedMessageCommand=function(self, params)
		VOLT26.MusicSelection.RefreshPlayer(params.Player, false)
	end,
	VOLT26ModalOverlayOpenedMessageCommand=function(self) modalOpen = true end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) modalOpen = false end,
	CodeMessageCommand=function(self, params)
		if params.Name == "Favorite1" or params.Name == "Favorite2" then
			VOLT26.Favorites.ToggleCurrent(params.PlayerNumber)
		elseif params.Name == "EscapeFromEventMode" then
			leaveMusicSelection()
		elseif params.Name == "ClosePack" then
			if not GAMESTATE:IsCourseMode() and not modalOpen then
				SCREENMAN:GetTopScreen():Cancel()
			end
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

}

-- Behaviour only, no visuals ----------------------------------------------

-- Some of these files only run code and return nothing; a nil in the child
-- list would leave a hole in it, so they stand as an empty actor instead.
local function behaviour(path)
	return LoadActor(path) or Def.Actor{}
end

-- Keeps the menu timer's remaining seconds when leaving for player options and
-- coming back.
af[#af+1] = behaviour("./PreserveMenuTimer.lua")
-- Reapplies the profile's player modifiers.
af[#af+1] = behaviour("./PlayerModifiers.lua")
-- Lets single, double and routine charts share the wheel.
af[#af+1] = behaviour("./AutoSetStyle.lua")

-- The sort menu cancels a score request on this child before it changes
-- screens.  Song Select makes no such request, so it is an empty stand-in.
af[#af+1] = Def.ActorFrame{
	Name="PaneDisplayMaster",
	Def.Actor{ Name="GetScoresRequester", CancelCommand=function(self) end },
}

-- Presentation -------------------------------------------------------------

local function schedule(self)
	self:stoptweening():sleep(0.03):queuecommand("Settled")
end

local layout = Def.ActorFrame{
	Name="SongWheelLayout",
	InitCommand=function(self) self:xy(K.Left, K.Top):zoom(K.Scale) end,
	OnCommand=function(self)
		self:queuecommand("Settled")
		-- A safety net for changes the engine does not announce: compare a
		-- small key a few times a second and refresh when it moves.
		local elapsed = 0
		self:SetUpdateFunction(function(frame, delta)
			elapsed = elapsed + (delta or 0)
			if elapsed < 0.25 then return end
			elapsed = 0
			local key = table.concat({
				tostring(S.Item()), tostring(S.Chart(PLAYER_1)), tostring(S.Chart(PLAYER_2)),
				tostring(#GAMESTATE:GetHumanPlayers()),
			}, "|")
			if key ~= frame.refreshKey then
				frame.refreshKey = key
				schedule(frame)
			end
		end)
	end,
	OffCommand=function(self) self:SetUpdateFunction(nil) end,
	SettledCommand=function(self) self:playcommand("Refresh") end,

	CurrentSongChangedMessageCommand=schedule,
	CurrentCourseChangedMessageCommand=schedule,
	CurrentStepsP1ChangedMessageCommand=schedule,
	CurrentStepsP2ChangedMessageCommand=schedule,
	CurrentTrailP1ChangedMessageCommand=schedule,
	CurrentTrailP2ChangedMessageCommand=schedule,
	PlayerJoinedMessageCommand=schedule,
	PlayerUnjoinedMessageCommand=schedule,
	PlayerProfileSetMessageCommand=schedule,
}

-- The details column steps aside while a modal overlay (sort menu, quick
-- mods, song search, leaderboard, input test) owns the screen.
local details = Def.ActorFrame{
	Name="Details",
	VOLT26ModalOverlayOpenedMessageCommand=function(self) self:visible(false) end,
	VOLT26ModalOverlayClosedMessageCommand=function(self) self:visible(true) end,
}
details[#details+1] = part("SongInfo.lua", { K=K, S=S })
details[#details+1] = part("Charts.lua", { K=K, S=S })
details[#details+1] = part("PlayerPane.lua", { K=K, S=S, Player=PLAYER_1 })
details[#details+1] = part("PlayerPane.lua", { K=K, S=S, Player=PLAYER_2 })
layout[#layout+1] = details
layout[#layout+1] = part("Header.lua", { K=K, S=S })
layout[#layout+1] = part("Footer.lua", { K=K })
af[#af+1] = layout

-- Shared modal overlays, in their original draw order -----------------------
af[#af+1] = LoadActor("./SortMenu/default.lua")
af[#af+1] = LoadActor("./QuickMods/default.lua")
af[#af+1] = LoadActor("./TestInput.lua")
af[#af+1] = LoadActor("./Leaderboard.lua")
af[#af+1] = LoadActor("./SongSearch/default.lua")

-- Use Song Select idle time to prepare the small shared gameplay/evaluation
-- textures before the player confirms a chart.
af[#af+1] = VOLT26.Warmup.CreateActor("Play", {Interval=0.12})

return af
