local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)

local af = Def.ActorFrame{
	Name=pn.."Card",
	InitCommand=function(self) self:xy(18,args.Y):rotationz(player == PLAYER_1 and -1.2 or 1.0) end,
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end
		self:GetChild("Name"):settext(H.PlayerName(player))
		local path = H.Avatar(player)
		self:GetChild("Avatar"):visible(path ~= nil)
		self:GetChild("Fallback"):visible(path == nil)
		if path then self:GetChild("Avatar"):Load(path):scaletoclipped(31,31) end
	end,
}

af[#af+1] = H.Polygon({{-5,1},{242,-3},{248,31},{2,38}}, H.White)
af[#af+1] = H.Polygon({{0,4},{237,1},{241,28},{5,34}}, H.Black)
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(0,2):zoomto(42,31):skewx(-0.12):diffuse(accent) end}
af[#af+1] = Def.Sprite{
	Name="Avatar",
	InitCommand=function(self) self:xy(24,18):visible(false) end,
}
af[#af+1] = Def.ActorFrame{
	Name="Fallback",
	InitCommand=function(self) self:visible(false) end,
	Def.Quad{InitCommand=function(self) self:xy(24,18):zoomto(27,27):diffuse(H.Black):diffusealpha(0.45) end},
	Def.BitmapText{Font=H.Font, Text="?", InitCommand=function(self) self:xy(24,18):zoom(0.10):diffuse(H.White) end},
}
af[#af+1] = Def.BitmapText{
	Font=H.Font, Text=pn,
	InitCommand=function(self) self:xy(48,8):horizalign(left):zoom(0.05):diffuse(accent) end,
}
af[#af+1] = Def.BitmapText{
	Name="Name", Font=H.Font,
	InitCommand=function(self) self:xy(48,22):horizalign(left):zoom(0.082):diffuse(H.White):maxwidth(175/0.082) end,
}
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(52,31):zoomto(170,2):rotationz(player == PLAYER_1 and -1 or 1):diffuse(accent) end}

H.AddRefresh(af)
return af
