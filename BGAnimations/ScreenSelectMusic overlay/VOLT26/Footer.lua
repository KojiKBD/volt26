local H = ...

local bandTop = H.H - H.FooterH
local middleY = bandTop + H.FooterH/2
local keyHeight = 20
local keyPadX = 6
local keyGap = 8
local itemGap = 28
local startPadX = 26
local startHeight = 38
local indicatorGap = 24
local dotSize = 8

-- The four things a player can do from here, in the order the buttons sit on a
-- cabinet.  An arrow pair is drawn rather than typed: the label face has no
-- arrow glyphs, and the design asks for shapes over icon bitmaps anyway.
local legend = {
	{Arrows="vertical",   Caption="HintSong"},
	{Arrows="horizontal", Caption="HintDifficulty"},
	{Key="SELECT",        Caption="HintOptions"},
	{Key="BACK",          Caption="HintGroup"},
}

local arrowSpan = 5
local arrowHalf = 4
local arrowGap = 2

local function arrowVertices(orientation)
	local tint = {H.Ink[1], H.Ink[2], H.Ink[3], 1}
	local function triangle(ax, ay, bx, by, cx, cy)
		return {{{ax,ay,0}, tint}, {{bx,by,0}, tint}, {{cx,cy,0}, tint}}
	end
	local vertices = {}
	local function append(points)
		for _, point in ipairs(points) do vertices[#vertices+1] = point end
	end
	if orientation == "vertical" then
		local offset = arrowSpan/2 + arrowGap/2
		append(triangle(0, -offset-arrowSpan, -arrowHalf, -offset, arrowHalf, -offset))
		append(triangle(0, offset+arrowSpan, -arrowHalf, offset, arrowHalf, offset))
	else
		local offset = arrowSpan/2 + arrowGap/2
		append(triangle(-offset-arrowSpan, 0, -offset, -arrowHalf, -offset, arrowHalf))
		append(triangle(offset+arrowSpan, 0, offset, -arrowHalf, offset, arrowHalf))
	end
	return vertices
end

local function indicatorLit(player)
	return GAMESTATE:IsHumanPlayer(player) and H.Chart(player) ~= nil
end

local af = Def.ActorFrame{
	Name="Footer",
	RefreshCommand=function(self)
		local x = H.Pad
		for index, entry in ipairs(legend) do
			local keyText = self:GetChild("KeyText"..index)
			local arrows = self:GetChild("Arrows"..index)
			local contentWidth
			if entry.Key then
				H.SetLabel(keyText, entry.Key, 10)
				contentWidth = keyText:GetZoomedWidth()
			else
				contentWidth = (arrowSpan + arrowGap/2)*2 + 2
			end
			local boxWidth = contentWidth + keyPadX*2 + 2

			self:GetChild("KeyBorder"..index):xy(x, middleY):zoomto(boxWidth, keyHeight)
			self:GetChild("KeyFill"..index):xy(x+1, middleY):zoomto(boxWidth-2, keyHeight-2)
			keyText:xy(x + boxWidth/2, middleY):visible(entry.Key ~= nil)
			arrows:xy(x + boxWidth/2, middleY):visible(entry.Arrows ~= nil)

			local caption = self:GetChild("Caption"..index)
			H.SetLabel(caption, H.String(entry.Caption), 10)
			caption:xy(x + boxWidth + keyGap, middleY)
			x = x + boxWidth + keyGap + caption:GetZoomedWidth() + itemGap
		end

		-- The right of the band is laid out from the screen edge inwards, so the
		-- START button keeps its place whatever the player names cost.
		local startLabel = self:GetChild("StartLabel")
		H.SetLabel(startLabel, "START", 18)
		local startWidth = startLabel:GetZoomedWidth() + startPadX*2
		local right = H.W - H.Pad
		self:GetChild("StartFill"):xy(right, middleY):zoomto(startWidth, startHeight)
		startLabel:xy(right - startWidth/2, middleY)
		right = right - startWidth - itemGap

		for _, player in ipairs({PLAYER_2, PLAYER_1}) do
			local pn = ToEnumShortString(player)
			local text = self:GetChild(pn.."Ready")
			local dot = self:GetChild(pn.."Dot")
			local lit = indicatorLit(player)
			H.SetLabel(text, pn.." "..H.String("Ready"), 10)
			text:xy(right, middleY):diffuse(lit and H.Mute or H.Dim)
			dot:xy(right - text:GetZoomedWidth() - keyGap, middleY)
				:diffuse(lit and H.Accent(player) or H.Line)
			right = right - text:GetZoomedWidth() - keyGap - dotSize - indicatorGap
		end
	end,
}

af[#af+1] = H.Rule{Name="Divider", Y=bandTop, Width=H.W, Height=1}

for index, entry in ipairs(legend) do
	af[#af+1] = Def.Quad{
		Name="KeyBorder"..index,
		InitCommand=function(self) self:align(0,0.5):diffuse(H.Dim) end,
	}
	af[#af+1] = Def.Quad{
		Name="KeyFill"..index,
		InitCommand=function(self) self:align(0,0.5):diffuse(H.Bg) end,
	}
	af[#af+1] = H.LabelText{Name="KeyText"..index, Px=10, Tint=H.Ink, Align=center}
	af[#af+1] = Def.ActorMultiVertex{
		Name="Arrows"..index,
		InitCommand=function(self)
			local vertices = entry.Arrows and arrowVertices(entry.Arrows) or {}
			self:SetDrawState({Mode="DrawMode_Triangles"})
				:SetNumVertices(#vertices):SetVertices(vertices):visible(false)
		end,
	}
	af[#af+1] = H.LabelText{Name="Caption"..index, Px=10, Tint=H.Dim}
end

for _, player in ipairs({PLAYER_1, PLAYER_2}) do
	local pn = ToEnumShortString(player)
	af[#af+1] = Def.Quad{
		Name=pn.."Dot",
		InitCommand=function(self) self:align(1,0.5):zoomto(dotSize, dotSize):diffuse(H.Line) end,
	}
	af[#af+1] = H.LabelText{Name=pn.."Ready", Px=10, Tint=H.Mute, Align=right}
end

af[#af+1] = Def.Quad{
	Name="StartFill",
	InitCommand=function(self) self:align(1,0.5):diffuse(H.Ink) end,
}
af[#af+1] = H.LabelText{Name="StartLabel", Px=18, Tint=H.Bg, Align=center}

H.AddRefresh(af)
return af
