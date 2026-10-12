-- The info panel at the bottom right of the mockup: the players' names in the
-- profiles' cutout lettering with the key facts of their chart under them,
-- the notes radar star, and one density graph per player with the chart's
-- stream measures beside it.
--
-- Columns and graphs follow the joined players in order, so a lone player
-- always takes the first column and the first graph, in their own colour.
-- The star is Radar.lua.  This is the mockup's own panel; the song select
-- uses the lighter player cards (Cards.lua) unless default.lua says otherwise.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local pieces = P.Art.Pieces

-- Columns: the mockup's "user1" and "user2".
local COLUMN_X = { 1273, 1443 }
local NAME_Y = 444
local NAME = { MaxW = 160, MaxH = 50, Base = 34 }
local INFO_TOP, INFO_PITCH, INFO_LINES = 492, 33, 5
local INFO_CAP, INFO_WIDTH = 16, 160
local MUTE = color("#9a9aa2")

-- The radar: centre and radius from the mockup's star.
local RADAR = { X = 1764, Y = 541, R = 130 }

-- Graphs: the two frames, and the plot inside each.
local GRAPH = { pieces.GraphFrameP1, pieces.GraphFrameP2 }
local PLOT_INSET = { Left = 6, Right = 14, Top = 13, Bottom = 4 }
local DENSITY_SAMPLES = 96
local MEASURES_DX = 12

local function densityVertices(data, w, h, colour)
	local vertices = {}
	if not data or #data.nps == 0 or data.peak <= 0 then return vertices end
	local count = #data.nps
	local tint = { colour[1], colour[2], colour[3], 1 }
	for sample = 0, DENSITY_SAMPLES do
		local position = sample / DENSITY_SAMPLES
		local index = math.min(count, math.max(1, math.floor(position * (count - 1)) + 1))
		local value = data.nps[index] or 0
		local x = position * w
		vertices[#vertices+1] = { {x, 0, 0}, tint }
		vertices[#vertices+1] = { {x, -math.min(h, h * value / data.peak), 0}, tint }
	end
	return vertices
end

local function setVertices(actor, vertices)
	actor:SetNumVertices(#vertices)
	if #vertices > 0 then actor:SetVertices(vertices) end
end

-- The facts under a player's name.
local function infoLines(player, item, chart, data)
	if not chart then return { K.Dash } end
	local meter = math.max(0, math.floor((tonumber(chart:GetMeter()) or 0) + 0.5))
	local lines = {
		("%s %d"):format(K.DifficultyName(chart:GetDifficulty()), meter),
		("%d NOTES"):format(data.notes or 0),
		("PEAK %.1f NPS"):format(data.peak or 0),
		("BEST %s"):format(S.PersonalBest(player, item, chart)),
	}
	local credit = S.StepArtist(chart)
	if credit ~= "" then lines[#lines+1] = credit end
	return lines
end

local af = Def.ActorFrame{
	Name="Panel",
	RefreshCommand=function(self)
		local item = S.Item()
		local players = GAMESTATE:GetHumanPlayers()
		local versus = #players > 1

		for c = 1, 2 do
			local player = players[c]
			local column = self:GetChild("Column" .. c)
			local graph = self:GetChild("Graph" .. c)
			column:visible(player ~= nil)
			graph:visible(player ~= nil)
			if player then
				local chart = S.Chart(player)
				local data = S.ChartData(player)
				local name = S.PlayerName(player)
				if column.name ~= name then
					column.name = name
					P.SetCutout(column:GetChild("Name"), name)
				end
				local lines = infoLines(player, item, chart, data)
				for l = 1, INFO_LINES do
					column:GetChild("Info" .. l):settext(lines[l] or "")
				end

				-- The frame in the player's colour, wherever the column is.
				local frame = GRAPH[c]
				graph:GetChild("FrameP1"):visible(player == PLAYER_1)
				graph:GetChild("FrameP2"):visible(player == PLAYER_2)
				local plotW = frame.W - PLOT_INSET.Left - PLOT_INSET.Right
				local plotH = frame.H - PLOT_INSET.Top - PLOT_INSET.Bottom
				setVertices(graph:GetChild("Density"),
					densityVertices(chart and data or nil, plotW, plotH, P.PlayerColor(player)))
				graph:GetChild("Measures"):settext(chart and ("%d measures"):format(data.streamMeasures) or "")
				graph:GetChild("Detail"):settext(chart
					and ("(%d%% stream, %d notes)"):format(math.floor(data.stream * 100 + 0.5), data.notes)
					or "")
			end
		end

	end,
}

af[#af+1] = P.Piece("Panel")

-- Names and chart facts.
for c = 1, 2 do
	local column = Def.ActorFrame{
		Name = "Column" .. c,
		InitCommand = function(self) self:xy(COLUMN_X[c], 0) end,
		P.CutoutSlot{ Name="Name", X=0, Y=NAME_Y, MaxW=NAME.MaxW, MaxH=NAME.MaxH, Base=NAME.Base,
			Tilt=-3, HAlign=0, VAlign=0.5, MaxChars=16, Scale=K.Scale },
	}
	for l = 1, INFO_LINES do
		column[#column+1] = P.Text{ Name="Info" .. l, Cap=INFO_CAP, Condense=0.8, X=0,
			Baseline=INFO_TOP + (l - 1) * INFO_PITCH, Width=INFO_WIDTH,
			Tint=(l == 1) and P.White or MUTE }
	end
	af[#af+1] = column
end

af[#af+1] = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/Radar.lua"),
	{ K=K, S=S, X=RADAR.X, Y=RADAR.Y, R=RADAR.R })

-- Density graphs.
for c = 1, 2 do
	local frame = GRAPH[c]
	local left, top = frame.X - frame.W / 2, frame.Y - frame.H / 2
	af[#af+1] = Def.ActorFrame{
		Name = "Graph" .. c,
		Def.ActorMultiVertex{
			Name = "Density",
			InitCommand = function(self)
				self:SetDrawState{Mode="DrawMode_QuadStrip"}
				self:xy(left + PLOT_INSET.Left, top + frame.H - PLOT_INSET.Bottom)
			end,
		},
		Def.Sprite{ Name="FrameP1", Texture=P.PiecePath("GraphFrameP1"),
			InitCommand=function(self) self:xy(frame.X, frame.Y) end },
		Def.Sprite{ Name="FrameP2", Texture=P.PiecePath("GraphFrameP2"),
			InitCommand=function(self) self:xy(frame.X, frame.Y) end },
		P.Text{ Name="Measures", Cap=17, Condense=0.8, X=frame.X + frame.W / 2 + MEASURES_DX,
			Baseline=frame.Y - 2, Width=1920 - (frame.X + frame.W / 2 + MEASURES_DX) - 10 },
		P.Text{ Name="Detail", Cap=10, Condense=0.8, X=frame.X + frame.W / 2 + MEASURES_DX,
			Baseline=frame.Y + 18, Width=1920 - (frame.X + frame.W / 2 + MEASURES_DX) - 10, Tint=MUTE },
	}
end

return af
