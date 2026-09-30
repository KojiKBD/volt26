local firstFrame = 0
local lastFrame = 64
local frameDelay = 1 / 30

local function framePath(index)
	return THEME:GetPathG("", "VOLT26/evaluation/eval_" .. string.format("%05d", index) .. ".png")
end

local animation = Def.Sprite{
	Texture=framePath(firstFrame),
	InitCommand=function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	end,
	OnCommand=function(self)
		self:sleep(frameDelay):queuecommand("Frame" .. (firstFrame + 1))
	end,
}

for index = firstFrame + 1, lastFrame do
	animation["Frame" .. index .. "Command"] = function(self)
		self:Load(framePath(index))
		self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		if index < lastFrame then
			self:sleep(frameDelay):queuecommand("Frame" .. (index + 1))
		end
	end
end

return Def.ActorFrame{
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/evaluation/bg_ss.png"),
		InitCommand=function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse({0.4, 0.4, 0.4, 1})
		end,
	},
	animation,
}
