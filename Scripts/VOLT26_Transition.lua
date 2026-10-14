-- Shared by the menu transition ("_volt26 menu transition.lua"), the screen
-- that holds its cover (ScreenProfileLoad overlay) and the receiver that plays
-- its second half ("_volt26 transition receiver.lua").

VOLT26 = VOLT26 or {}

-- Adds to `frame` one hidden sprite per path, from index `first` on.  A hidden
-- sprite still holds its texture, so a sequence played by Load() on another
-- sprite finds every frame decoded and uploaded already, and keeps it across
-- the screen change (the next screen loads while this one is still alive).
function VOLT26.PreloadTransitionFrames(frame, paths, first)
	if type(paths) ~= "table" then return end
	for i = math.max(1, first or 1), #paths do
		frame[#frame+1] = Def.Sprite{
			Texture = paths[i],
			InitCommand = function(self) self:visible(false) end,
		}
	end
end
