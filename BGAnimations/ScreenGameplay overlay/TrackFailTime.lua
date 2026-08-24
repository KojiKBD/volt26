-- Record the player's failure position through the VOLT26 failure service.

local player = ...

return Def.Actor{
	HealthStateChangedMessageCommand=function(self, params)
		if params.PlayerNumber == player and params.HealthState == "HealthState_Dead" then
			VOLT26.Failure.Record(player)
		end
	end,
}
