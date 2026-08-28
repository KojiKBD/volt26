local animationPath = "VOLT26/Song_Select_Animation/ssa_"
local firstFrame = 0
local lastFrame = 59
local frameDelay = 1 / 20
local currentFrame = firstFrame

local function framePath(frame)
	return THEME:GetPathG("", animationPath..string.format("%05d", frame)..".png")
end

local background = Def.Sprite{
	Name="SongSelectBackgroundAnimation",
	Texture=framePath(firstFrame),
	InitCommand=function(self)
		self:Center():setsize(_screen.w, _screen.h)
		currentFrame = firstFrame
	end,
	OnCommand=function(self)
		self:sleep(frameDelay):queuecommand("NextFrame")
	end,
	NextFrameCommand=function(self)
		currentFrame = currentFrame < lastFrame and currentFrame + 1 or firstFrame
		self:Load(framePath(currentFrame))
		self:sleep(frameDelay):queuecommand("NextFrame")
	end,
}

return Def.ActorFrame{
	background,
	Def.Quad{
		InitCommand=function(self) self:FullScreen():Center():diffuse(Color.Black) end,
		OnCommand=function(self) self:linear(0.25):diffusealpha(0):queuecommand("Hide") end,
		HideCommand=function(self) self:visible(false) end
	}
}
