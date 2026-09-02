-- The second half of VOLT26's title-menu transition. This actor is loaded
-- through "Screen in.lua", so it is recreated on whichever screen the title
-- menu selected (gameplay flow, edit mode, or options).
local transitionData = VOLT26.State.Global.Volt26TransData

if transitionData and transitionData.lightweight then
	local revealTime = tonumber(transitionData.reveal_time) or 0.22
	local af = Def.ActorFrame{
		Name="VOLT26_PerformanceTransitionReceiver",
		InitCommand=function(self) self:draworder(1000) end,
		StartTransitioningCommand=function(self)
			self:sleep(revealTime):queuecommand("FinishVolt26Transition")
		end,
		FinishVolt26TransitionCommand=function(self)
			if VOLT26.State.Global.Volt26TransData == transitionData then
				VOLT26.State.Global.Volt26TransData = nil
			end
			self:visible(false)
		end,
	}

	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:Center():zoomto(_screen.w, _screen.h):diffuse(Color.Black)
		end,
		StartTransitioningCommand=function(self)
			self:linear(revealTime):diffusealpha(0)
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
				self:accelerate(revealTime):addx(direction * _screen.w)
			end,
		}
	end

	return af
end

return Def.Sprite{
	InitCommand=function(self)
		self:Center():scaletoclipped(_screen.w, _screen.h)
			:draworder(1000):diffusealpha(0)

		local data = SL.Global.Volt26TransData
		if data and data.paths and data.paths[data.next_frame] then
			self.Volt26Data = data
			self.Volt26Frame = data.next_frame
			-- Cover the destination immediately, before its first rendered
			-- frame, then continue the sequence when its in-transition starts.
			self:Load(data.paths[self.Volt26Frame]):diffusealpha(1)
		end
	end,

	StartTransitioningCommand=function(self)
		local data = self.Volt26Data
		if not data then return end

		if self.Volt26Frame < #data.paths then
			self:sleep(data.frame_time):queuecommand("PlayNextVolt26Frame")
		else
			self:sleep(data.frame_time):queuecommand("FinishVolt26Transition")
		end
	end,

	PlayNextVolt26FrameCommand=function(self)
		local data = self.Volt26Data
		if not data then return end

		self.Volt26Frame = self.Volt26Frame + 1
		self:Load(data.paths[self.Volt26Frame])

		if self.Volt26Frame < #data.paths then
			self:sleep(data.frame_time):queuecommand("PlayNextVolt26Frame")
		else
			self:sleep(data.frame_time):queuecommand("FinishVolt26Transition")
		end
	end,

	FinishVolt26TransitionCommand=function(self)
		self:diffusealpha(0)
		if SL.Global.Volt26TransData == self.Volt26Data then
			SL.Global.Volt26TransData = nil
		end
		self.Volt26Data = nil
	end
}
