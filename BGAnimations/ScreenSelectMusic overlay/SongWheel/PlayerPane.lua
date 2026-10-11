-- One player's pane, after Simply Love's pane display: the chosen chart, its
-- note counts, and the best personal and machine scores on it.  P1 stands on
-- the left half of the details column and P2 on the right, alone or together,
-- so a player always finds their pane on their own side.
local p = ...
local K, S, player = p.K, p.S, p.Player

local paneTop = 815
local height = 180
local width = 450
local x = player == PLAYER_1 and 40 or 510
local accent = K.PlayerColor(player)
local headerHeight = 40
local statWidth = 100

local stats = {
	{ "Steps", "RadarCategory_TapsAndHolds" },
	{ "Jumps", "RadarCategory_Jumps" },
	{ "Holds", "RadarCategory_Holds" },
	{ "Mines", "RadarCategory_Mines" },
	{ "Hands", "RadarCategory_Hands" },
	{ "Rolls", "RadarCategory_Rolls" },
}

local af = Def.ActorFrame{
	Name="Pane" .. ToEnumShortString(player),
	InitCommand=function(self) self:xy(x, paneTop):visible(GAMESTATE:IsHumanPlayer(player)) end,
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end

		local item = S.Item()
		local chart = item and S.Chart(player) or nil
		K.SetLabel(self:GetChild("Name"), S.PlayerName(player):upper(), 16, 250)
		local chartText = ""
		if chart then
			chartText = string.format("%s  %d", K.DifficultyName(chart:GetDifficulty()),
				math.floor((tonumber(chart:GetMeter()) or 0) + 0.5))
		end
		K.SetLabel(self:GetChild("Chart"), chartText, 13, 160)
		self:GetChild("Chart"):diffuse(chart and K.DifficultyColor(chart:GetDifficulty()) or K.Mute)

		for i, stat in ipairs(stats) do
			local value = S.Radar(chart, player, stat[2])
			K.SetDisplay(self:GetChild("Stat" .. i), value and tostring(value) or K.Dash, 26, statWidth - 12)
		end
		K.SetDisplay(self:GetChild("Personal"), S.PersonalBest(player, item, chart), 28, 112)
		K.SetDisplay(self:GetChild("Machine"), S.MachineBest(item, chart), 28, 112)
	end,
}

af[#af+1] = K.Rule{ Name="Ground", Width=width, Height=height, Tint=K.Panel, Alpha=0.9 }
af[#af+1] = K.Rule{ Name="HeaderBand", Width=width, Height=headerHeight, Tint=K.Panel2 }
af[#af+1] = K.Rule{ Name="Accent", Width=6, Height=height, Tint=accent }
af[#af+1] = K.Text{ Name="Name", Px=16, Tint=K.Ink, X=20, Y=headerHeight/2 }
af[#af+1] = K.Text{ Name="Chart", Px=13, Tint=K.Mute, Align=right, X=width - 14, Y=headerHeight/2 }

for i, stat in ipairs(stats) do
	local column = (i - 1) % 3
	local line = math.floor((i - 1) / 3)
	local sx = 20 + column * statWidth
	local sy = headerHeight + 26 + line * 66
	af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=sx, Y=sy, Text=K.String(stat[1]) }
	af[#af+1] = K.Text{ Name="Stat" .. i, Role="Display", Px=26, Tint=K.Ink, X=sx, Y=sy + 26 }
end

local scoreX = 20 + 3 * statWidth + 6
af[#af+1] = K.Rule{ X=scoreX - 12, Y=headerHeight + 12, Width=1, Height=height - headerHeight - 24 }
af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=scoreX, Y=headerHeight + 26, Text=K.String("PersonalBest") }
af[#af+1] = K.Text{ Name="Personal", Role="Display", Px=28, Tint=K.Ink, X=scoreX, Y=headerHeight + 52 }
af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=scoreX, Y=headerHeight + 92, Text=K.String("MachineBest") }
af[#af+1] = K.Text{ Name="Machine", Role="Display", Px=28, Tint=K.Mute, X=scoreX, Y=headerHeight + 118 }

return af
