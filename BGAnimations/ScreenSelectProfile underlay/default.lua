-- ScreenSelectProfile.
--
-- Who is playing, asked as a strip of cards: [ GUEST ] first, then every local
-- profile, with a panel beside it describing whichever card the cursor is on.
-- The engine still owns joining, unjoining, memory cards and the profile
-- assignment itself; this screen owns the cursor and the presentation, and
-- hands the engine an index when it finishes.
--
-- The pieces:
--   Selection.lua          the cursor, the window, and who has committed
--   PlayerFrame.lua        one player's strip and panel
--   Input.lua              buttons
--   PlayerProfileData.lua  what is known about each local profile
--   _volt26 select chrome  the frame this screen shares with the play-mode screen

local Chrome = LoadActor(THEME:GetPathB("", "_volt26 select chrome"))

-- PreferredStyle is a VOLT26 preference that can allow players to always
-- automatically have one of [single, double, versus] chosen for them.
-- If PreferredStyle is either "single" or "double", we don't want to load
-- frames for both PLAYER_1 and PLAYER_2, but only the MasterPlayerNumber
local PreferredStyle = VOLT26.Profile.GetPreferredStyle()

-- a table of profile data (display name, songs played, mods, etc.)
local profile_data = LoadActor("./PlayerProfileData.lua")

local Selection = LoadActor("./Selection.lua", {ProfileData=profile_data})

-- Whether the screen is showing one player across the full width or two
-- players either side of the centre line.
local single = (PreferredStyle=="single" or PreferredStyle=="double") and #GAMESTATE:GetHumanPlayers() <= 1
local players = single and { GAMESTATE:GetMasterPlayerNumber() } or { PLAYER_1, PLAYER_2 }

-- ----------------------------------------------------------------------------
-- Which of the three states each side is in.  A side is either waiting to be
-- joined, browsing the strip, or locked to a memory card.

local HandleStateChange = function(self, Player)
	local frame = self:GetChild(ToEnumShortString(Player) .. 'Frame')
	if not frame then return end

	if not GAMESTATE:IsHumanPlayer(Player) then
		frame:playcommand("SetState", {State="join"})
		return
	end

	if MEMCARDMAN:GetCardState(Player) ~= 'MemoryCardState_none' then
		frame:playcommand("SetState", {State="card"})
		SCREENMAN:GetTopScreen():SetProfileIndex(Player, 0)
		return
	end

	frame:playcommand("SetState", {State="browse"})
end

-- ----------------------------------------------------------------------------
-- Opening position: a player starts on the profile they are already using
-- (fast switch) or on their default profile, and otherwise on [ GUEST ].

local function FocusInitialProfile(player)
	if VOLT26.Profile.IsFastSwitchInProgress() and PROFILEMAN:IsPersistentProfile(player) then
		local current = PROFILEMAN:GetProfile(player)
		if current then
			for profile in ivalues(profile_data) do
				if profile.guid == current:GetGUID() then
					Selection.FocusEngineIndex(player, profile.index)
					return
				end
			end
		end
	end

	local default_id = PREFSMAN:GetPreference("DefaultLocalProfileID"..ToEnumShortString(player))
	if default_id and default_id ~= "" then
		Selection.FocusProfileDir(player, PROFILEMAN:LocalProfileIDToDir(default_id))
	end
end

for player in ivalues(players) do FocusInitialProfile(player) end

-- ----------------------------------------------------------------------------

local invalid_count = 0

local t = Def.ActorFrame {

	InitCommand=function(self) self:queuecommand("Stall") end,
	StallCommand=function(self)
		-- FIXME: Stall for 0.5 seconds so that the Lua InputCallback doesn't get immediately added to the screen.
		-- It's otherwise possible to enter the screen with MenuLeft/MenuRight already held and firing off events,
		-- which causes the list of profile names to not display.  I don't have time to debug it right now.
		self:sleep(0.5):queuecommand("InitInput")

		-- FIXME: I need to find time to look at how the engine actually handles MenuTimers because
		-- including an Actor command that queues itself every 0.5 seconds to check the MenuTimer on custom
		-- screens like this (and ScreenPlayAgain, etc.) seems like it should be unnecessary.)
		if VOLT26.MenuTimer.IsEnabled() then
			self:queuecommand("CheckMenuTimer")
		end
	end,
	InitInputCommand=function(self)
		SCREENMAN:GetTopScreen():AddInputCallback( LoadActor("./Input.lua", {af=self, Selection=Selection}) )
	end,

	CheckMenuTimerCommand=function(self)
		-- if the MenuTimer has reached 0, it's time to queue the OffCommand and force a transition to the next screen
		if SCREENMAN:GetTopScreen():GetChild("Timer"):GetSeconds() <= 0 then

			-- It's possible that both players had the same local profile selected when the MenuTimer
			-- reached 0.  Queueing the OffCommand like this would assign the same local profile to
			-- both players.  Though engine permits this, it is unclear whether that is intentional
			-- or oversight, and I've yet to meet anyone who has requested such a feature.
			-- So, if the MenuTimer reaches 0 and both players are on the same non-GUEST profile
			-- we'll set them both to GUEST before transitioning.
			if #GAMESTATE:GetHumanPlayers() > 1
			and Selection.Get(PLAYER_1).index == Selection.Get(PLAYER_2).index
			and Selection.Get(PLAYER_1).index ~= 0 then
				Selection.SetCursor(PLAYER_1, 1)
				Selection.SetCursor(PLAYER_2, 1)
				self:playcommand("Redraw")
				self:sleep(0.3)
			end

			self:queuecommand("Off")
		else
			self:sleep(0.5):queuecommand("CheckMenuTimer")
		end
	end,

	-- the OffCommand will have been queued, when it is appropriate, from ./Input.lua
	-- sleep for 0.5 seconds to give the frames time to tween out
	-- and queue a call to Finish() so that the engine can wrap things up
	OffCommand=function(self)
		-- Update the lobby state in case we're online. This won't do anything
		-- if we're not connected to a lobby.
		-- Replace the screen with ScreenSelectMusic so we don't send ScreenSelectProfile as the
		-- current screen to the lobby.
		MESSAGEMAN:Broadcast("UpdateOnlineState", {screenName="ScreenSelectMusic"})
		self:sleep(0.5):queuecommand("Finish")
	end,
	FinishCommand=function(self)
		-- Loop through the enum for PlayerNumber that the engine has exposed to Lua.
		for player in ivalues( PlayerNumber ) do
			-- check if this player is joined in
			if GAMESTATE:IsHumanPlayer(player) then
				-- the item this player's cursor is on; [ GUEST ] carries index 0
				local item = Selection.Get(player)
				local index = type(item)=="table" and item.index or 0

				-- the engine's SetProfileIndex() method expects local profiles to use index values that are > 0
				-- it also uses the following hardcoded values:
				--   0: use the USB memory card associated with this player
				--  -1: join the player and play the theme's start sound effect
				--  -2: unjoin the player, unlock their memorycard, and unmount their memorycard
				--  -3: allow the user to play without a profile (USB or local)

				-- check for and handle USB memorycards first
				if MEMCARDMAN:GetCardState(player) ~= 'MemoryCardState_none' then
					SCREENMAN:GetTopScreen():SetProfileIndex(player, 0)

				-- local profile
				elseif index > 0 then
					SCREENMAN:GetTopScreen():SetProfileIndex(player, index)

				-- [ GUEST ]: the engine's own Finish() hardcodes DefaultProfileIDs, which would
				-- interfere with VOLT26's notion of NOT requiring all players to use profiles.
				-- If the player went out of their way to enable ScreenSelectProfile, they presumably
				-- want to be able to pick, and picking means having an option for not-using-a-profile.
				elseif index == 0 then
					PREFSMAN:SetPreference("DefaultLocalProfileIDP1", "")
					PREFSMAN:SetPreference("DefaultLocalProfileIDP2", "")

					-- Passing -3 to SetProfileIndex() will allow the player to play without a profile
					SCREENMAN:GetTopScreen():SetProfileIndex(player, -3)
				end
			end
		end

		if VOLT26.Profile.IsFastSwitchInProgress() then
			VOLT26.Profile.FinishFastSwitch()
			-- Check if one of the players has a memory card
			-- If so, we need to reload the screen to update the profile data
			-- Otherwise, we can just finish the screen
			if MEMCARDMAN:GetCardState(PLAYER_1) ~= 'MemoryCardState_none' or MEMCARDMAN:GetCardState(PLAYER_2) ~= 'MemoryCardState_none' then
				MESSAGEMAN:Broadcast("ReloadScreenForMemoryCards")
			end
		end
		SCREENMAN:GetTopScreen():Finish()
	end,

	CodeMessageCommand=function(self, params)

		if (PreferredStyle=="single" or PreferredStyle=="double" or #GAMESTATE:GetHumanPlayers() > 1 ) and params.PlayerNumber ~= GAMESTATE:GetMasterPlayerNumber()  then return end

		-- Don't allow players to unjoin from SelectProfile in CoinMode_Pay.
		-- 1 credit has already been deducted from ScreenTitleJoin, so allowing players
		-- to unjoin would mean we'd have to handle credit refunding (or something).
		if GAMESTATE:GetCoinMode() == "CoinMode_Pay" then return end

		if params.Name == "Select" then
			if GAMESTATE:GetNumPlayersEnabled()==0 then
				if VOLT26.Profile.IsFastSwitchInProgress() then
					MESSAGEMAN:Broadcast("PreventEscape")
				else
					SCREENMAN:GetTopScreen():Cancel()
				end
			else
				-- CurrentStyle has to be explicitly set to single in order to be able to
				-- unjoin a player from a 2-player setup
				if VOLT26.Profile.IsFastSwitchInProgress() and GAMESTATE:GetNumSidesJoined() == 1 then
					GAMESTATE:SetCurrentStyle("single")
					SCREENMAN:GetTopScreen():playcommand("Update")
				end
			end
		end
	end,

	-- various events can occur that require us to reassess what we're drawing
	OnCommand=function(self) self:queuecommand('Update') end,
	StorageDevicesChangedMessageCommand=function(self) self:queuecommand('Update') end,
	PlayerJoinedMessageCommand=function(self, params) self:playcommand('Update', {player=params.Player}) end,
	PlayerUnjoinedMessageCommand=function(self, params) self:playcommand('Update', {player=params.Player}) end,
	SelectedProfileMessageCommand=function(self, params)
		MESSAGEMAN:Broadcast("VOLT26ProfileReady", {PlayerNumber=params.PlayerNumber})
	end,
	UnselectedProfileMessageCommand=function(self, params)
		MESSAGEMAN:Broadcast("VOLT26ProfileReady", {PlayerNumber=params.PlayerNumber})
	end,

	-- there are several ways to get here, but if we're here, we'll just
	-- punt to HandleStateChange() to reassess what is being drawn
	UpdateCommand=function(self, params)
		if params and params.player then
			HandleStateChange(self, params.player)
			return
		end

		if single then
			HandleStateChange(self, GAMESTATE:GetMasterPlayerNumber())
		else
			HandleStateChange(self, PLAYER_1)
			HandleStateChange(self, PLAYER_2)
		end
	end,

	-- sounds
	LoadActor( THEME:GetPathS("Common", "start") )..{
		IsAction=true,
		StartButtonMessageCommand=function(self) self:play() end
	},
	LoadActor( THEME:GetPathS("ScreenSelectMusic", "select down") )..{
		IsAction=true,
		BackButtonMessageCommand=function(self) self:play() end
	},
	LoadActor( THEME:GetPathS("ScreenSelectMaster", "change") )..{
		IsAction=true,
		DirectionButtonMessageCommand=function(self)
			self:play()
			if invalid_count then invalid_count = 0 end
		end
	},
	LoadActor( THEME:GetPathS("Common", "invalid") )..{
		IsAction=true,
		InvalidChoiceMessageCommand=function(self)
			self:play()
			if PREFSMAN:GetPreference("EasterEggs") and invalid_count then
				invalid_count = invalid_count + 1
				if invalid_count >= 10 then MESSAGEMAN:Broadcast("What"); invalid_count = nil end
			end
		end
	},
	LoadActor( THEME:GetPathS("", "what.ogg") )..{
		WhatMessageCommand=function(self) self:play() end
	}
}

-- ----------------------------------------------------------------------------
-- get table of player avatar paths

local avatars = {}
for profile in ivalues(profile_data) do
	if profile.dir and profile.displayname then
		avatars[profile.index] = VOLT26.Profile.GetAvatarPath(profile.dir, profile.displayname)
	end
end

-- if we're fast profile switching, dim the song wheel in the background
if VOLT26.Profile.IsFastSwitchInProgress() then
	t[#t+1] = Def.Quad {
		InitCommand=function(self)
			self:FullScreen():diffuse(Color.Black):diffusealpha(0.8)
		end
	}
end

-- ----------------------------------------------------------------------------
-- chrome

t[#t+1] = Chrome.TitleBlock{
	title = THEME:GetString("ScreenSelectProfile", "TitleProfile"),
	tabs = { "Profile", "Mode" },
	active = "Profile",
}

t[#t+1] = Chrome.SectionLabel( THEME:GetString("ScreenSelectProfile", "SectionWhoIsPlaying") )

t[#t+1] = Chrome.Hints{
	button = THEME:GetString("ScreenSelectProfile", "HintButton"),
	action = THEME:GetString("ScreenSelectProfile", "HintConfirm"),
	center = PREFSMAN:GetPreference("EventMode")
		and THEME:GetString("ScreenSelectProfile", "EventMode")
		or nil,
}

-- a quiet note under the strip: the choice lasts the whole session
t[#t+1] = Chrome.Label{
	text = THEME:GetString("ScreenSelectProfile", "SessionNote"), px=9,
	x = Chrome.Metrics.Margin, y = single and 324 or 284,
	color = Chrome.Color.Faint,
}

-- ----------------------------------------------------------------------------
-- player frames

for player in ivalues(players) do
	t[#t+1] = LoadActor("PlayerFrame.lua", {
		Player = player,
		Selection = Selection,
		ProfileData = profile_data,
		Avatars = avatars,
		Chrome = Chrome,
		Layout = single and "full" or "split",
	})
end

return t
