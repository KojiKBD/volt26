-- The inherited Simply Love results: letter grade, difficulty, records and the
-- two pane columns the players page through with MenuLeft / MenuRight.
--
-- Their actors keep the screen coordinates Simply Love lays them out in; once
-- the evaluation sequence has finished, the frames that draw them are scaled,
-- tilted and centred as one block in the space to the right of the song card.
-- Behind them sits a VOLT26 slab per column in the title screen's language: a
-- slanted ink body with a white edge over an offset red plate, a slanted red
-- header, and the player's name in cutout lettering.  Input and score state
-- are live from the start.  The song title, banner and BPM line stay hidden
-- because the card shows them; the event overlay, screenshot flash and
-- favourite toast stay full screen.

local players = GAMESTATE:GetHumanPlayers()
local ink = color(VOLT26.Brand.Surfaces.Ink)
local red = color("#FF0000")
local white = color("#FFFFFF")

-- Slab geometry, in the inherited layout's screen units.
local columnGap = 10
local headerTop = 18    -- above the record texts (y 50-60) and the grade (y 66+)
local headerHeight = 22
local bodyBottom = _screen.cy + 222   -- just below the modifiers strip
local skew = 14         -- horizontal lean of every slab, top edge to the right
local edge = 2          -- white rim around the ink body
local plateOffset = 11  -- red plate offset down and right
local tiltDeg = -3      -- the whole block, matching the card's lean

local function columns()
	if #players == 1 then
		return { {player = players[1], left = _screen.cx - 310, right = _screen.cx + 310} }
	end
	return {
		{player = PLAYER_1, left = _screen.cx - 310, right = _screen.cx - columnGap / 2},
		{player = PLAYER_2, left = _screen.cx + columnGap / 2, right = _screen.cx + 310},
	}
end

local source = {
	left = _screen.cx - 310 - edge, right = _screen.cx + 310 + skew + edge + plateOffset,
	top = headerTop - 12, bottom = bodyBottom + edge + plateOffset,
}

-- Space to the right of the card, whose right edge is at 813 of 1920 pixels in
-- the sequence's last frame (see ScreenEvaluationStage background.lua).
local region = {
	left = 832 * SCREEN_WIDTH / 1920, right = SCREEN_WIDTH - 12,
	top = 12, bottom = SCREEN_HEIGHT - 12,
}

local sourceW, sourceH = source.right - source.left, source.bottom - source.top
local regionW, regionH = region.right - region.left, region.bottom - region.top
local tilt = math.rad(tiltDeg)
local ct, st = math.abs(math.cos(tilt)), math.abs(math.sin(tilt))
-- Fit the tilted block's bounding box.
local zoom = math.min(regionW / (sourceW * ct + sourceH * st), regionH / (sourceW * st + sourceH * ct))
local originX = region.left + (regionW - sourceW * zoom) / 2 - source.left * zoom
local originY = region.top + (regionH - sourceH * zoom) / 2 - source.top * zoom
local pivotX, pivotY = (region.left + region.right) / 2, (region.top + region.bottom) / 2

-- A frame drawn at (x, y) with children in screen units is moved so the whole
-- block lands in the region: screen point p maps to origin + p * zoom, then the
-- block turns by tiltDeg about the region's centre.
local function fit(frame)
	if not frame then return end
	local x = originX + frame:GetX() * zoom - pivotX
	local y = originY + frame:GetY() * zoom - pivotY
	local c, s = math.cos(tilt), math.sin(tilt)
	frame:xy(pivotX + x * c - y * s, pivotY + x * s + y * c):zoom(zoom):rotationz(tiltDeg)
end

local function playerName(player)
	local name = PROFILEMAN:GetPlayerName(player)
	if not name or name == "" then name = ToEnumShortString(player) end
	return name
end

-- A parallelogram leaning right: the top edge is shifted by `lean`.
local function slab(left, top, right, bottom, lean, tint, alpha)
	return Def.ActorMultiVertex{
		InitCommand=function(self)
			local c = {tint[1], tint[2], tint[3], alpha or 1}
			self:SetDrawState{Mode="DrawMode_Quads"}
			self:SetVertices{
				{{left + lean, top, 0}, c}, {{right + lean, top, 0}, c},
				{{right, bottom, 0}, c}, {{left, bottom, 0}, c},
			}
		end,
	}
end

local nameSlots = {}

local backdrop = Def.ActorFrame{ Name="VOLT26Backdrop" }
for _, column in ipairs(columns()) do
	local l, r = column.left, column.right
	local top, bottom = headerTop, bodyBottom
	local height = bottom - top
	-- Lean at the header's bottom edge, so the header band follows the body.
	local headerLean = skew * headerHeight / height
	local headerBottom = top + headerHeight

	backdrop[#backdrop+1] = slab(l + plateOffset, top + plateOffset, r + plateOffset, bottom + plateOffset, skew, red)
	backdrop[#backdrop+1] = slab(l - edge, top - edge, r + edge, bottom + edge, skew, white)
	backdrop[#backdrop+1] = slab(l, top, r, bottom, skew, ink, 0.96)
	backdrop[#backdrop+1] = Def.ActorMultiVertex{
		InitCommand=function(self)
			self:SetDrawState{Mode="DrawMode_Quads"}
			self:SetVertices{
				{{l + skew, top, 0}, red}, {{r + skew, top, 0}, red},
				{{r + skew - headerLean, headerBottom, 0}, red}, {{l + skew - headerLean, headerBottom, 0}, red},
			}
		end,
	}
	backdrop[#backdrop+1] = LoadFont(VOLT26.Type.Label)..{
		InitCommand=function(self)
			self:align(1, 0.5):xy(r + skew - 12, top + headerHeight / 2):diffuse(ink)
			VOLT26.Type.SetLabel(self, "RESULTS", 13, (r - l) * 0.35)
		end,
	}

	-- The player's name in cutout lettering.  A single player's upper half
	-- leaves the half opposite the grade empty, so the name fills it large;
	-- with two players it rides the header band, breaking out of its top edge.
	local params
	if #players == 1 then
		local emptyX = column.player == PLAYER_1 and _screen.cx + 155 or _screen.cx - 155
		params = {
			x = emptyX + skew * 0.6, y = (headerBottom + _screen.cy - 60) / 2,
			maxW = 270, maxH = 110, halign = 0.5, valign = 0.5,
			opts = { base = 46, tiltDeg = -6 },
		}
	else
		params = {
			x = l + skew + 8, y = top + headerHeight / 2,
			maxW = (r - l) * 0.55, maxH = 40, halign = 0, valign = 0.5,
			opts = { base = 24, tiltDeg = -4 },
		}
	end
	params.onInit = function(slot) nameSlots[#nameSlots+1] = {slot = slot, name = playerName(column.player)} end
	backdrop[#backdrop+1] = VOLT26.Cutout.CreateSlot(params)
end

local hidden = { TitleAndBanner = true, SongFeatures = true }

return Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	OnCommand=function(self)
		for _, entry in ipairs(nameSlots) do
			entry.slot:playcommand("CutoutSet", {text = entry.name})
		end
	end,
	VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
		fit(self:GetChild("VOLT26Backdrop"))
		local common = self:GetChild("ScreenEval Common")
		if common then
			for name in pairs(hidden) do
				local child = common:GetChild(name)
				if child then child:visible(false) end
			end
			fit(common:GetChild("Panes"))
			for player in ivalues(players) do
				local pn = ToEnumShortString(player)
				fit(common:GetChild(pn .. "_AF_Upper"))
				fit(common:GetChild(pn .. "_AF_Lower"))
			end
		end
		-- No fade: a parent's alpha would be baked into the cutout name's texture.
		self:visible(true)
	end,
	backdrop,
	LoadActor(THEME:GetPathB("ScreenEvaluation", "common")),
}
