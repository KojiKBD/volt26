local held = {}
local unmapped_list
local game = GAMESTATE:GetCurrentGame():GetName()
local callback_screen

-- -----------------------------------------------------------------------

local InputHandler = function(event)
	if not (event and event.button) then return false end

	-- allow players to back out of ScreenTestInput by pressing Escape on their keyboard
	if event.GameButton == "Back" and event.type == "InputEventType_FirstPress" then
		SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	end

	if VOLT26.InputDiagnostics.ShouldBroadcast(event) then
		MESSAGEMAN:Broadcast("TestInputEvent", event)
	end

	if event.button == "" then
		VOLT26.InputDiagnostics.UpdateHeldSources(held, event)
		if unmapped_list then unmapped_list:playcommand("Update") end
	end

	return false
end

-- -----------------------------------------------------------------------

local af = Def.ActorFrame {
	OnCommand=function(self)
		if VOLT26.InputDiagnostics.SupportsPadVisuals(game) then
			callback_screen = SCREENMAN:GetTopScreen()
			callback_screen:AddInputCallback(InputHandler)
		end
	end,
	OffCommand=function(self)
		if callback_screen then
			callback_screen:RemoveInputCallback(InputHandler)
			callback_screen = nil
		end
		MESSAGEMAN:Broadcast("ResetInputDiagnostics")
		self:sleep(0.4)
	end,

	Def.DeviceList {
		Font=THEME:GetPathF("","Common Normal"),
		InitCommand=function(self)
			if ThemePrefs.Get("RainbowMode") then self:diffuse(0,0,0,1) end
			self:xy(_screen.cx,_screen.h-60):zoom(0.8)
		end
	}
}

-- for these specific games
if VOLT26.InputDiagnostics.SupportsPadVisuals(game) then

	-- load custom visuals to show which inputs are mapped to game buttons
	for player in ivalues( PlayerNumber ) do
		local pad = LoadActor(THEME:GetPathB("", "_modules/TestInput Pad"), {Player=player, ShowMenuButtons=true, ShowPlayerLabel=true})

		pad.InitCommand=function(self) self:xy(_screen.cx + 150 * (player==PLAYER_1 and -1 or 1), _screen.cy):diffusealpha(0) end
		pad.OnCommand=function(self) self:linear(0.3):diffusealpha(1) end
		pad.OffCommand=function(self) self:linear(0.2):diffusealpha(0) end

		af[#af+1] = pad
	end

	-- and add a custom BitmapText to show which inputs are not mapped to any game buttons
	af[#af+1] = Def.BitmapText{
		Font="Common Normal",
		InitCommand=function(self)
			if ThemePrefs.Get("RainbowMode") then self:diffuse(0,0,0,1) end
			self:xy(_screen.cx, _screen.cy+32):vertalign(top):vertspacing(-3)
			unmapped_list = self
		end,
		UpdateCommand=function(self)
			local labels = VOLT26.InputDiagnostics.GetHeldLabels(held)
			for i, label in ipairs(labels) do
				labels[i] = ("%s (%s)"):format(label, THEME:GetString("ScreenTestInput", "not mapped"))
			end
			self:settext(table.concat(labels, "\n"))
		end

	}

-- for other games (para, kb7), just use a standard InputList provided by the engine
else
	af[#af+1] = Def.InputList{
		Font="Common Normal",
		InitCommand=function(self)
			if ThemePrefs.Get("RainbowMode") then self:diffuse(0,0,0,1) end
			self:xy(_screen.cx-250, 50):horizalign(left):vertalign(top):vertspacing(0)
		end
	}
end

return af
