-- The info panel at the bottom right of the mockup: the players' names in the
-- profiles' cutout lettering with the key facts of their chart under them,
-- the notes radar star, and one density graph per player with the chart's
-- stream measures beside it.
--
-- Columns and graphs follow the joined players in order, so a lone player
-- always takes the first column and the first graph, in their own colour.
-- The star is gold for a lone player; with two, P1's red star and P2's blue
-- one are laid over each other, P2's on top and see-through.
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
local RADAR_X, RADAR_Y, RADAR_R = 1764, 541, 130
-- With two players P2's star is laid over P1's, see-through and edged, so
-- both shapes read where they differ.
local RADAR_P2_ALPHA = 0.45
local RADAR_EDGE = 3
local radarArt = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/RadarArt.lua"))
local radarTips, radarValleys = radarArt.Tips, radarArt.Valleys
local radarCount = VOLT26.ChartRadar.GetAxisCount()
local SEAM_PITCH, SEAM_DOT = 0.124, 0.008

-- Graphs: the two frames, and the plot inside each.
local GRAPH = { pieces.GraphFrameP1, pieces.GraphFrameP2 }
local PLOT_INSET = { Left = 6, Right = 14, Top = 13, Bottom = 4 }
local DENSITY_SAMPLES = 96
local MEASURES_DX = 12

-- GetCurrentThemeDirectory() is relative ("Themes/VOLT26/"); anchor it, and
-- check first, since THEME:GetPathG stops on a missing file.
local function radarAsset(file)
	local path = ("/" .. THEME:GetCurrentThemeDirectory() .. "Graphics/VOLT26/SongSelection/NotesRadar/" .. file):gsub("^//", "/")
	return FILEMAN:DoesFileExist(path) and path or nil
end

-- Every point of the star is two triangles meeting on the ridge from the
-- centre to the tip, shaded on one side and lit on the other, as in the
-- owner's artwork (see docs/notes-radar.md).
local function starVertices(tips, valleys, radius, colours, alpha)
	local lit = { colours.Lit[1], colours.Lit[2], colours.Lit[3], alpha }
	local shade = { colours.Shade[1], colours.Shade[2], colours.Shade[3], alpha }
	local vertices = {}
	for i = 1, radarCount do
		local before = i == 1 and radarCount or i - 1
		local t, b, a = radarTips[i], radarValleys[before], radarValleys[i]
		local ts, bs, as = tips[i] * radius, valleys[before] * radius, valleys[i] * radius
		vertices[#vertices+1] = { {0, 0, 0}, shade }
		vertices[#vertices+1] = { {b[1] * bs, b[2] * bs, 0}, shade }
		vertices[#vertices+1] = { {t[1] * ts, t[2] * ts, 0}, shade }
		vertices[#vertices+1] = { {0, 0, 0}, lit }
		vertices[#vertices+1] = { {t[1] * ts, t[2] * ts, 0}, lit }
		vertices[#vertices+1] = { {a[1] * as, a[2] * as, 0}, lit }
	end
	return vertices
end

local function seamVertices(tips, radius, colour, alpha)
	local rgba = { colour[1], colour[2], colour[3], alpha }
	local vertices = {}
	local pitch = math.max(5, radius * SEAM_PITCH)
	local half = math.max(0.75, radius * SEAM_DOT / 2)
	for i = 1, radarCount do
		local t = radarTips[i]
		local norm = math.sqrt(t[1] * t[1] + t[2] * t[2])
		local length = norm * tips[i] * radius
		local dx, dy = t[1] / norm, t[2] / norm
		local d = pitch
		while d < length - pitch * 0.5 do
			local x, y = dx * d, dy * d
			vertices[#vertices+1] = { {x - half, y - half, 0}, rgba }
			vertices[#vertices+1] = { {x + half, y - half, 0}, rgba }
			vertices[#vertices+1] = { {x + half, y + half, 0}, rgba }
			vertices[#vertices+1] = { {x - half, y + half, 0}, rgba }
			d = d + pitch
		end
	end
	return vertices
end

-- The star's edge: points and valleys in turn, closed.
local function edgeVertices(tips, valleys, radius, colour)
	local rgba = { colour[1], colour[2], colour[3], 1 }
	local vertices = {}
	for i = 1, radarCount + 1 do
		local k = (i - 1) % radarCount + 1
		local t, v = radarTips[k], radarValleys[k]
		vertices[#vertices+1] = { {t[1] * tips[k] * radius, t[2] * tips[k] * radius, 0}, rgba }
		if i <= radarCount then
			vertices[#vertices+1] = { {v[1] * valleys[k] * radius, v[2] * valleys[k] * radius, 0}, rgba }
		end
	end
	return vertices
end

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

		-- The radar.
		local radar = self:GetChild("Radar")
		for slot = 1, 2 do
			local reading = radar:GetChild("Reading" .. slot)
			local player = players[slot]
			local data = player and S.ChartData(player) or nil
			local axes = data and data.radar
			local show = data and data.techAvailable and type(axes) == "table" and #axes == radarCount
			reading:visible(show and true or false)
			if show then
				local colours = (not versus) and P.Gold or (player == PLAYER_1 and P.P1Star or P.P2Star)
				local alpha = (versus and slot == 2) and RADAR_P2_ALPHA or 1
				local tips, valleys = VOLT26.ChartRadar.StarRadii(axes, 1)
				setVertices(reading:GetChild("Faces"), starVertices(tips, valleys, RADAR_R, colours, alpha))
				setVertices(reading:GetChild("Seams"), seamVertices(tips, RADAR_R, colours.Seam, alpha))
				local edged = versus and slot == 2
				reading:GetChild("Edge"):visible(edged)
				if edged then setVertices(reading:GetChild("Edge"), edgeVertices(tips, valleys, RADAR_R, colours.Lit)) end
				if reading.chart ~= data.chart then
					reading.chart = data.chart
					reading:stoptweening():zoom(0.82):decelerate(0.16):zoom(1)
				end
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

-- The notes radar.
local radar = Def.ActorFrame{
	Name = "Radar",
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
}
local backdrop, labels = radarAsset("backdrop.png"), radarAsset("labels.png")
if backdrop then
	radar[#radar+1] = Def.Sprite{ Texture=backdrop,
		InitCommand=function(self) self:zoom(RADAR_R / radarArt.ArtRadius) end }
end
for slot = 1, 2 do
	radar[#radar+1] = Def.ActorFrame{
		Name = "Reading" .. slot,
		Def.ActorMultiVertex{ Name="Faces", InitCommand=function(self) self:SetDrawState{Mode="DrawMode_Triangles"} end },
		Def.ActorMultiVertex{ Name="Seams", InitCommand=function(self) self:SetDrawState{Mode="DrawMode_Quads"} end },
		Def.ActorMultiVertex{ Name="Edge", InitCommand=function(self)
			self:SetDrawState{Mode="DrawMode_LineStrip"}
			self:SetLineWidth(RADAR_EDGE)
		end },
	}
end
if labels then
	radar[#radar+1] = Def.Sprite{ Texture=labels,
		InitCommand=function(self) self:zoom(RADAR_R / radarArt.ArtRadius) end }
end
af[#af+1] = radar

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
