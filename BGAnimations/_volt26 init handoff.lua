-- Reveals the fully-created title menu with the same visual language used
-- when entering Song Select. The startup handoff is intentionally text-free.
local enabled = _G.Volt26InitHandoff == true

local function Finish(self)
	_G.Volt26InitHandoff = nil
	self:visible(false)
end

if VOLT26.Performance.IsEnabled() then
	local revealTime = 0.22
	local af = Def.ActorFrame{
		Name="VOLT26_PerformanceHomeReceiver",
		InitCommand=function(self) self:draworder(1000):visible(enabled) end,
		StartTransitioningCommand=function(self)
			if not enabled then return end
			self:sleep(revealTime):queuecommand("FinishHandoff")
		end,
		FinishHandoffCommand=Finish,
	}

	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:Center():zoomto(_screen.w, _screen.h):diffuse(Color.Black)
		end,
		StartTransitioningCommand=function(self)
			if enabled then self:linear(revealTime):diffusealpha(0) end
		end,
	}

	for index, y in ipairs({-_screen.h * 0.19, _screen.h * 0.19}) do
		local lineY = y
		local direction = index == 1 and -1 or 1
		af[#af+1] = Def.Quad{
			InitCommand=function(self)
				self:xy(_screen.cx, _screen.cy + lineY):zoomto(_screen.w, 8)
					:diffuse(color("#FF0000"))
			end,
			StartTransitioningCommand=function(self)
				if enabled then
					self:accelerate(revealTime):addx(direction * _screen.w)
				end
			end,
		}
	end

	return af
end

-- Enhanced mode mirrors the animated receiver used by Song Select. Start on
-- the fully-covered switch frame, then play only the reveal half over Home.
local frameTime = 1/30
local transitions = {
	{folder="VOLT26/TransMenu", prefix="TransMenu", frames=16, switchScreen=8},
	{folder="VOLT26/TransMenu2", prefix="TransMenu2", frames=28, switchScreen=17},
}
local selected = transitions[math.random(#transitions)]
local paths = {}
for frame = selected.switchScreen, selected.frames - 1 do
	paths[#paths+1] = THEME:GetPathG("", string.format(
		"%s/%s_%05d.png", selected.folder, selected.prefix, frame))
end
if PREFETCHMAN then
	for _, path in ipairs(paths) do PREFETCHMAN:Add(path) end
end

return Def.Sprite{
	Name="VOLT26_EnhancedHomeReceiver",
	InitCommand=function(self)
		self:Center():scaletoclipped(_screen.w, _screen.h)
			:draworder(1000):visible(enabled)
		if enabled and paths[1] then self:Load(paths[1]) end
		self.HandoffFrame = 1
	end,
	StartTransitioningCommand=function(self)
		if not enabled then return end
		self:sleep(frameTime):queuecommand("PlayNextHandoffFrame")
	end,
	PlayNextHandoffFrameCommand=function(self)
		self.HandoffFrame = self.HandoffFrame + 1
		local path = paths[self.HandoffFrame]
		if path then
			self:Load(path):sleep(frameTime):queuecommand("PlayNextHandoffFrame")
		else
			self:queuecommand("FinishHandoff")
		end
	end,
	FinishHandoffCommand=Finish,
}
