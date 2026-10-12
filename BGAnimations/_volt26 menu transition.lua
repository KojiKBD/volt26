-- VOLT26's menu transition, shared by every screen that leaves with it (the
-- title menu, and the play-mode choice on its way to music selection).
--
-- Enhanced mode plays one of the TransMenu frame sequences, picked at random,
-- up to its fully covered frame; the rest of the sequence is played over the
-- next screen by "_volt26 transition receiver.lua" (through "Screen in.lua"),
-- which reads VOLT26.State.Global.Volt26TransData.  A screen in between that
-- only holds the cover (ScreenProfileLoad) shows that covered frame and leaves
-- the data for the screen after it.
--
-- Performance mode draws a dark shade and one red diagonal wipe instead, and
-- hands nothing over.
--
-- Load it into a screen's "out" transition; the actor's own sleep sets how
-- long the transition lasts.
local performance = VOLT26.Performance.IsEnabled()

-- Let the press animation land before the covering frames begin.
local KNIFE_DELAY = 0.35

if performance then
	local WIPE_TIME = 0.30
	local WIPE_PAUSE = 0.08
	local duration = KNIFE_DELAY + WIPE_TIME + WIPE_PAUSE + WIPE_TIME

	return Def.ActorFrame{
		Name="VOLT26_PerformanceTransition",
		InitCommand=function(self) self:draworder(1000) end,
		OffCommand=function(self)
			VOLT26.State.Global.Volt26TransData = nil
			self:sleep(duration)
		end,
		Def.Quad{
			Name="TransitionShade",
			InitCommand=function(self)
				self:Center():zoomto(_screen.w, _screen.h)
					:diffuse(color("#090909")):diffusealpha(0)
			end,
			OffCommand=function(self)
				self:sleep(KNIFE_DELAY):linear(WIPE_TIME):diffusealpha(0.92)
			end,
		},
		Def.Quad{
			Name="AccentWipe",
			InitCommand=function(self)
				self:xy(-180, _screen.cy):rotationz(-8)
					:diffuse(color("#ff0000")):zoomto(130, _screen.h*1.35)
			end,
			OffCommand=function(self)
				self:sleep(KNIFE_DELAY):decelerate(WIPE_TIME):x(_screen.cx)
					:sleep(WIPE_PAUSE):accelerate(WIPE_TIME):x(_screen.w+180)
			end,
		},
	}
end

local FRAME_TIME = 1/30
local SEQUENCES = {
	-- switch_screen is a fully covered frame.  Everything after it is
	-- rendered by "Screen in.lua" over the newly loaded screen.
	{ folder="VOLT26/TransMenu",  prefix="TransMenu",  frames=16, switch_screen=8  },
	{ folder="VOLT26/TransMenu2", prefix="TransMenu2", frames=28, switch_screen=17 },
}

local selected = SEQUENCES[math.random(#SEQUENCES)]
local paths = {}
for i = 0, selected.frames - 1 do
	paths[#paths+1] = THEME:GetPathG("",
		string.format("%s/%s_%05d.png", selected.folder, selected.prefix, i))
end

if PREFETCHMAN then
	for _, path in ipairs(paths) do PREFETCHMAN:Add(path) end
end

local duration = KNIFE_DELAY + selected.switch_screen * FRAME_TIME

local transition = Def.Sprite{
	Name="VOLT26_MenuTransition",
	InitCommand=function(self)
		self:Center():scaletoclipped(_screen.w, _screen.h)
			:draworder(1000):diffusealpha(0)
	end,
	-- Store the sequence when the screen actually leaves.  The table survives
	-- the screen swap; the generic Screen "in" actor consumes it.
	OffCommand=function(self)
		VOLT26.State.Global.Volt26TransData = {
			paths=paths,
			next_frame=selected.switch_screen + 1,
			frame_time=FRAME_TIME,
		}
		self:sleep(KNIFE_DELAY):queuecommand("VoltFrame1")
	end,
	VoltFrame1Command=function(self)
		self:Load(paths[1]):diffusealpha(1)
			:sleep(FRAME_TIME):queuecommand("VoltFrame2")
	end,
}

for i = 2, selected.switch_screen do
	transition["VoltFrame" .. i .. "Command"] = function(self)
		self:Load(paths[i]):sleep(FRAME_TIME)
		if i < selected.switch_screen then
			self:queuecommand("VoltFrame" .. (i + 1))
		end
	end
end

-- queuecommand chains do not count as tween time, so the frame holding the
-- sprite sleeps for the whole covering half.
return Def.ActorFrame{
	OffCommand=function(self) self:sleep(duration) end,
	transition,
}
