-- The difficulty column beside the jacket: one meter badge per chart, easiest
-- at the top, each on a small black square.  A chart nobody has chosen is
-- dimmed.  A chosen one stands on its player's square (P1 red, P2 blue) and
-- its badge is coloured as if seen through it, as the mockup does with an
-- exclusion blend.  When both players choose the same chart the square is
-- split, red half for P1 and blue half for P2; when they choose different
-- ones, each chart gets the whole square in its player's colour.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local pieces = P.Art.Pieces

local MAX_SLOTS = 6
-- The mockup's middle badge sits on its square here; the others follow the
-- column down at the same slant.
local back = pieces.DiffBack
local CENTRE_X, CENTRE_Y = back.X, 200
local PITCH, SPAN = 107, 270
local BADGE_ZOOM = 0.46
local BADGE_DX = 1.5
-- A little disorder, as in the mockup: each slot nudged and turned.
local NUDGE = { 18, 0, -4, 10, -2, 8 }
local TURN = { -6, -2, 3, -4, 2, -3 }
local DIMMED = 0.5

local function chartIndex(charts, chart)
	if not chart then return nil end
	for index, candidate in ipairs(charts) do
		if candidate == chart then return index end
	end
	return nil
end

-- With more charts than slots, the window follows the players' choices.
local function firstShown(charts)
	if #charts <= MAX_SLOTS then return 1 end
	local low, high
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local index = chartIndex(charts, S.Chart(player))
		if index then
			low = math.min(low or index, index)
			high = math.max(high or index, index)
		end
	end
	if not low then return 1 end
	local first = math.max(1, high - MAX_SLOTS + 1)
	first = math.min(first, low)
	return math.max(1, math.min(first, #charts - MAX_SLOTS + 1))
end

local function setSlot(slot, chart)
	slot:visible(chart ~= nil)
	if not chart then return end
	local mine = {}
	for player in ivalues(PlayerNumber) do
		mine[player] = GAMESTATE:IsHumanPlayer(player) and S.Chart(player) == chart
	end
	local p1, p2 = mine[PLAYER_1], mine[PLAYER_2]
	local half1, half2 = slot:GetChild("HalfP1"), slot:GetChild("HalfP2")
	half1:visible(p1 or p2)
	half2:visible(p1 or p2)
	local boxInk, plainInk = P.Ink.Plain, P.Ink.Plain
	if p1 and p2 then
		half1:diffuse(P.Flag); half2:diffuse(P.Blue)
		boxInk, plainInk = P.Ink.P1Box, P.Ink.P2
	elseif p1 then
		half1:diffuse(P.Flag); half2:diffuse(P.Flag)
		boxInk, plainInk = P.Ink.P1Box, P.Ink.P1
	elseif p2 then
		half1:diffuse(P.Blue); half2:diffuse(P.Blue)
		boxInk, plainInk = P.Ink.P2Box, P.Ink.P2
	end
	local meter = math.max(0, math.floor((tonumber(chart:GetMeter()) or 0) + 0.5))
	P.SetBadge(slot:GetChild("Badge"), meter, boxInk, plainInk)
	local chosen = p1 or p2
	slot:diffusealpha(chosen and 1 or DIMMED)
	if chosen and not slot.chosen then
		slot:stoptweening():zoom(1.18):decelerate(0.12):zoom(1)
	end
	slot.chosen = chosen
end

local af = Def.ActorFrame{
	Name="Difficulty",
	RefreshCommand=function(self)
		local charts = S.Charts(S.Item())
		local first = firstShown(charts)
		local shown = math.min(MAX_SLOTS, #charts)
		local pitch = shown > 1 and math.min(PITCH, SPAN / (shown - 1)) or 0
		for i = 1, MAX_SLOTS do
			local slot = self:GetChild("Slot" .. i)
			local chart = i <= shown and charts[first + i - 1] or nil
			if chart then
				slot:xy(CENTRE_X + NUDGE[i], CENTRE_Y + (i - (shown + 1) / 2) * pitch)
					:rotationz(TURN[i])
			end
			setSlot(slot, chart)
		end
	end,
}

for i = 1, MAX_SLOTS do
	af[#af+1] = Def.ActorFrame{
		Name = "Slot" .. i,
		InitCommand = function(self) self:visible(false) end,
		P.Piece("DiffBack", back.X, back.Y),
		-- Over the square: in the mockup the halves turn it red or blue.
		P.Piece("HalfP1", back.X, back.Y),
		P.Piece("HalfP2", back.X, back.Y),
		P.Badge{ Name="Badge", X=BADGE_DX, Y=0, Zoom=BADGE_ZOOM },
	}
end

return af
