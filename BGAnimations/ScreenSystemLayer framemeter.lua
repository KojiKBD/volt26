-- Frame meter (Theme Options -> Frame Meter, off by default).
--
-- For finding what costs frame rate on a cabinet: a small line at the left
-- edge with the frames per second, the mean frame time and the worst frame
-- of the last half second, and the screen's name.  When a screen is left its
-- totals (mean and worst frame, frames counted) are written to the log as
-- "VOLT26 frame meter: ...", so a whole session can be read back from
-- Logs/log.txt.  It lives in ScreenSystemLayer, so it measures every screen
-- the same way; while the option is off it has no update function at all.

local WINDOW = 0.5
local X, Y = 6, 44

local meter
local screenName, total, frames, worst = nil, 0, 0, 0
local window, windowFrames, windowWorst = 0, 0, 0

local function enabled()
	local ok, value = pcall(function() return ThemePrefs.Get("FrameMeter") end)
	return ok and value == true
end

local function report()
	if screenName and frames > 0 then
		Trace(("VOLT26 frame meter: %s  mean %.2f ms  worst %.2f ms  %d frames  %.1f s"):format(
			screenName, total / frames * 1000, worst * 1000, frames, total))
	end
	total, frames, worst = 0, 0, 0
	window, windowFrames, windowWorst = 0, 0, 0
end

local function update(self, delta)
	delta = delta or 0
	if delta <= 0 then return end
	total, frames = total + delta, frames + 1
	if delta > worst then worst = delta end
	window, windowFrames = window + delta, windowFrames + 1
	if delta > windowWorst then windowWorst = delta end
	if window < WINDOW then return end
	self:GetChild("Text"):settext(("%3.0f FPS   mean %5.2f ms   worst %5.2f ms   %s"):format(
		windowFrames / window, window / windowFrames * 1000, windowWorst * 1000, screenName or "?"))
	local text = self:GetChild("Text")
	self:GetChild("Back"):zoomto(text:GetZoomedWidth() + 12, text:GetZoomedHeight() + 6)
	window, windowFrames, windowWorst = 0, 0, 0
end

return Def.ActorFrame{
	Name = "VOLT26FrameMeter",
	InitCommand = function(self)
		meter = self
		self:xy(X, Y):visible(false)
	end,
	ScreenChangedMessageCommand = function(self)
		report()
		local screen = SCREENMAN:GetTopScreen()
		screenName = screen and screen:GetName() or nil
		local on = enabled()
		self:visible(on)
		self:SetUpdateFunction(on and update or nil)
		if on then self:GetChild("Text"):settext(screenName or "") end
	end,
	Def.Quad{
		Name = "Back",
		InitCommand = function(self) self:align(0, 0):xy(-6, -3):diffuse(0, 0, 0, 0.7) end,
	},
	LoadFont("Common Normal")..{
		Name = "Text",
		InitCommand = function(self) self:align(0, 0):zoom(0.6):diffuse(1, 1, 1, 1):shadowlength(0) end,
	},
}
