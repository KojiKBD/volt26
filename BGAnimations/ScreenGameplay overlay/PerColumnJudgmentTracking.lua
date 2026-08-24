-- Collect per-column judgments through the VOLT26 telemetry service.

if not VOLT26.Telemetry.IsEnabled() then return end

local player = ...

return Def.Actor{
	JudgmentMessageCommand=function(self, params)
		VOLT26.Telemetry.RecordColumnJudgment(player, params)
	end,
}
