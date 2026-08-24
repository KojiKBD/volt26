local firstFrame = 0
local lastFrame = 38
local frameDelay = 1 / 24

local function framePath(index)
	return THEME:GetPathG("", "VOLT26/Eval/tyt_res/tyt_"..string.format("%05d", index)..".png")
end

return Def.ActorFrame{
	InitCommand=function(self)
		self._frame = firstFrame
		self._elapsed = 0
	end,
	OnCommand=function(self)
		-- Keep animation state on the parent. Reloading a Sprite texture may
		-- reset Sprite-local update state, while this ActorFrame remains stable.
		self:SetUpdateFunction(function(frame, delta)
			frame._elapsed = frame._elapsed + (tonumber(delta) or 0)
			if frame._elapsed < frameDelay then return end
			local steps = math.floor(frame._elapsed / frameDelay)
			frame._elapsed = frame._elapsed - steps * frameDelay
			frame._frame = firstFrame + ((frame._frame - firstFrame + steps) % (lastFrame - firstFrame + 1))
			frame:GetChild("Spinner"):Load(framePath(frame._frame)):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		end)
	end,

	Def.Sprite{
		Name="Spinner",
		Texture=framePath(firstFrame),
		InitCommand=function(self) self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT) end,
	},
}
