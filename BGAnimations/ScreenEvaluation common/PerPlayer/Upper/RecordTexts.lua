if SL.Global.GameMode == "Casual" then return end

local player = ...

local record = VOLT26.Results.ApplyNameEntryEligibility(player)

-- We always want to return this actor frame in case we need to "hijack" it for GrooveStats functionality.
local t = Def.ActorFrame{
	Name="RecordTexts",
	InitCommand=function(self) self:zoom(0.225) end,
	OnCommand=function(self)
		self:x( player == PLAYER_1 and -45 or 95 )
		self:y( 54 )
	end
}

t[#t+1] = LoadFont("Common Bold")..{
	Name="MachineRecord",
	InitCommand=function(self) self:xy(-110,-18):diffuse(PlayerColor(player)) end,
	OnCommand=function(self)
		if record.earnedMachine and record.machineIndex+1 > 0 then
			self:settext(ScreenString("MachineRecord"):format(record.machineIndex+1))
		end
	end,
}

t[#t+1] = LoadFont("Common Bold")..{
	Name="PersonalRecord",
	InitCommand=function(self) self:xy(-110,24):diffuse(PlayerColor(player)) end,
	OnCommand=function(self)
		if record.earnedPersonal and record.personalIndex+1 > 0 then
			self:settext(ScreenString("PersonalRecord"):format(record.personalIndex+1))
		end
	end,
}

return t
