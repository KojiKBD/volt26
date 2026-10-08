-- The stage evaluation has no header or footer; its only decoration is the
-- VOLT26 result panels, which reveal themselves after the evaluation sequence.
return Def.ActorFrame{
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common/VOLT26/ResultPanel.lua")),
}
