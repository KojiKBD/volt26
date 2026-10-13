local minimumDisplaySeconds = 0.45
-- The cutout lettering warm-up (VOLT26.Cutout.Cache.WarmStartup: credit line,
-- profile names, pack names) is waited for at most this long; whatever is
-- left keeps rendering in the background, one pass a frame.
local cutoutMaxSeconds = 3

local af = Def.ActorFrame{
	Name="VOLT26_PreIntroWarmup",
	InitCommand=function(self)
		self:Center()
		self.WarmupComplete = false
		self.MinimumComplete = false
		self.CutoutComplete = false
	end,
	OnCommand=function(self)
		self:sleep(minimumDisplaySeconds):queuecommand("MinimumDisplayComplete")
		local queued = 0
		if VOLT26.Cutout.Cache and VOLT26.Cutout.Cache.WarmStartup then
			queued = VOLT26.Cutout.Cache.WarmStartup()
		end
		if queued == 0 then
			self.CutoutComplete = true
		else
			-- A separate timer, so the minimum-display sleep above is not delayed.
			self:GetChild("CutoutTimer"):sleep(cutoutMaxSeconds):queuecommand("Expire")
		end
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
	VOLT26CutoutWarmupCompleteMessageCommand=function(self)
		self.CutoutComplete = true
		self:queuecommand("ContinueWhenReady")
	end,
	CutoutTimeoutCommand=function(self)
		self.CutoutComplete = true
		self:queuecommand("ContinueWhenReady")
	end,
	ContinueWhenReadyCommand=function(self)
		if not self.WarmupComplete or not self.MinimumComplete
		or not self.CutoutComplete or self.TransitionStarted then return end
		self.TransitionStarted = true
		local screen = SCREENMAN:GetTopScreen()
		screen:SetNextScreenName("ScreenInit")
		screen:StartTransitioningScreen("SM_GoToNextScreen")
	end,
}

af[#af+1] = Def.Actor{
	Name="CutoutTimer",
	ExpireCommand=function(self) self:GetParent():playcommand("CutoutTimeout") end,
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

-- A thin second bar under the textures' one: the cutout lettering's progress.
af[#af+1] = Def.Quad{
	Name="CutoutProgress",
	InitCommand=function(self)
		self:xy(-_screen.w * 0.17, -_screen.h/2 + 40):halign(0)
			:zoomto(0, 1):diffuse(color("#FF0000")):diffusealpha(0.6)
	end,
	VOLT26CutoutWarmupProgressMessageCommand=function(self, params)
		if not params.Total or params.Total < 1 then return end
		self:zoomtowidth(_screen.w * 0.34 * params.Done / params.Total)
	end,
}

return af
