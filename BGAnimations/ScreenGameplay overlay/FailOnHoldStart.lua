-- Reconcile give-up, autoplay, and premature gameplay exits.

local guard = VOLT26.Failure.NewExitGuard()

return Def.ActorFrame{
	JudgmentMessageCommand=function(self, params)
		VOLT26.Failure.ObserveJudgment(guard, params)
	end,
	OffCommand=function(self)
		VOLT26.Failure.ReconcileExit(guard)
	end,
}
