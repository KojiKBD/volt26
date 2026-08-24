-- Collect transient EX judgments through the VOLT26 telemetry service.

if not VOLT26.Telemetry.IsEnabled() then return end

local player = ...

return Def.Actor{
	OnCommand=function(self)
		VOLT26.Telemetry.Ensure(player)
	end,
	JudgmentMessageCommand=function(self, params)
		local update = VOLT26.Telemetry.RecordExJudgment(player, params)
		if update then MESSAGEMAN:Broadcast("ExCountsChanged", update) end
	end,
}
