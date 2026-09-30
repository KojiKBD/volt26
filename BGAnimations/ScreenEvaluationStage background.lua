local firstFrame = 0
local lastFrame = 64
local frameDelay = 1 / 30

local function framePath(index)
	return THEME:GetPathG("", "VOLT26/evaluation/eval_" .. string.format("%05d", index) .. ".png")
end

local animation = Def.Sprite{
	Name="Animation",
	Texture=framePath(firstFrame),
	InitCommand=function(self)
		self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
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
	OnCommand=function(self)
		self:GetChild("SequenceAudio"):play()
		self:GetChild("Animation"):sleep(frameDelay):queuecommand("Frame" .. (firstFrame + 1))
	end,
	OffCommand=function(self)
		self:GetChild("SequenceAudio"):stop()
	end,
	Def.Sprite{
		Texture=THEME:GetPathG("", "VOLT26/evaluation/bg_ss.png"),
		InitCommand=function(self)
			self:Center():zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse({0.4, 0.4, 0.4, 1})
		end,
	},
	animation,
	Def.Sound{
		Name="SequenceAudio",
		File=THEME:GetPathS("", "VOLT26/evaluation/result_sequence.ogg"),
	},
}
