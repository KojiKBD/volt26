-- player options objects, used to figure out what mods each player has active
local po = {}
for player in ivalues(GAMESTATE:GetHumanPlayers()) do
	po[player] = GAMESTATE:GetPlayerState(player):GetPlayerOptions('ModsLevel_Song')
end

local callbackActive = false

local InputHandler = function( event )
	if not event.PlayerNumber or not event.button then return false end
	if po[event.PlayerNumber] == nil              then return false end
	if event.type == "InputEventType_Release"     then return false end

	-- check event.button instead of event.MenuButton to ensure the player definitely pressed a dedicated MenuButton.
	-- we don't want to change speed mod if a player has OnlyDedicatedMenuButtons=0 and is, for example, tapping out
	-- the beat on their dance pad before the first note.
	if event.button == "MenuRight" or event.button == "MenuLeft" then
		local speedmod_str, speedmod = VOLT26.CourseSpeed.GetActive(po[event.PlayerNumber])
		if not speedmod_str then return false end
		local direction = event.button == "MenuRight" and 1 or -1
		speedmod = VOLT26.CourseSpeed.Adjust(speedmod_str, speedmod, direction)
		if not speedmod then return false end

		VOLT26.Options.GetPlayerModifiers(event.PlayerNumber).SpeedMod = speedmod

		-- format a GameCommand string like "mod,1.75x" or "mod,c460" or "mod,m900"
		local gcString = VOLT26.CourseSpeed.Format(speedmod_str, speedmod)

		-- apply the new speed mod to the player immediately
		GAMESTATE:ApplyGameCommand(gcString, event.PlayerNumber)

		-- broadcast which player's mods changed so that ScreenGameplay's DisplayMods.lua
		-- can update its BitmapText string to show the player updated text
		MESSAGEMAN:Broadcast("PlayerOptionsChanged", {Player=event.PlayerNumber})
	end

	return false
end

return Def.Actor{
	OnCommand=function(self)                        self:playcommand("AddInputHandler") end,
	CurrentSongChangedMessageCommand=function(self) self:playcommand("AddInputHandler") end,

	OffCommand=function(self)             self:playcommand("RemoveInputHandler") end,
	JudgmentMessageCommand=function(self) self:playcommand("RemoveInputHandler") end,

	AddInputHandlerCommand=function(self)
		if callbackActive then return end
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:AddInputCallback( InputHandler )
			callbackActive = true
		end
	end,
	RemoveInputHandlerCommand=function(self)
		if not callbackActive then return end
		local screen = SCREENMAN:GetTopScreen()
		if screen then
			screen:RemoveInputCallback( InputHandler )
			callbackActive = false
		end
	end
}
