-- The VOLT26 evaluation summary, laid out to the right of the song card:
--
--   * a score panel per player: coloured header with the player tag, name and
--     speed/rate, the letter grade, the ITG percentage, and EX / personal-best
--     chips;
--   * one shared judgment table: player 1's counts on the left, the judgment
--     labels as coloured chips in the middle, player 2's counts on the right,
--     each count with a bar proportional to the chart's steps (a single player
--     gets the left side and the labels move right to give the bars room);
--   * a timing panel per player: offset histogram tinted by timing window,
--     with the mean offset and standard deviation.
--
-- Each panel is a black body with a white rim over an offset plate in the
-- player's colour, turned by a degree or so, like the card it sits beside.
-- All data comes from VOLT26.Results / VOLT26.Analysis; this file only draws.
-- Coordinates are design pixels on a 1920x1080 canvas.

local players = GAMESTATE:GetHumanPlayers()
local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080
local function X(v) return v * sx end
local function S(v) return v * sy end

local black = color("#000000")
local white = color("#FFFFFF")
local body = color("#050101")
local stripe = color(VOLT26.Brand.Surfaces.Ink)
local muted = color("#9A8A8A")
local darkChip = color("#2A2626")
-- Player 2 is blue on this screen, following the evaluation mockup.
local accent = {
	[PLAYER_1] = color("#E8001C"),
	[PLAYER_2] = color("#1F66E8"),
}

local judgmentColors = VOLT26.JudgmentColors.ITG
local fantasticPlus = VOLT26.JudgmentColors["FA+"][2]

local summaries = {}
for player in ivalues(players) do summaries[player] = VOLT26.Results.GetSummary(player) end

local function playerName(player)
	local name = PROFILEMAN:GetPlayerName(player)
	if not name or name == "" then name = ToEnumShortString(player) end
	return name
end

-- Sets text and zooms it to a cap height in design pixels, optionally capped
-- to a width.  Returns the zoom.
local function fitText(actor, text, height, maxWidth)
	actor:settext(tostring(text or ""))
	local zoom = S(height) / math.max(1, actor:GetHeight())
	actor:zoom(zoom)
	if maxWidth then actor:maxwidth(S(maxWidth) / zoom) end
	return zoom
end

local function quad(x, y, w, h, tint, halign)
	return Def.Quad{
		InitCommand=function(self)
			self:xy(S(x), S(y)):zoomto(S(w), S(h)):diffuse(tint)
			if halign then self:halign(halign) end
		end,
	}
end

local function label(text, x, y, px, tint, align, width)
	return LoadFont(VOLT26.Type.Label)..{
		InitCommand=function(self)
			self:xy(S(x), S(y)):halign(align or 0.5):diffuse(tint or white)
			VOLT26.Type.SetLabel(self, text, S(px), width and S(width))
		end,
	}
end

-- A rotated panel: offset plate, white rim, black body, then `contents`,
-- positioned in panel-local design pixels around the panel's centre.
local function panel(cx, cy, w, h, tiltDeg, plate, plateDX, plateDY, contents)
	local frame = Def.ActorFrame{
		InitCommand=function(self) self:xy(X(cx), S(cy)):rotationz(tiltDeg) end,
		quad(plateDX, plateDY, w + 6, h + 6, plate),
		quad(0, 0, w + 6, h + 6, white),
		quad(0, 0, w, h, body),
	}
	for _, actor in ipairs(contents) do frame[#frame+1] = actor end
	return frame
end

-- A chip: a filled box sized to its text.  `anchor` is 0 (grow right from x),
-- 0.5 (centred) or 1 (grow left).  `onWidth` receives the width in design px.
local function chip(text, x, y, height, fill, ink, anchor, font, onWidth)
	return Def.ActorFrame{
		InitCommand=function(self) self:xy(S(x), S(y)) end,
		Def.Quad{ Name="Box", InitCommand=function(self) self:diffuse(fill) end },
		LoadFont(font or "Wendy/_wendy small")..{
			Name="Text",
			InitCommand=function(self)
				self:diffuse(ink)
				fitText(self, text, height * 0.62)
				local w = self:GetZoomedWidth() / sy + height * 0.7
				local box = self:GetParent():GetChild("Box")
				box:zoomto(S(w), S(height))
				local shift = (0.5 - (anchor or 0.5)) * w
				box:x(S(shift)); self:x(S(shift))
				if onWidth then onWidth(w) end
			end,
		},
	}
end

local function speedText(summary)
	local rate = ("%.2fx"):format(summary.musicRate or 1)
	local kind, value = summary.speedModType, summary.speedMod
	if not kind or not value then return rate end
	local speed = kind == "X" and ("%.2fx"):format(value) or (kind .. tostring(math.floor(value + 0.5)))
	return rate .. " · " .. speed
end

-- ---------------------------------------------------------------------------
-- Score panels

local scorePanel = { w = 500, h = 196, header = 40, cy = 152 }
local scoreCentres = #players == 1
	and { [players[1]] = 1375 }
	or { [PLAYER_1] = 1112, [PLAYER_2] = 1640 }
local scoreTilt = { [PLAYER_1] = -1.4, [PLAYER_2] = -1.0 }

local function buildScorePanel(player)
	local summary = summaries[player]
	local tint = accent[player]
	local w, h = scorePanel.w, scorePanel.h
	if #players == 1 then w = 1010 end
	local left, right, top, bottom = -w / 2, w / 2, -h / 2, h / 2
	local headerY = top + scorePanel.header / 2
	local pn = ToEnumShortString(player)
	local percent = FormatPercentScore(summary.percentDP):gsub("%%", "")
	local bodyMid = (top + scorePanel.header + bottom) / 2

	local contents = {
		quad(0, headerY, w, scorePanel.header, tint),
		quad(left + 32, headerY, 44, 28, black),
		LoadFont("Wendy/_wendy small")..{
			InitCommand=function(self)
				self:xy(S(left + 32), S(headerY)):diffuse(white)
				fitText(self, pn, 16, 38)
			end,
		},
		LoadFont("Wendy/_wendy small")..{
			InitCommand=function(self)
				self:xy(S(left + 66), S(headerY)):halign(0):diffuse(white)
				fitText(self, playerName(player):upper(), 22, w * 0.5)
			end,
		},
		label(speedText(summary), right - 16, headerY, 12, white, 1, w * 0.3),
		-- Letter grade.
		LoadActor(THEME:GetPathG("", "_grades/" .. summary.grade .. ".lua"),
			STATSMAN:GetCurStageStats():GetPlayerStageStats(player))..{
			InitCommand=function(self) self:xy(S(left + 85), S(bodyMid)) end,
			OnCommand=function(self) self:zoom(0.36 * SCREEN_HEIGHT / 480) end,
		},
		label("ITG SCORE", right - 22, top + scorePanel.header + 18, 11, muted, 1),
		-- Percentage, with a smaller percent sign.
		LoadFont("Wendy/_wendy small")..{
			Name="PercentSign",
			Text="%",
			InitCommand=function(self)
				self:xy(S(right - 20), S(bodyMid + 14)):halign(1):valign(1):diffuse(white)
				fitText(self, "%", 34)
			end,
		},
		LoadFont("Wendy/_wendy white")..{
			InitCommand=function(self)
				self:halign(1):valign(1):diffuse(white)
				fitText(self, percent, 72)
			end,
			OnCommand=function(self)
				local sign = self:GetParent():GetChild("PercentSign")
				self:xy(sign:GetX() - sign:GetZoomedWidth() - S(2), S(bodyMid + 18))
			end,
		},
	}

	-- EX and personal-best chips, right-aligned along the bottom.
	local chipY = bottom - 24
	local chips = {}
	local pb = summary.personalBest
	if pb then
		if pb.isNew and not pb.delta then
			chips[#chips+1] = {"NEW PB", tint, white}
		elseif pb.isNew then
			chips[#chips+1] = {("NEW PB +%.2f"):format(pb.delta), tint, white}
		else
			chips[#chips+1] = {("%+.2f PB"):format(pb.delta), darkChip, white}
		end
	end
	if not VOLT26.Gameplay.IsCasual() then
		chips[#chips+1] = {("EX %.2f%%"):format(summary.exPercent or 0), white, black}
	end
	local row = Def.ActorFrame{}
	local widths = {}
	for index, spec in ipairs(chips) do
		row[#row+1] = chip(spec[1], 0, chipY, 30, spec[2], spec[3], 1, nil,
			function(width) widths[index] = width end)..{ Name="Chip" .. index }
	end
	row.OnCommand = function(self)
		local x = right - 20
		for index = 1, #chips do
			self:GetChild("Chip" .. index):x(S(x))
			x = x - (widths[index] or 0) - 8
		end
	end
	contents[#contents+1] = row

	local plateDX = player == PLAYER_1 and -10 or 10
	return panel(scoreCentres[player], scorePanel.cy, w, h, scoreTilt[player], tint, plateDX, 10, contents)
end

-- ---------------------------------------------------------------------------
-- Judgment table

local anySplit = false
for player in ivalues(players) do
	if summaries[player].splitFantastic then anySplit = true end
end

local function tns(window)
	return THEME:GetString("TapNoteScore", window):upper()
end

-- Each row: label, chip fill, chip text colour, bar tint (nil: no bar), and a
-- function returning the text and bar value for a summary.
local function windowValue(window, index)
	return function(s)
		if index and s.timingWindows and s.timingWindows[index] == false then return "-", nil end
		return tostring(s.judgments[window]), s.judgments[window]
	end
end
local function radarValue(category)
	return function(s)
		local possible = clamp(s.radar.possible[category], 0, 999)
		return ("%d/%d"):format(s.radar.actual[category], possible), nil
	end
end

local rows = {}
if anySplit then
	rows[#rows+1] = { tns("W1"), judgmentColors[1], black, judgmentColors[1], function(s)
		local n = s.splitFantastic and s.exJudgments.W0 or s.judgments.W1
		return tostring(n), n
	end }
	rows[#rows+1] = { tns("W1"), fantasticPlus, black, color("#D8D8D8"), function(s)
		if not s.splitFantastic then return "-", nil end
		return tostring(s.exJudgments.W1), s.exJudgments.W1
	end }
else
	rows[#rows+1] = { tns("W1"), judgmentColors[1], black, judgmentColors[1], windowValue("W1") }
end
rows[#rows+1] = { tns("W2"), judgmentColors[2], black, judgmentColors[2], windowValue("W2", 2) }
rows[#rows+1] = { tns("W3"), judgmentColors[3], black, judgmentColors[3], windowValue("W3", 3) }
rows[#rows+1] = { tns("W4"), judgmentColors[4], black, judgmentColors[4], windowValue("W4", 4) }
rows[#rows+1] = { tns("W5"), judgmentColors[5], black, judgmentColors[5], windowValue("W5", 5) }
rows[#rows+1] = { tns("Miss"), judgmentColors[6], white, judgmentColors[6], windowValue("Miss") }
rows[#rows+1] = { THEME:GetString("ScreenEvaluation", "Holds"):upper(), white, black, nil, radarValue("Holds") }
rows[#rows+1] = { THEME:GetString("ScreenEvaluation", "Mines"):upper(), white, black, nil, radarValue("Mines") }
rows[#rows+1] = { THEME:GetString("ScreenEvaluation", "Rolls"):upper(), white, black, nil, radarValue("Rolls") }
rows[#rows+1] = { "MAX COMBO", white, black, color("#8A8A8A"), function(s) return tostring(s.maxCombo), s.maxCombo end }

local tableSpec = { cx = 1375, cy = 520, w = 1020, header = 46, rowH = 36, tilt = 0.8 }
tableSpec.h = tableSpec.header + #rows * tableSpec.rowH + 18

local function buildTable()
	local w, h = tableSpec.w, tableSpec.h
	local left, right, top = -w / 2, w / 2, -h / 2
	local single = #players == 1 and players[1] or nil
	-- Label column: centred for two players, pushed to the far side for one.
	local labelX = 0
	if single == PLAYER_1 then labelX = right - 120 elseif single == PLAYER_2 then labelX = left + 120 end
	local sides = {
		[PLAYER_1] = { numX = left + 24, dir = 1, align = 0 },
		[PLAYER_2] = { numX = right - 24, dir = -1, align = 1 },
	}
	for player, side in pairs(sides) do
		side.barMax = math.abs(labelX - side.numX) - 80 - 110 - 20
	end

	local contents = {
		label("JUDGMENTS", labelX, top + 22, 12, muted, 0.5),
	}
	for player in ivalues(players) do
		local side = sides[player]
		contents[#contents+1] = LoadFont("Wendy/_wendy small")..{
			InitCommand=function(self)
				self:xy(S(side.numX), S(top + 22)):halign(side.align):diffuse(accent[player])
				fitText(self, ToEnumShortString(player), 18)
			end,
		}
	end

	for index, row in ipairs(rows) do
		local y = top + tableSpec.header + (index - 0.5) * tableSpec.rowH
		contents[#contents+1] = quad(0, y, w - 16, tableSpec.rowH - 4, index % 2 == 1 and stripe or body)
		-- The chips lean a little each way, like stickers.
		local lean = ({-1.5, 1, -0.5, 1.5, -1, 0.5})[(index - 1) % 6 + 1]
		contents[#contents+1] = chip(row[1], labelX, y, 28, row[2], row[3], 0.5)..{
			OnCommand=function(self) self:rotationz(lean) end,
		}
		for player in ivalues(players) do
			local side = sides[player]
			local summary = summaries[player]
			local text, value = row[5](summary)
			contents[#contents+1] = Def.ActorFrame{
				LoadFont("Wendy/_wendy small")..{
					Name="Number",
					InitCommand=function(self)
						self:xy(S(side.numX), S(y)):halign(side.align):diffuse(text == "-" and muted or white)
						fitText(self, text, 30)
					end,
				},
				Def.Quad{
					InitCommand=function(self)
						if not (row[4] and value and summary.totalSteps > 0) then self:visible(false) return end
						local length = math.max(4, side.barMax * math.min(1, value / summary.totalSteps))
						self:halign(side.align):zoomto(S(length), S(5)):diffuse(row[4])
					end,
					OnCommand=function(self)
						local number = self:GetParent():GetChild("Number")
						self:xy(number:GetX() + side.dir * (number:GetZoomedWidth() + S(12)), S(y))
					end,
				},
			}
		end
	end

	local plate = accent[single or PLAYER_1]
	return panel(tableSpec.cx, tableSpec.cy, w, h, tableSpec.tilt, plate, -8, 10, contents)
end

-- ---------------------------------------------------------------------------
-- Timing panels

local timingSpec = { cy = 905, h = 190, bins = 61 }
local timingCentres = #players == 1
	and { [players[1]] = 1375 }
	or { [PLAYER_1] = 1112, [PLAYER_2] = 1640 }
local timingTilt = { [PLAYER_1] = -0.6, [PLAYER_2] = -0.9 }

local function binColour(offset, split)
	local magnitude = math.abs(offset)
	if split and magnitude <= GetTimingWindow(1, "FA+") then return judgmentColors[1] end
	local window = DetermineTimingWindow(offset)
	if split and window == 1 then return fantasticPlus end
	return judgmentColors[window] or judgmentColors[5]
end

local function buildTimingPanel(player)
	local summary = summaries[player]
	local w, h = 500, timingSpec.h
	if #players == 1 then w = 1010 end
	local left, right, top, bottom = -w / 2, w / 2, -h / 2, h / 2
	local offsets = VOLT26.Analysis.GetTimingOffsets(player)
	local analysis = VOLT26.Analysis.AnalyzeTiming(offsets)
	local worst = GetTimingWindow(math.max(3, VOLT26.Analysis.GetWorstJudgment(offsets)))
	local histogram = VOLT26.Analysis.BuildHistogram(offsets, worst, timingSpec.bins)

	local graphLeft, graphRight = left + 18, right - 18
	local graphBottom, graphTop = bottom - 18, top + 46
	local slot = (graphRight - graphLeft) / timingSpec.bins
	local vertices = {}
	for index, bin in ipairs(histogram.bins) do
		if bin.count > 0 then
			local x0 = graphLeft + (index - 1) * slot + slot * 0.12
			local x1 = graphLeft + index * slot - slot * 0.12
			local y = graphBottom - (graphBottom - graphTop) * bin.count / math.max(1, histogram.peak)
			local tint = binColour(bin.center, summary.splitFantastic)
			vertices[#vertices+1] = {{S(x0), S(y), 0}, tint}
			vertices[#vertices+1] = {{S(x1), S(y), 0}, tint}
			vertices[#vertices+1] = {{S(x1), S(graphBottom), 0}, tint}
			vertices[#vertices+1] = {{S(x0), S(graphBottom), 0}, tint}
		end
	end

	local stats = analysis.count > 0
		and ("MEAN %+.1fms · SD %.1f"):format(analysis.meanOffsetMs, analysis.sigmaMs) or "NO DATA"

	local contents = {
		label("TIMING — " .. ToEnumShortString(player), left + 18, top + 20, 12, muted, 0),
		label(stats, right - 18, top + 20, 12, accent[player], 1, w * 0.6),
		quad((graphLeft + graphRight) / 2, graphBottom + 2, graphRight - graphLeft, 2, judgmentColors[4]),
		Def.ActorMultiVertex{
			InitCommand=function(self)
				self:SetDrawState{Mode="DrawMode_Quads"}
				if #vertices > 0 then self:SetVertices(vertices) end
			end,
		},
	}
	local plateDX = player == PLAYER_1 and -8 or 8
	return panel(timingCentres[player], timingSpec.cy, w, h, timingTilt[player], accent[player], plateDX, 8, contents)
end

-- ---------------------------------------------------------------------------

local af = Def.ActorFrame{ Name="VOLT26Summary" }
if VOLT26.Gameplay.IsCasual() then
	-- Casual play keeps the inherited single-pane layout.
	return af
end
for player in ivalues(players) do af[#af+1] = buildScorePanel(player) end
af[#af+1] = buildTable()
for player in ivalues(players) do af[#af+1] = buildTimingPanel(player) end
return af
