-- The footer: the joined players' names in the profiles' cutout lettering,
-- side by side at the bottom right of the screen (under the SELECT side),
-- right-justified as a group, P1 before P2, each underlined in its colour.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))

local RIGHT, Y = 1890, 1034
local GAP = 34
local UNDERLINE = { Y = 30, H = 5 }

local ids = { [PLAYER_1] = "FooterP1", [PLAYER_2] = "FooterP2" }

return Def.ActorFrame{
	Name="Footer",
	-- Arriving: the names slide in from the right edge.
	OnCommand=function(self)
		self:stoptweening():x(520):sleep(0.4):decelerate(0.22):x(-10):decelerate(0.08):x(0)
	end,
	RefreshCommand=function(self)
		local players = GAMESTATE:GetHumanPlayers()
		local right = RIGHT
		-- From the right edge leftwards: the last player first.
		for i = 2, 1, -1 do
			local player = PlayerNumber[i]
			local name = self:GetChild("Name" .. i)
			local line = self:GetChild("Line" .. i)
			local joined = GAMESTATE:IsHumanPlayer(player)
			name:visible(joined)
			line:visible(joined)
			if joined then
				local text = S.PlayerName(player)
				P.SetCutout(name, text)
				local width = P.CutoutWidth(ids[player], text, K.Scale)
				name:x(right)
				line:x(right):zoomto(width, UNDERLINE.H)
				right = right - width - GAP
			end
		end
	end,

	P.CutoutSlot{ Name="Name1", Id="FooterP1", X=RIGHT, Y=Y, Scale=K.Scale },
	P.CutoutSlot{ Name="Name2", Id="FooterP2", X=RIGHT, Y=Y, Scale=K.Scale },
	Def.Quad{ Name="Line1", InitCommand=function(self)
		self:align(1, 0):y(Y + UNDERLINE.Y):diffuse(P.Flag) end },
	Def.Quad{ Name="Line2", InitCommand=function(self)
		self:align(1, 0):y(Y + UNDERLINE.Y):diffuse(P.Blue) end },
}
