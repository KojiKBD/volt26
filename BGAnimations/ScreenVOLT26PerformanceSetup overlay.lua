local selected = 1
local options = {
	{
		name="PERFORMANCE",
		description="Recommended for arcade cabinets and lower-end hardware. Uses lighter effects and faster transitions for smoother play.",
		enhanced=false,
	},
	{
		name="ENHANCED",
		description="Recommended for powerful hardware. Uses the complete visual effects, animations, and transition sequences.",
		enhanced=true,
	},
}

local input
input = function(event)
	if not event or event.type ~= "InputEventType_FirstPress" then return false end

	if event.GameButton == "MenuLeft" or event.GameButton == "MenuUp" then
		selected = selected == 1 and #options or selected - 1
		MESSAGEMAN:Broadcast("VOLT26FirstRunChoiceChanged", {Index=selected})
	elseif event.GameButton == "MenuRight" or event.GameButton == "MenuDown" then
		selected = selected == #options and 1 or selected + 1
		MESSAGEMAN:Broadcast("VOLT26FirstRunChoiceChanged", {Index=selected})
	elseif event.GameButton == "Start" then
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return false end
		screen:RemoveInputCallback(input)
		VOLT26.Performance.Choose(options[selected].enhanced)
		screen:SetNextScreenName("ScreenVOLT26Warmup")
		screen:StartTransitioningScreen("SM_GoToNextScreen")
	end

	return false
end

local af = Def.ActorFrame{
	Name="VOLT26FirstRunPerformanceSetup",
	InitCommand=function(self) self:Center() end,
	OnCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:AddInputCallback(input) end
		MESSAGEMAN:Broadcast("VOLT26FirstRunChoiceChanged", {Index=selected})
	end,
	OffCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:RemoveInputCallback(input) end
	end,
}

af[#af+1] = Def.Quad{
	Name="Background",
	InitCommand=function(self)
		self:zoomto(_screen.w, _screen.h):diffuse(color("#090909"))
	end,
}

af[#af+1] = LoadFont("Common Bold")..{
	Text="CHOOSE YOUR VOLT26 EXPERIENCE",
	InitCommand=function(self)
		self:y(-_screen.h * 0.30):zoom(0.72):maxwidth(_screen.w * 1.05)
			:diffuse(Color.White):shadowlength(2)
	end,
}

af[#af+1] = LoadFont("Common Normal")..{
	Text="You can change this later from Theme Options.",
	InitCommand=function(self)
		self:y(-_screen.h * 0.235):zoom(0.43):maxwidth(_screen.w * 1.45)
			:diffuse(color("#a8a8a8"))
	end,
}

for index, option in ipairs(options) do
	local x = index == 1 and -_screen.w * 0.22 or _screen.w * 0.22
	local card = Def.ActorFrame{
		Name="Choice" .. index,
		InitCommand=function(self) self:x(x) end,
		VOLT26FirstRunChoiceChangedMessageCommand=function(self, params)
			local focused = params.Index == index
			self:stoptweening():decelerate(0.12):zoom(focused and 1 or 0.96)
			local name = self:GetChild("Name")
			if name then
				name:stoptweening():decelerate(0.12)
					:diffuse(focused and color("#ff2020") or Color.White)
			end
		end,
	}

	card[#card+1] = LoadFont("Common Bold")..{
		Name="Name",
		Text=option.name,
		InitCommand=function(self)
			self:y(-_screen.h * 0.095):zoom(0.66)
				:diffuse(Color.White):shadowlength(1)
		end,
	}
	card[#card+1] = LoadFont("Common Normal")..{
		Text=option.description,
		InitCommand=function(self)
			self:y(_screen.h * 0.025):zoom(0.42)
				:wrapwidthpixels((_screen.w * 0.29) / 0.42)
				:diffuse(color("#c8c8c8"))
		end,
	}
	af[#af+1] = card
end

af[#af+1] = LoadFont("Common Bold")..{
	Text="LEFT / RIGHT TO CHOOSE     START TO CONFIRM",
	InitCommand=function(self)
		self:y(_screen.h * 0.32):zoom(0.40):maxwidth(_screen.w * 1.55)
			:diffuse(color("#ff3030"))
	end,
}

return af
