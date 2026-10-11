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
--
-- The pack step and this screen are drawn to read as one screen: the same
-- backdrop, header and footer bands (K.Chrome) that fade in over it, and the
-- pack jacket that shrinks into this
-- header's badge on the way in grows back out of it on the way out.  Arriving
-- from the pack step the wheel slides in from the right and the details from
-- the left; Back plays the reverse before the (motion-only) cancel transition
-- hands over to the pack step.

local K = LoadActor(THEME:GetPathB("", "_volt26 music kit.lua"))
local S = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/State.lua"), K)
local G = VOLT26.MusicSelection.Wheel

local modalOpen = false
local leaving = false
local handoff = not GAMESTATE:IsCourseMode() and VOLT26.PackSelection.TakeHandoff() or nil
local WHEEL_SLIDE = 920        -- design units the wheel travels in and out
local DETAILS_SLIDE = 40

local function part(file, params)
	return LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/" .. file), params)
end

local overlay

local function layoutPart(name)
	return overlay and overlay:GetChild("SongWheelLayout"):GetChild(name) or nil
end

local function leaveMusicSelection()
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return end
	leaving = true
	-- Leaving music selection altogether: no hand-off, everything fades.
	local wheel = K.Wheel()
	if wheel then wheel:stoptweening():linear(0.2):diffusealpha(0) end
	if overlay then layoutPart("Details"):stoptweening():linear(0.2):diffusealpha(0) end
	pcall(function() screen:SetPrevScreenName(VOLT26.Navigation.LeaveMusicSelection()) end)
	screen:Cancel()
end

-- Arriving from the pack step: the badge is already in place (the jacket just
-- shrank into it), so the wheel slides in under it and the details follow.
local function enterFromPacks()
	local wheel = K.Wheel()
	if wheel then
		wheel:stoptweening():addx(WHEEL_SLIDE * K.Scale):diffusealpha(0)
			:decelerate(K.HandoffSeconds):addx(-WHEEL_SLIDE * K.Scale):diffusealpha(1)
	end
	layoutPart("Details"):stoptweening():addx(-DETAILS_SLIDE):diffusealpha(0)
		:sleep(0.06):decelerate(K.HandoffSeconds):addx(DETAILS_SLIDE):diffusealpha(1)
	layoutPart("Header"):playcommand("SongWheelIn")
	-- The pack step has no bands: they fade in here and out on the way back.
	layoutPart("Chrome"):stoptweening():diffusealpha(0):linear(K.HandoffSeconds):diffusealpha(1)
		:playcommand("ChromeIn")
end

-- Back to the pack step: the reverse.  Everything but the badge leaves; the
-- pack step then grows its jacket out of the badge.
local function leaveToPacks()
	if leaving or modalOpen or GAMESTATE:IsCourseMode() then return end
	local screen = SCREENMAN:GetTopScreen()
	if not screen then return end
	leaving = true
	VOLT26.PackSelection.SetHandoff("FromSongWheel")
	local wheel = K.Wheel()
	if wheel then
		wheel:stoptweening():accelerate(0.24):addx(WHEEL_SLIDE * K.Scale):diffusealpha(0)
	end
	layoutPart("Details"):stoptweening():accelerate(0.2):addx(-DETAILS_SLIDE):diffusealpha(0)
	layoutPart("Header"):playcommand("SongWheelOut")
	layoutPart("Chrome"):stoptweening():linear(0.2):diffusealpha(0)
	screen:Cancel()
end

-- Back is taken here rather than left to the engine so the motion and the
-- screen change start together.  Whichever of the two reaches Cancel first
-- wins; the other is ignored by the screen.
local function input(event)
	if not event or event.type ~= "InputEventType_FirstPress" then return false end
	if event.GameButton ~= "Back" or not event.PlayerNumber then return false end
	-- A modal overlay redirects input away from the engine; Back belongs to it.
	local ok, redirected = pcall(function() return SCREENMAN:get_input_redirected(event.PlayerNumber) end)
	if ok and redirected then return false end
	leaveToPacks()
	return false
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		overlay = self
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
		if handoff == "ToSongWheel" then enterFromPacks() end
		if not GAMESTATE:IsCourseMode() then SCREENMAN:GetTopScreen():AddInputCallback(input) end
	end,
	OffCommand=function(self)
		leaving = true
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:RemoveInputCallback(input) end
	end,
	-- The selection is final: Back no longer means "back to the packs".
	SongChosenMessageCommand=function(self) leaving = true end,
	ShowPressStartForOptionsCommand=function(self) leaving = true end,

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
			leaveToPacks()
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
		-- Refreshed at once rather than queued, so the header badge is in place
		-- on the first frame, where the pack step's jacket just landed.
		self:playcommand("Refresh")
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
local hintKeys = GAMESTATE:IsCourseMode()
	and { "HintPlay", "HintMenu", "HintExit" }
	or { "HintPlay", "HintPacks", "HintMenu" }
local hints = {}
for _, key in ipairs(hintKeys) do hints[#hints+1] = K.String(key) end

layout[#layout+1] = details
layout[#layout+1] = K.Chrome{
	Title = K.String(GAMESTATE:IsCourseMode() and "CourseTitle" or "SongTitle"),
	Hints = table.concat(hints, "        "),
}
layout[#layout+1] = part("Header.lua", { K=K, S=S })
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
