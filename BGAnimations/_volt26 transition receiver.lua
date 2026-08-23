-- The second half of VOLT26's title-menu transition. This actor is loaded
-- through "Screen in.lua", so it is recreated on whichever screen the title
-- menu selected (gameplay flow, edit mode, or options).
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
