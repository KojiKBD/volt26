return {
	Question=THEME:GetString("ScreenSelectMusic", "SongSearchInstructions"),
	InitialAnswer="",
	MaxInputLength=30,
	OnOK=function(input)
		local result = VOLT26.SongBrowsing.Search(input)
		if result then MESSAGEMAN:Broadcast("DisplaySearchResults", result) end
	end,
}
