local Players = GAMESTATE:GetHumanPlayers()
local NumPanes = VOLT26.Gameplay.IsCasual() and 1 or 8

local callbackController = VOLT26.EvaluationInput.NewCallbackController()
local inputHandler, diagnosticInputHandler, eventOverlayInputHandler, shortcutInputHandler

if ThemePrefs.Get("WriteCustomScores") then
	WriteScores()
end

local t = Def.ActorFrame{Name="ScreenEval Common"}

if not VOLT26.Gameplay.IsCasual() then
	local function redirectPlayers(redirected)
		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, redirected)
		end
	end

	local function activateStandardInput()
		callbackController:Deactivate("event")
		callbackController:Activate("panes", inputHandler)
		callbackController:Activate("diagnostics", diagnosticInputHandler)
		callbackController:Activate("shortcuts", shortcutInputHandler)
		redirectPlayers(false)
	end

	t.OnCommand=function(self)
		inputHandler = LoadActor("./InputHandler.lua", {self, NumPanes})
		diagnosticInputHandler = LoadActor("./Shared/DiagnosticInputHandler.lua")
		eventOverlayInputHandler = LoadActor("./Shared/EventInputHandler.lua")
		if VOLT26.EvaluationInput.CanUseReplayPracticeShortcuts() then
			shortcutInputHandler = VOLT26.EvaluationInput.CreateReplayPracticeHandler()
		end
		activateStandardInput()
		PROFILEMAN:SaveMachineProfile()
	end
	t.DirectInputToEngineCommand=function(self)
		activateStandardInput()
	end
	t.DirectInputToEventOverlayHandlerCommand=function(self)
		if not eventOverlayInputHandler then return end
		callbackController:Deactivate("panes")
		callbackController:Deactivate("diagnostics")
		callbackController:Deactivate("shortcuts")
		callbackController:Activate("event", eventOverlayInputHandler)
		redirectPlayers(true)
	end
	t.OffCommand=function(self)
		callbackController:Clear()
		redirectPlayers(false)
	end
else
	t.OnCommand=function(self)
		PROFILEMAN:SaveMachineProfile()
	end
end

-- -----------------------------------------------------------------------
-- First, add actors that would be the same whether 1 or 2 players are joined.

-- code for triggering a screenshot and animating a "screenshot" texture
t[#t+1] = LoadActor("./Shared/ScreenshotHandler.lua")

-- favorite shortcuts are independent from screenshot capture
t[#t+1] = LoadActor("./Shared/FavoriteHandler.lua")

-- the title of the song and its graphical banner, if there is one
t[#t+1] = LoadActor("./Shared/TitleAndBanner.lua")

-- text to display BPM range (and ratemod if ~= 1.0) and song length immediately
-- under the banner
t[#t+1] = LoadActor("./Shared/SongFeatures.lua")

-- store some attributes of this playthrough of this song in the global SL table
-- for later retrieval on ScreenEvaluationSummary
t[#t+1] = LoadActor("./Shared/GlobalStorage.lua")

-- help text that appears if we're in Casual gamemode
t[#t+1] = LoadActor("./Shared/CasualHelpText.lua")

-- -----------------------------------------------------------------------
-- Then, load player-specific actors.

for player in ivalues(Players) do

	-- store player stats for later retrieval on EvaluationSummary and NameEntryTraditional
	-- this doesn't draw anything to the screen, it just runs some code
	t[#t+1] = LoadActor("./PerPlayer/Storage.lua", player)

	-- the per-player upper half of ScreenEvaluation, including: letter grade, nice
	-- stepartist, difficulty text, difficulty meter, machine/personal HighScore text
	t[#t+1] = LoadActor("./PerPlayer/Upper/default.lua", player)

	-- the per-player lower half of ScreenEvaluation, including:
	-- judgment scatterplot, modifier list, disqualified text
	t[#t+1] = LoadActor("./PerPlayer/Lower/default.lua", player)

	-- Generate the .itl file for the player.
	-- When the event isn't active, this actor is nil.
	t[#t+1] = LoadActor("./PerPlayer/ItlFile.lua", player)
end

-- -----------------------------------------------------------------------
-- Then load the Panes.

t[#t+1] = LoadActor("./Panes/default.lua", NumPanes)

-- -----------------------------------------------------------------------

-- The actor that will automatically upload scores to GrooveStats.
-- This is only added in "dance" mode and if the service is available.
-- Since this actor also spawns the event overlay it must go on top of everything else
t[#t+1] = LoadActor("./Shared/AutoSubmitScore.lua")

return t
