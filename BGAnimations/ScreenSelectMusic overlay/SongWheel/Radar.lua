-- The notes radar: the owner's star artwork (docs/notes-radar.md) with each
-- player's reading raised inside it.  Gold for a lone player; with two, P1's
-- red star with P2's blue one laid over it, see-through and edged, so both
-- shapes read where they differ.
--
-- params: K, S, X, Y (centre, design pixels), R (radius: the mean distance of
-- the dark star's points).
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))

local RADAR_X, RADAR_Y, RADAR_R = p.X, p.Y, p.R
local RADAR_P2_ALPHA = 0.45
local RADAR_EDGE = 3
local radarArt = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/VOLT26/RadarArt.lua"))
local radarTips, radarValleys = radarArt.Tips, radarArt.Valleys
local radarCount = VOLT26.ChartRadar.GetAxisCount()
local SEAM_PITCH, SEAM_DOT = 0.124, 0.008

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

local function setVertices(actor, vertices)
	actor:SetNumVertices(#vertices)
	if #vertices > 0 then actor:SetVertices(vertices) end
end

local radar = Def.ActorFrame{
	Name = "Radar",
	InitCommand = function(self) self:xy(RADAR_X, RADAR_Y) end,
	RefreshCommand = function(self)
		local players = GAMESTATE:GetHumanPlayers()
		local versus = #players > 1
		for slot = 1, 2 do
			local reading = self:GetChild("Reading" .. slot)
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
return radar
