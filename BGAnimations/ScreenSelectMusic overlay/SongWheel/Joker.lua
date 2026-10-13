-- Joker over the song select while the wheel rests on a row that is not a song
-- (the PACK SELECTION row or a pack's header), as in the owner's mockup.
--
-- The right side steps aside while he is there: the jacket's frame, the pack
-- tile in it, and everything in the info column (jacket, length, difficulty
-- column, notes radar, player cards, names footer).  The wheel, the focused
-- row and the scenery stay as they are.  He slides in from the right; moving
-- back onto a song he slides out and the right side returns.  Going back to
-- the pack step (LeaveCommand, from default.lua) he slides out as the rest of
-- the screen leaves.
--
-- The picture is the owner's joker.png (Graphics/VOLT26/SongSelect/joker.png,
-- stored at 1024 px high, 0.832 of the original), placed where the mockup
-- has it: the original at 0.99 with its top-left corner at (237, -132).
local p = ...
local K, S = p.K, p.S

local PICTURE_SCALE = 1024 / 1231   -- the stored picture against the original
local X, Y, ZOOM = 237, -132, 0.99 / PICTURE_SCALE
local SLIDE = 520

local function rightSide(layout)
	local details = layout:GetChild("Details")
	return {
		layout:GetChild("Header"),
		layout:GetChild("Info") and layout:GetChild("Info"):GetChild("Right"),
		details and details:GetChild("SceneFront"),
	}
end

local function showRight(layout, shown)
	for _, actor in ipairs(rightSide(layout)) do
		if actor then actor:visible(shown) end
	end
end

local function onPackRow()
	if S.IsCourseMode() then return false end
	return S.Item() == nil
end

return Def.ActorFrame{
	Name="Joker",
	InitCommand=function(self) self.shown = false end,
	RefreshCommand=function(self)
		local wanted = onPackRow()
		if wanted == self.shown or self.leaving then return end
		self.shown = wanted
		local joker = self:GetChild("Picture")
		local layout = self:GetParent()
		if wanted then
			showRight(layout, false)
			joker:finishtweening():visible(true):x(X + SLIDE):diffusealpha(0):rotationz(4)
				:decelerate(0.18):x(X - 12):diffusealpha(1):rotationz(-0.5)
				:decelerate(0.08):x(X):rotationz(0)
		else
			joker:finishtweening():accelerate(0.12):x(X + SLIDE):diffusealpha(0)
				:queuecommand("Gone")
		end
	end,
	-- Back to the pack step: he leaves with the screen; the pack tile shows
	-- again, since the pack step's jacket grows out of it.
	LeaveCommand=function(self)
		self.leaving = true
		if not self.shown then return end
		local layout = self:GetParent()
		local header = layout:GetChild("Header")
		if header then header:visible(true) end
		self:GetChild("Picture"):finishtweening():accelerate(0.15):x(X + SLIDE):rotationz(4):diffusealpha(0)
	end,

	Def.Sprite{
		Name="Picture",
		Texture=THEME:GetPathG("", "VOLT26/SongSelect/joker.png"),
		InitCommand=function(self) self:align(0, 0):xy(X, Y):zoom(ZOOM):visible(false) end,
		GoneCommand=function(self)
			self:visible(false)
			local frame = self:GetParent()
			if not frame.shown then showRight(frame:GetParent(), true) end
		end,
	},
}
