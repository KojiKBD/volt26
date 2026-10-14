return Def.Actor{
	OnCommand=function(self)
		VOLT26.Evaluation.StoreStageContext()
	end,
	-- The stage counts as played when the evaluation is left.  The header
	-- (Graphics/ScreenEvaluationStage header.lua) used to be the only place
	-- doing this, and the stage evaluation no longer shows one: the session
	-- summary, name entry and game over then found no stage at all.
	-- CompleteStage is idempotent, so both may call it.
	OffCommand=function(self)
		VOLT26.Evaluation.CompleteStage()
	end,
}
