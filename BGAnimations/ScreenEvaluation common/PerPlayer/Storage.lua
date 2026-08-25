local player = ...
return Def.Actor{
	OnCommand=function(self)
		VOLT26.Evaluation.StorePlayerSnapshot(player)
	end
}
