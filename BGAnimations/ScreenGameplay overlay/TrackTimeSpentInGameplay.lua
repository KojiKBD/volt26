-- We want to be able to display the time spent in gameplay across the entire set
-- for ScreenGameover.  We could call GAMESTATE:GetCurrentSong():MusicLengthSeconds(),
-- store that, and sum each value at ScreenGameover, but that wouldn't (easily) handle
-- early quitting/escaping out of songs accurately.
--
-- So instead, calculate the duration of time actually spent in ScreenGameplay when its
-- OffCommand is called.
------------------------------------------------------------

local player = ...
local actor = Def.Actor{
	OnCommand=function(self)
		VOLT26.Session.BeginGameplay(player, GetTimeSinceStart())
		self:SetUpdateFunction(function()
			local screen = SCREENMAN:GetTopScreen()
			local paused = screen and screen.IsPaused and screen:IsPaused() or false
			VOLT26.Session.SetGameplayPaused(player, paused, GetTimeSinceStart())
		end)
	end,
	OffCommand=function(self)
		self:SetUpdateFunction(nil)
		VOLT26.Session.FinishGameplay(player, GetTimeSinceStart())
	end
}

return actor
