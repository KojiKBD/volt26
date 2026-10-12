-- One card per joined player under the jacket, in the song rows' own
-- language: a black band with the player's name (the profiles' cutout
-- lettering) and the chosen chart, a white band with the player's best on it,
-- then two see-through strips, the chart's counts and its density graph.
-- It stands in for the mockup's solid info panel (Panel.lua), which weighed
-- too much on the right of the screen; the notes radar has moved out of it
-- onto the red (Radar.lua, placed by default.lua).
--
-- Cards follow the joined players in order and step down and to the left
-- like the song rows, so a lone player takes the first card.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local bands = P.Art.Pieces.RowBands

local CARDS = { { X = 1252, Y = 398 }, { X = 1210, Y = 690 } }
local W = 640
local BANDS_ZOOMX = W / bands.W
local DARK = 0.8                          -- the strips' black
local MUTE = color("#9a9aa2")
local INK_MUTE = color("#55555c")         -- labels on the white band

-- The counters strip, and its columns.
local STATS_TOP, STATS_H = bands.H + 8, 60
local GRAPH_TOP, GRAPH_H = STATS_TOP + STATS_H + 6, 46
local COUNTERS = {
	{ "NOTES", "RadarCategory_TapsAndHolds" },
	{ "JUMPS", "RadarCategory_Jumps" },
	{ "HOLDS", "RadarCategory_Holds" },
	{ "MINES", "RadarCategory_Mines" },
	{ "ROLLS", "RadarCategory_Rolls" },
	{ "HANDS", "RadarCategory_Hands" },
	{ "PEAK NPS" },
	{ "STREAM" },
}
local COLUMN_W = (W - 28) / #COUNTERS

local function percent(value)
	if not value then return K.Dash end
	return ("%.2f%%"):format(value)
end

local function fill(card, player, item)
	local chart = S.Chart(player)
	local data = S.ChartData(player)

	local name = S.PlayerName(player)
	if card.name ~= name then
		card.name = name
		P.SetCutout(card:GetChild("Name"), name)
	end

	local chartText = ""
	if chart then
		chartText = ("%s %d"):format(K.DifficultyName(chart:GetDifficulty()),
			math.floor((tonumber(chart:GetMeter()) or 0) + 0.5))
	end
	card:GetChild("Chart"):settext(chartText)
		:diffuse(chart and K.DifficultyColor(chart:GetDifficulty()) or MUTE)

	-- The player's best on this chart.
	local best = S.Best(player, item, chart)
	card:GetChild("Itg"):settext(percent(best and best.PercentDP and best.PercentDP * 100))
	card:GetChild("Ex"):settext(percent(best and best.ExPercent))
	local letter, stars = P.Grade(best and best.Grade)
	local grade = card:GetChild("Grade")
	grade:visible(letter ~= nil)
	if letter and grade.loaded ~= letter then
		grade.loaded = letter
		grade:Load(letter)
		grade:zoom(40 / P.GradeAssetSize)
	end
	for i = 1, 5 do card:GetChild("Star" .. i):visible(i <= stars) end
	card:GetChild("GradeLabel"):visible(letter ~= nil or stars > 0)

	local credit = S.StepArtist(chart)
	card:GetChild("Credit"):settext(credit ~= "" and ("STEPS BY " .. credit) or "")
	card:GetChild("Rate"):settext(("RATE %.2fx"):format(VOLT26.MusicSelection.GetMusicRate()))

	-- The counts.
	for i, counter in ipairs(COUNTERS) do
		local value
		if counter[2] then
			local v = S.Radar(chart, player, counter[2])
			value = v and tostring(v) or K.Dash
		elseif counter[1] == "PEAK NPS" then
			value = chart and ("%.1f"):format(data.peak or 0) or K.Dash
		else
			value = chart and ("%d"):format(data.streamMeasures) or K.Dash
		end
		card:GetChild("Value" .. i):settext(value)
	end
	card:GetChild("Label" .. #COUNTERS):settext(chart
		and ("STREAM %d%%"):format(math.floor(data.stream * 100 + 0.5)) or "STREAM")

	P.SetVertices(card:GetChild("Density"),
		P.DensityVertices(chart and data or nil, W - 20, GRAPH_H - 6, P.PlayerColor(player)))

	-- A new chart: its name slides in and its graph rises from the floor.
	if card.chart ~= chart then
		card.chart = chart
		card:GetChild("Chart"):stoptweening():x(W - 26 + 40):diffusealpha(0)
			:decelerate(0.14):x(W - 26):diffusealpha(1)
		card:GetChild("Density"):stoptweening():zoomy(0):decelerate(0.26):zoomy(1)
	end
end

local af = Def.ActorFrame{
	Name="Cards",
	RefreshCommand=function(self)
		local item = S.Item()
		local players = GAMESTATE:GetHumanPlayers()
		for c = 1, #CARDS do
			local card = self:GetChild("Card" .. c)
			local player = players[c]
			card:visible(player ~= nil)
			if player then fill(card, player, item) end
		end
	end,
}

for c, at in ipairs(CARDS) do
	local card = Def.ActorFrame{
		Name = "Card" .. c,
		InitCommand = function(self) self:xy(at.X, at.Y) end,
		-- Arriving: the cards slide in from the right edge, one after the other.
		OnCommand = function(self)
			self:stoptweening():x(at.X + 760):sleep(0.14 + (c - 1) * 0.06)
				:decelerate(0.17):x(at.X - 14):decelerate(0.06):x(at.X)
		end,
		-- The bands of a song row, stretched to the card's width.
		Def.Sprite{ Texture=P.PiecePath("RowBands"),
			InitCommand=function(self) self:xy(W / 2, bands.H / 2):zoomx(BANDS_ZOOMX) end },
		P.CutoutSlot{ Name="Name", Id="Card" .. c .. "Name", X=16, Y=32, Scale=K.Scale },
		P.Text{ Name="Chart", Cap=24, Condense=0.75, Align=1, X=W - 26, Baseline=46, Width=260 },

		-- On the white band: best ITG, best EX, grade; credit and rate.
		P.Text{ Name="ItgLabel", Cap=10, Condense=0.85, X=14, Baseline=76, Tint=INK_MUTE, Text="BEST - ITG" },
		P.Text{ Name="Itg", Cap=26, Condense=0.75, X=14, Baseline=106, Tint=P.Black, Width=140 },
		P.Text{ Name="ExLabel", Cap=10, Condense=0.85, X=164, Baseline=76, Tint=INK_MUTE, Text="EX" },
		P.Text{ Name="Ex", Cap=26, Condense=0.75, X=164, Baseline=106, Tint=P.Black, Width=140 },
		P.Text{ Name="GradeLabel", Cap=10, Condense=0.85, X=310, Baseline=76, Tint=INK_MUTE, Text="GRADE" },
		Def.Sprite{ Name="Grade", InitCommand=function(self) self:xy(330, 96):visible(false) end },
		P.Text{ Name="Credit", Cap=11, Condense=0.85, Align=1, X=W - 30, Baseline=80, Tint=INK_MUTE, Width=210 },
		P.Text{ Name="Rate", Cap=11, Condense=0.85, Align=1, X=W - 34, Baseline=102, Tint=INK_MUTE },

		-- The counts.
		Def.Quad{ InitCommand=function(self)
			self:align(0, 0):xy(0, STATS_TOP):zoomto(W, STATS_H):diffuse(0, 0, 0, DARK) end },
		-- The density graph.
		Def.Quad{ InitCommand=function(self)
			self:align(0, 0):xy(0, GRAPH_TOP):zoomto(W, GRAPH_H):diffuse(0, 0, 0, DARK) end },
		Def.ActorMultiVertex{ Name="Density", InitCommand=function(self)
			self:SetDrawState{Mode="DrawMode_QuadStrip"}
			self:xy(10, GRAPH_TOP + GRAPH_H - 3)
		end },
	}
	for i = 1, 5 do
		card[#card+1] = Def.Sprite{ Name="Star" .. i, Texture=P.GradeStarPath,
			InitCommand=function(self) self:xy(318 + (i - 1) * 20, 96):zoom(18 / P.GradeAssetSize):visible(false) end }
	end
	for i, counter in ipairs(COUNTERS) do
		local x = 14 + (i - 1) * COLUMN_W
		card[#card+1] = P.Text{ Name="Label" .. i, Cap=9, Condense=0.85, X=x, Baseline=STATS_TOP + 18,
			Tint=MUTE, Text=counter[1], Width=COLUMN_W - 6 }
		card[#card+1] = P.Text{ Name="Value" .. i, Cap=22, Condense=0.75, X=x, Baseline=STATS_TOP + 49,
			Tint=P.White, Width=COLUMN_W - 6 }
	end
	af[#af+1] = card
end

return af
