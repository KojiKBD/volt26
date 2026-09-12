local args = ...
local Selection = args.Selection

-- a simple boolean flag we'll use to ignore input once profiles have been
-- selected and the screen's OffCommand has been queued.
--
-- aside: SM's screen class does have a RemoveInputCallback() method,
-- but it needs a reference to the original input handler funtion as
-- a passed-in argument, and that's tricky with how this screen's code is
-- split across multiple files.
local finished = false

-- Whether each side still owes the screen a decision.  A side that is not
-- joined owes nothing, so it starts satisfied.
local readyPlayers = {
	["P1"] = not GAMESTATE:IsSideJoined(PLAYER_1),
	["P2"] = not GAMESTATE:IsSideJoined(PLAYER_2),
}

local PreferredStyle = VOLT26.Profile.GetPreferredStyle()

local Handle = {}

-- ----------------------------------------------------------------------------

local function BothOnSameProfile()
	if PROFILEMAN:GetNumLocalProfiles() <= 0 then return false end
	if #GAMESTATE:GetHumanPlayers() <= 1 then return false end
	if GAMESTATE:IsAnyHumanPlayerUsingMemoryCard() then return false end

	local one, two = Selection.Get(PLAYER_1), Selection.Get(PLAYER_2)
	if not (one and two) then return false end
	-- Two players may both play as [ GUEST ]; they may not both play as the
	-- same saved profile.
	return one.index == two.index and one.index ~= 0
end

-- ----------------------------------------------------------------------------

Handle.Start = function(event)
	-- Nothing to do if the player has already selected a profile
	if GAMESTATE:IsHumanPlayer(event.PlayerNumber) and readyPlayers[ToEnumShortString(event.PlayerNumber)] then return end

	local topscreen = SCREENMAN:GetTopScreen()

	-- if the input event came from a side that is not currently registered as a human player, we'll either
	-- want to reject the input (we're in Pay mode and there aren't enough credits to join the player),
	-- or we'll use ScreenSelectProfile's inscrutably custom SetProfileIndex() method to join the player.
	if not GAMESTATE:IsHumanPlayer(event.PlayerNumber) then

		-- IsArcade() is defined in _fallback/Scripts/02 Utilities.lua
		-- in CoinMode_Free, EnoughCreditsToJoin() will always return true
		-- thankfully, EnoughCreditsToJoin() factors in Premium settings
		if IsArcade() then
			if not GAMESTATE:EnoughCreditsToJoin() then
				-- play the InvalidChoice sound and don't go any further
				MESSAGEMAN:Broadcast("InvalidChoice", {PlayerNumber=event.PlayerNumber})
				return
			else
				if (not VOLT26.Profile.IsFastSwitchInProgress() and
						GAMESTATE:GetCoinMode() == "CoinMode_Pay" and
						(GAMESTATE:GetPremium() ~= "Premium_2PlayersFor1Credit" or
						GAMESTATE:GetNumPlayersEnabled()==0)) then
					-- Consume the credit if:
					-- 1. This side is not joined
					-- 2. We are not fast switching (i.e. in the SelectMusic screen)
					-- 3. We are in coin mode
					-- 4. EITHER Each side needs its own credits
					--    OR neither side is currently joined
					GAMESTATE:InsertCoin(-GAMESTATE:GetCoinsNeededToJoin())
				end
			end
		end

		-- unset the readyPlayers flag for this player since they now
		-- have to make a selection
		readyPlayers[ToEnumShortString(event.PlayerNumber)] = false

		-- otherwise, pass -1 to SetProfileIndex() to join that player
		-- see ScreenSelectProfile.cpp for details
		topscreen:SetProfileIndex(event.PlayerNumber, -1)
	else

		if BothOnSameProfile() and readyPlayers[ToEnumShortString(event.PlayerNumber == PLAYER_1 and PLAYER_2 or PLAYER_1)] then
			-- broadcast an InvalidChoice message to play the "Common invalid" sound
			-- and "shake" the frame for the player that just pressed start
			MESSAGEMAN:Broadcast("InvalidChoice", {PlayerNumber=event.PlayerNumber})
			return
		end

		readyPlayers[ToEnumShortString(event.PlayerNumber)] = true
		Selection.SetReady(event.PlayerNumber, true)
		MESSAGEMAN:Broadcast("SelectedProfile", {PlayerNumber=event.PlayerNumber})

		if readyPlayers["P1"] and readyPlayers["P2"] then
			-- Set finished to true so that we don't process any more input
			finished = true
			-- if we're here, both players have selected a profile
			-- play the StartButton sound
			MESSAGEMAN:Broadcast("StartButton")
			-- and queue the OffCommand for the entire screen
			topscreen:queuecommand("Off"):sleep(0.4)
		end
	end
end
Handle.Center = Handle.Start

-- ----------------------------------------------------------------------------
-- Moving along the strip.  The strip is a row with one player and a column with
-- two, so both axes move the cursor and the layout decides what that looks like.

local function Move(event, delta)
	if readyPlayers[ToEnumShortString(event.PlayerNumber)] then return end
	if not GAMESTATE:IsHumanPlayer(event.PlayerNumber) then return end
	if MEMCARDMAN:GetCardState(event.PlayerNumber) ~= 'MemoryCardState_none' then return end

	if Selection.Move(event.PlayerNumber, delta) then
		MESSAGEMAN:Broadcast("DirectionButton")
		MESSAGEMAN:Broadcast("VOLT26ProfileCursor", {PlayerNumber=event.PlayerNumber})
	end
end

Handle.MenuLeft  = function(event) Move(event, -1) end
Handle.MenuUp    = Handle.MenuLeft
Handle.DownLeft  = Handle.MenuLeft

Handle.MenuRight = function(event) Move(event, 1) end
Handle.MenuDown  = Handle.MenuRight
Handle.DownRight = Handle.MenuRight

-- ----------------------------------------------------------------------------

Handle.Back = function(event)
	if GAMESTATE:GetNumPlayersEnabled()==0 then
		if VOLT26.Profile.IsFastSwitchInProgress() then
			-- Going back to the song wheel without any players connected doesn't
			-- make much sense; disallow dismissing the ScreenSelectProfile
			-- top screen until at least one player has joined in
			MESSAGEMAN:Broadcast("PreventEscape")
		else
			-- On the other hand, dismissing the regular ScreenSelectProfile
			-- (not in fast switch mode) is perfectly fine since we can just go
			-- back to the previous screen
			SCREENMAN:GetTopScreen():Cancel()
		end
	else
		-- If the player is joined, has selected a profile but then pressed back, we
		-- need to unset the readyPlayers flag and go back to the strip.
		if GAMESTATE:IsHumanPlayer(event.PlayerNumber) and
				readyPlayers[ToEnumShortString(event.PlayerNumber)] then
			readyPlayers[ToEnumShortString(event.PlayerNumber)] = false
			Selection.SetReady(event.PlayerNumber, false)
			MESSAGEMAN:Broadcast("BackButton", {PlayerNumber=event.PlayerNumber})
			MESSAGEMAN:Broadcast("UnselectedProfile", {PlayerNumber=event.PlayerNumber})
			return
		end

		-- Otherwise they are unjoining.
		MESSAGEMAN:Broadcast("BackButton", {PlayerNumber=event.PlayerNumber})

		if (GAMESTATE:IsHumanPlayer(event.PlayerNumber) and
				not VOLT26.Profile.IsFastSwitchInProgress() and
				GAMESTATE:GetCoinMode() == "CoinMode_Pay" and
			    (GAMESTATE:GetPremium() ~= "Premium_2PlayersFor1Credit" or
				 GAMESTATE:GetNumPlayersEnabled()==1)) then
			-- Refund credit if:
			-- 1. This side is originally joined
			-- 2. We are not fast switching (i.e. in the SelectMusic screen)
			-- 3. We are in coin mode
			-- 4. EITHER each side needs its own credits
			--    OR we are about to have 0 players joined, thus refunding the original credit.

			-- We originally consumed the credit when the player joined, so we
			-- should refund them if they unjoin.

			-- Use the CoinsPerCredit over GetCoinsNeededToJoin because
			-- it'll report 0 when going from 1 -> 0 players in
			-- Premium_2PlayersFor1Credit mode since a side is currently
			-- joined.
			local coins = PREFSMAN:GetPreference("CoinsPerCredit")
			GAMESTATE:InsertCoin(coins)
		end

		-- set the readyPlayers flag for this player since they no longer
		-- need to make a selection
		readyPlayers[ToEnumShortString(event.PlayerNumber)] = true
		Selection.SetReady(event.PlayerNumber, false)

		-- ScreenSelectProfile:SetProfileIndex() will interpret -2 as
		-- "Unjoin this player and unmount their USB stick if there is one"
		-- see ScreenSelectProfile.cpp for details
		SCREENMAN:GetTopScreen():SetProfileIndex(event.PlayerNumber, -2)

		-- CurrentStyle has to be explicitly set to single in order to be able to
		-- unjoin a player from a 2-player setup
		if VOLT26.Profile.IsFastSwitchInProgress() and GAMESTATE:GetNumSidesJoined() == 1 then
			GAMESTATE:SetCurrentStyle("single")
			-- If PreferredStyle is single then someone had joined during gameplay
			-- We need to explicitly remove this player's join frame
			if (PreferredStyle=="single") then
				SCREENMAN:GetTopScreen():playcommand("Update", {player=event.PlayerNumber})
			else
				SCREENMAN:GetTopScreen():playcommand("Update")
			end
		end

	end
end
Handle.Select = Handle.Back


local InputHandler = function(event)
	if finished then return false end
	if not event or not event.button then return false end
	if (((PreferredStyle=="single" or PreferredStyle=="double") and #GAMESTATE:GetHumanPlayers() == 1) and event.PlayerNumber ~= GAMESTATE:GetMasterPlayerNumber()) then return false	end

	if event.type ~= "InputEventType_Release" then
		if Handle[event.GameButton] then Handle[event.GameButton](event) end
	end
end

return InputHandler
