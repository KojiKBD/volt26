local af = Def.ActorFrame{
	-- the content
	LoadActor( THEME:GetPathB("ScreenEvaluation","common") )
}

if VOLT26.Evaluation.AllPlayersFailed() then
	af[#af+1] = LoadActor(THEME:GetPathB("ScreenEvaluation", "common/Shared/VOLT26FailureSpinner.lua"))
end

return af
