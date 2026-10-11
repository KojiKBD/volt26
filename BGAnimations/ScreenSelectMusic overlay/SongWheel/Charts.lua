-- The chart list, after Simply Love's difficulty grid: one row per chart with
-- its difficulty, meter and a bar of blocks, and a marker on the side of each
-- player whose chart it is (P1 left, P2 right).  Up to six charts show at
-- once; with more, the list follows the players' choices.
local p = ...
local K, S = p.K, p.S

local listTop = 470
local rowCount = 6
local pitch = 50
local rowHeight = 44
local listLeft, width = 40, 920
local bodyX, bodyWidth = listLeft + 34, width - 68
local blockCount = 12
local blockWidth, blockHeight, blockGap = 30, 20, 6
local blocksX = bodyX + 290

local function chartIndex(charts, chart)
	if not chart then return nil end
	for index, candidate in ipairs(charts) do
		if candidate == chart then return index end
	end
	return nil
end

local function firstVisible(charts)
	if #charts <= rowCount then return 1 end
	local last = 1
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		last = math.max(last, chartIndex(charts, S.Chart(player)) or 1)
	end
	return math.max(1, math.min(last - rowCount + 1, #charts - rowCount + 1))
end

local function setRow(row, chart, charts)
	row:visible(chart ~= nil)
	if not chart then return end
	local difficulty = chart:GetDifficulty()
	local meter = math.max(0, math.floor((tonumber(chart:GetMeter()) or 0) + 0.5))
	local tint = K.DifficultyColor(difficulty)

	local mine = {}
	for player in ivalues(PlayerNumber) do
		mine[player] = GAMESTATE:IsHumanPlayer(player) and S.Chart(player) == chart
	end
	local selected = mine[PLAYER_1] or mine[PLAYER_2]

	row:GetChild("Bg"):diffuse(selected and K.Panel2 or K.Panel):diffusealpha(selected and 1 or 0.85)
	row:GetChild("Stripe"):diffuse(tint)
	K.SetLabel(row:GetChild("Name"), K.DifficultyName(difficulty), 14, 170)
	row:GetChild("Name"):diffuse(tint)
	K.SetDisplay(row:GetChild("Meter"), meter, 34)
	row:GetChild("Meter"):diffuse(selected and K.Ink or K.Mute)

	local blocks = row:GetChild("Blocks")
	for i = 1, blockCount do
		local filled = i <= meter
		blocks:GetChild("Block" .. i):diffuse(filled and tint or K.Line):diffusealpha(filled and 1 or 0.6)
	end

	row:GetChild("MarkerP1"):visible(mine[PLAYER_1])
	row:GetChild("MarkerP2"):visible(mine[PLAYER_2])
end

local af = Def.ActorFrame{
	Name="Charts",
	RefreshCommand=function(self)
		local charts = S.Charts(S.Item())
		local first = firstVisible(charts)
		for i = 1, rowCount do
			setRow(self:GetChild("Row" .. i), charts[first + i - 1], charts)
		end
		local more = #charts - (first + rowCount - 1)
		K.SetLabel(self:GetChild("Count"),
			#charts > rowCount and string.format(K.String("ChartsShown"), first, first + rowCount - 1, #charts) or "", 11)
		self:GetChild("Empty"):visible(#charts == 0)
		self:GetChild("More"):visible(more > 0)
	end,
}

af[#af+1] = K.Text{ Px=11, Tint=K.Dim, X=listLeft, Y=listTop - 2, Text=K.String("Charts") }
af[#af+1] = K.Text{ Name="Count", Px=11, Tint=K.Dim, Align=right, X=listLeft + width, Y=listTop - 2 }
af[#af+1] = K.Text{ Name="Empty", Px=14, Tint=K.Dim, X=bodyX + 16, Y=listTop + 40, Text=K.String("NoCharts") }

local function marker(name, x, tint, text)
	local frame = Def.ActorFrame{
		Name=name,
		InitCommand=function(self) self:x(x):visible(false) end,
	}
	frame[#frame+1] = K.Rule{ AlignX=0.5, AlignY=0.5, Width=28, Height=rowHeight, Tint=tint }
	frame[#frame+1] = K.Text{ Px=11, Tint=K.Ink, Align=center, Text=text }
	return frame
end

for i = 1, rowCount do
	local row = Def.ActorFrame{
		Name="Row" .. i,
		InitCommand=function(self) self:y(listTop + 22 + (i - 0.5) * pitch):visible(false) end,
	}
	row[#row+1] = K.Rule{ Name="Bg", X=bodyX, AlignY=0.5, Width=bodyWidth, Height=rowHeight, Tint=K.Panel }
	row[#row+1] = K.Rule{ Name="Stripe", X=bodyX, AlignY=0.5, Width=6, Height=rowHeight }
	row[#row+1] = K.Text{ Name="Name", Px=14, X=bodyX + 22 }
	row[#row+1] = K.Text{ Name="Meter", Role="Display", Px=34, Tint=K.Ink, Align=right, X=blocksX - 24 }
	local blocks = Def.ActorFrame{ Name="Blocks" }
	for b = 1, blockCount do
		blocks[#blocks+1] = K.Rule{
			Name="Block" .. b, AlignY=0.5,
			X=blocksX + (b - 1) * (blockWidth + blockGap),
			Width=blockWidth, Height=blockHeight,
		}
	end
	row[#row+1] = blocks
	row[#row+1] = marker("MarkerP1", listLeft + 14, K.P1, "P1")
	row[#row+1] = marker("MarkerP2", listLeft + width - 14, K.P2, "P2")
	af[#af+1] = row
end

af[#af+1] = K.Text{ Name="More", Px=11, Tint=K.Dim, Align=center, X=listLeft + width/2,
	Y=listTop + 22 + rowCount * pitch + 8, Text="v" }

return af
