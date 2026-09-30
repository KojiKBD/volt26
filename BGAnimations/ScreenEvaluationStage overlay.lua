-- Keep evaluation state and input handling active while hiding its temporary UI.
return Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common")),
}
