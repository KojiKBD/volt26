local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)

local af = Def.ActorFrame{
	Name=pn.."Name",
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end
		local twoPlayers = #GAMESTATE:GetHumanPlayers() > 1
		local width = twoPlayers and 106 or 218
		local x = twoPlayers and (player == PLAYER_1 and 624 or 736) or 624
		self:xy(x,445)
		self:GetChild("Background"):zoomto(width,25)
		self:GetChild("Accent"):zoomto(width,2)
		self:GetChild("Name"):settext(H.PlayerName(player)):maxwidth((width-12)/H.BoldZoom(0.052))
	end,
}

af[#af+1] = Def.Quad{
	Name="Background",
	InitCommand=function(self) self:align(0,0):diffuse(H.Surface):diffusealpha(H.SurfaceAlpha) end,
}
af[#af+1] = Def.Quad{
	Name="Accent",
	InitCommand=function(self) self:align(0,0):diffuse(H.Accent(player)) end,
}
af[#af+1] = Def.BitmapText{
	Name="Name", Font=H.FontBold,
	InitCommand=function(self) self:xy(8,14):horizalign(left):zoom(H.BoldZoom(0.052)):diffuse(H.Black) end,
}

H.AddRefresh(af)
return af
