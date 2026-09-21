-- a reference to the primary ActorFrame
local args = ...
local t = args[1]
local AlphabetWheels = args[2]

-- the highscore name character limit
local CharacterLimit = 4

-- Define the input handler
local InputHandler = function(event)

	if not event.PlayerNumber or not event.button then
		return false
	end

	-- a local function to delete a character from a player's highscore name
	local function RemoveLastCharacter(pn)
		if VOLT26[pn].HighScores.Name:len() > 0 then
			-- remove the last character
			VOLT26[pn].HighScores.Name = VOLT26[pn].HighScores.Name:sub(1, -2)
			-- update the display
			t:GetChild("PlayerNameAndDecorations_"..pn):GetChild("PlayerName"):queuecommand("Set")
			-- play the "delete" sound
			t:GetChild("delete"):playforplayer(event.PlayerNumber)
		else
			-- there's nothing to delete, so play the "invalid" sound
			t:GetChild("invalid"):playforplayer(event.PlayerNumber)
		end
	end


	if event.type ~= "InputEventType_Release" then
		local pn = ToEnumShortString(event.PlayerNumber)

		if event.GameButton == "MenuRight" and VOLT26[pn].HighScores.EnteringName then
			-- scroll this player's AlphabetWheel right by 1
			AlphabetWheels[pn]:scroll_by_amount(1)
			t:GetChild("move"):playforplayer(event.PlayerNumber)

		elseif event.GameButton == "MenuLeft" and VOLT26[pn].HighScores.EnteringName then
			-- scroll this player's AlphabetWheel left by 1
			AlphabetWheels[pn]:scroll_by_amount(-1)
			t:GetChild("move"):playforplayer(event.PlayerNumber)

		elseif event.GameButton == "Start" then

			if VOLT26[pn].HighScores.EnteringName then
				-- This gets us the value selected out of the PossibleCharacters table
				local SelectedCharacter = AlphabetWheels[pn]:get_info_at_focus_pos()

				if SelectedCharacter == "&OK;" then
					VOLT26[pn].HighScores.EnteringName = false
					-- hide this player's cursor
					t:GetChild("PlayerNameAndDecorations_"..pn):GetChild("Cursor"):queuecommand("Hide")
					-- hide this player's AlphabetWheel
					t:GetChild("AlphabetWheel_"..pn):queuecommand("Hide")
					-- play the "enter" sound
					t:GetChild("enter"):playforplayer(event.PlayerNumber)

				elseif SelectedCharacter == "&BACK;" then
					RemoveLastCharacter(pn)

				else -- it must be a normal character
					if VOLT26[pn].HighScores.Name:len() < CharacterLimit then
						-- append the new character
						VOLT26[pn].HighScores.Name = VOLT26[pn].HighScores.Name .. SelectedCharacter
						-- update the display
						t:GetChild("PlayerNameAndDecorations_"..pn):GetChild("PlayerName"):queuecommand("Set")
						-- play the "enter" sound
						t:GetChild("enter"):playforplayer(event.PlayerNumber)
					else
						t:GetChild("invalid"):playforplayer(event.PlayerNumber)
					end

					if VOLT26[pn].HighScores.Name:len() >= CharacterLimit then
						AlphabetWheels[pn]:scroll_to_pos(2)
					end

				end

			end

			-- check if we're ready to save scores and proceed to the next screen
			t:queuecommand("AttemptToFinish")

		elseif event.GameButton == "Select" and VOLT26[pn].HighScores.EnteringName then
			RemoveLastCharacter(pn)
		end
	end

	return false
end

return InputHandler
