-- Name entry input (Simply Love's, for the VOLT26 layout: each player's
-- pieces live in their half, "Half" .. pn, of the underlay's root).
local args = ...
local t = args[1]
local AlphabetWheels = args[2]

-- the highscore name character limit
local CharacterLimit = 4

local function part(pn, name)
	local half = t:GetChild("Half" .. pn)
	return half and half:GetChild(name)
end

local function entry(pn, name)
	local e = part(pn, "PlayerNameAndDecorations_" .. pn)
	return e and e:GetChild(name)
end

local InputHandler = function(event)
	if not event.PlayerNumber or not event.button then return false end

	local function RemoveLastCharacter(pn)
		if SL[pn].HighScores.Name:len() > 0 then
			SL[pn].HighScores.Name = SL[pn].HighScores.Name:sub(1, -2)
			entry(pn, "PlayerName"):queuecommand("Set")
			t:GetChild("delete"):playforplayer(event.PlayerNumber)
		else
			t:GetChild("invalid"):playforplayer(event.PlayerNumber)
		end
	end

	if event.type ~= "InputEventType_Release" then
		local pn = ToEnumShortString(event.PlayerNumber)
		-- Player 2's half is mirrored, but the alphabet still reads left to
		-- right, so left and right keep their meaning.
		if event.GameButton == "MenuRight" and SL[pn].HighScores.EnteringName then
			AlphabetWheels[pn]:scroll_by_amount(1)
			t:GetChild("move"):playforplayer(event.PlayerNumber)

		elseif event.GameButton == "MenuLeft" and SL[pn].HighScores.EnteringName then
			AlphabetWheels[pn]:scroll_by_amount(-1)
			t:GetChild("move"):playforplayer(event.PlayerNumber)

		elseif event.GameButton == "Start" then
			if SL[pn].HighScores.EnteringName then
				local SelectedCharacter = AlphabetWheels[pn]:get_info_at_focus_pos()

				if SelectedCharacter == "&OK;" then
					SL[pn].HighScores.EnteringName = false
					entry(pn, "Cursor"):queuecommand("Hide")
					part(pn, "AlphabetWheel_" .. pn):queuecommand("Hide")
					t:GetChild("enter"):playforplayer(event.PlayerNumber)

				elseif SelectedCharacter == "&BACK;" then
					RemoveLastCharacter(pn)

				else
					if SL[pn].HighScores.Name:len() < CharacterLimit then
						SL[pn].HighScores.Name = SL[pn].HighScores.Name .. SelectedCharacter
						entry(pn, "PlayerName"):queuecommand("Set")
						t:GetChild("enter"):playforplayer(event.PlayerNumber)
					else
						t:GetChild("invalid"):playforplayer(event.PlayerNumber)
					end

					if SL[pn].HighScores.Name:len() >= CharacterLimit then
						AlphabetWheels[pn]:scroll_to_pos(2)
					end
				end
			end

			t:queuecommand("AttemptToFinish")

		elseif event.GameButton == "Select" and SL[pn].HighScores.EnteringName then
			RemoveLastCharacter(pn)
		end
	end

	return false
end

return InputHandler
