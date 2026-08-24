if VOLT26.Gameplay.IsCasual() then return end

return Def.Actor{
	CodeMessageCommand=function(self, params)
		if params.Name == "Favorite1" or params.Name == "Favorite2" then
			VOLT26.Favorites.ToggleCurrent(params.PlayerNumber)
		end
	end,
}
