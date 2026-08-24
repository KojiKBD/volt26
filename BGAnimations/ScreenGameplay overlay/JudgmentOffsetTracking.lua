-- Collect chronological judgment offsets through the VOLT26 telemetry service.

if not VOLT26.Telemetry.IsEnabled() then return end

local player = ...
local require_step_on_hold_heads = THEME:GetMetric("Player", "RequireStepOnHoldHeads")

return Def.Actor{
	JudgmentMessageCommand=function(self, params)
		VOLT26.Telemetry.RecordOffset(player, params, require_step_on_hold_heads)
	end,
}
