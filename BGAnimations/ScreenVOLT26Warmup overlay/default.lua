local minimumDisplaySeconds = 0.45

local af = Def.ActorFrame{
	Name="VOLT26_PreIntroWarmup",
	InitCommand=function(self)
		self:Center()
		self.WarmupComplete = false
		self.MinimumComplete = false
	end,
	OnCommand=function(self)
		self:sleep(minimumDisplaySeconds):queuecommand("MinimumDisplayComplete")
	end,
	MinimumDisplayCompleteCommand=function(self)
		self.MinimumComplete = true
		self:queuecommand("ContinueWhenReady")
	end,
	VOLT26WarmupCompleteMessageCommand=function(self, params)
		if params.Group ~= "Core" then return end
		self.WarmupComplete = true
		self:queuecommand("ContinueWhenReady")
	end,
	ContinueWhenReadyCommand=function(self)
		if not self.WarmupComplete or not self.MinimumComplete
		or self.TransitionStarted then return end
		self.TransitionStarted = true
		local screen = SCREENMAN:GetTopScreen()
		screen:SetNextScreenName("ScreenInit")
		screen:StartTransitioningScreen("SM_GoToNextScreen")
	end,
}

af[#af+1] = Def.Quad{
	Name="Background",
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(Color.Black)
	end,
}

af[#af+1] = LoadFont("Common Bold")..{
	Text="VOLT26",
	InitCommand=function(self)
		self:y(-36):zoom(0.82):diffuse(Color.White):shadowlength(2)
	end,
}

af[#af+1] = VOLT26.Warmup.CreateActor("Core", {
	Interval=0.08,
	ShowProgress=true,
})

return af

