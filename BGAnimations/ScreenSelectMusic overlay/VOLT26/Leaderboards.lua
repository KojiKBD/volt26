local args = ...
local H = args.H
local player = args.Player
local pn = ToEnumShortString(player)
local accent = H.Accent(player)
local columnX = args.X
local columnW = args.Width

-- The two leaderboards a lone player gets in the column the radar vacates: the
-- machine's own best times on this chart above, and GrooveStats below.  Both
-- read the same way -- a rank, a name and a percentage -- and both end with this
-- player's own line when it did not make the visible cut, drawn in their colour
-- so it can be found without reading the list.

local panelGap = 14
local panelInset = 0
local headerH = 48
local rowH = 21
local cellPad = 18
local rankW = 24
local scoreW = 78
local maxEntries = 10
local selfGap = 8

local panelX = columnX + panelInset
local panelW = columnW - panelInset*2
local cellX = panelX + cellPad
local cellW = panelW - cellPad*2
local rankRight = cellX + rankW
local nameX = rankRight + 8
local nameW = cellW - rankW - 8 - scoreW - 10
local scoreRight = cellX + cellW

local dash = "--"

local transparent = color("0,0,0,0")

-- These two lists are built the way the songwheel is: no box of their own, no
-- ground of their own, nothing but a caption, a rule under it and the rows.  The
-- one line that is this player's wears the wheel's highlight -- an accent bar
-- with the same wash falling away behind it -- and nothing else on the column
-- carries accent, so the eye finds that line the way it finds the selected song.
local highlightAlpha = 0.22
local selfHighlightAlpha = 0.26

-- --------------------------------------------------------------- local data

local function selfHighScoreName()
	local ok, name = pcall(function()
		return PROFILEMAN:GetProfile(player):GetLastUsedHighScoreName()
	end)
	return ok and type(name) == "string" and name or ""
end

local function localEntries()
	local item, chart = H.Item(), H.Chart(player)
	if not (item and chart) then return nil end
	local ok, scores = pcall(function()
		return PROFILEMAN:GetMachineProfile():GetHighScoreList(item, chart):GetHighScores()
	end)
	if not ok or type(scores) ~= "table" then return nil end

	local mine = selfHighScoreName()
	local entries = {}
	for i, score in ipairs(scores) do
		local name = score:GetName() or ""
		entries[#entries+1] = {
			Rank = i,
			Name = name ~= "" and name or dash,
			Percent = (tonumber(score:GetPercentDP()) or 0)*100,
			IsSelf = mine ~= "" and name == mine,
			IsFail = score:GetGrade() == "Grade_Failed",
		}
	end
	return entries
end

-- ---------------------------------------------------------- groovestats data

-- Keyed by chart hash and player, so hovering back over a chart already asked
-- about costs nothing.  A failed lookup is kept too, for long enough that
-- scrolling through a pack cannot turn into a burst of retries.
local gsCache = {}
local errorRetryAfter = 45

local function cacheKey(hash) return pn.."|"..hash end

local function chartHash()
	local chart = H.Chart(player)
	if not chart or GAMESTATE:IsCourseMode() then return nil end
	local ok, hash = pcall(VOLT26.ChartHash.Compute, chart, player)
	if ok and type(hash) == "string" and hash ~= "" then return hash end
	return nil
end

local function normalizeBoard(board)
	if type(board) ~= "table" then return nil end
	local entries = {}
	for entry in ivalues(board) do
		if type(entry) == "table" then
			entries[#entries+1] = {
				Rank = tonumber(entry.rank) or (#entries + 1),
				Name = type(entry.name) == "string" and entry.name ~= "" and entry.name or dash,
				Percent = (tonumber(entry.score) or 0)/100,
				IsSelf = entry.isSelf == true,
				IsRival = entry.isRival == true,
				IsFail = entry.isFail == true,
			}
		end
	end
	return entries
end

local function gsProcessor(response, params)
	local record = gsCache[params.Key]
	if not record then return end
	record.Time = GetTimeSinceStart()

	local data = VOLT26.GrooveStats.DecodeResponse(response)
	local playerData = type(data) == "table" and data["player"..(player == PLAYER_1 and 1 or 2)] or nil
	if type(playerData) ~= "table" then
		record.State = "error"
		record.Status = "UNAVAILABLE"
		MESSAGEMAN:Broadcast("VOLT26LeaderboardUpdated")
		return
	end

	-- A player scoring in EX wants the EX board first; everyone else gets the
	-- ordinary one.  Either way the fallback is whichever board came back.
	local wantsEx = SL and SL[pn] and SL[pn].ActiveModifiers
		and SL[pn].ActiveModifiers.ShowExScore or false
	local exBoard = normalizeBoard(playerData.exLeaderboard)
	local gsBoard = normalizeBoard(playerData.gsLeaderboard)
	local entries, isEx = {}, false
	if wantsEx and exBoard and #exBoard > 0 then
		entries, isEx = exBoard, true
	elseif gsBoard and #gsBoard > 0 then
		entries, isEx = gsBoard, false
	elseif exBoard and #exBoard > 0 then
		entries, isEx = exBoard, true
	end

	record.State = "ok"
	record.Entries = entries
	record.Status = isEx and "EX" or (playerData.isRanked and "RANKED" or "ITG")
	MESSAGEMAN:Broadcast("VOLT26LeaderboardUpdated")
end

-- ------------------------------------------------------------------- actors

local function panelActor(name)
	local panel = Def.ActorFrame{Name=name}
	panel[#panel+1] = H.Rule{Name="HeaderRule"}
	panel[#panel+1] = H.LabelText{Name="Caption", Px=9, Tint=H.Mute}
	panel[#panel+1] = H.LabelText{Name="Status", Px=9, Tint=H.Dim, Align=right}
	panel[#panel+1] = H.LabelText{Name="Message", Px=10, Tint=H.Dim, Align=center}

	for i=1, maxEntries do
		panel[#panel+1] = H.Rule{Name="RowRule"..i, Alpha=0.5}
		panel[#panel+1] = Def.Quad{
			Name="Highlight"..i,
			InitCommand=function(self)
				self:align(0,0.5):diffuse(accent):diffusealpha(highlightAlpha)
					:diffuserightedge(transparent):visible(false)
			end,
		}
		panel[#panel+1] = Def.Quad{
			Name="HighlightBar"..i,
			InitCommand=function(self)
				self:align(0,0.5):diffuse(accent):visible(false)
			end,
		}
		panel[#panel+1] = H.LabelText{Name="Rank"..i, Px=10, Tint=H.Dim, Align=right}
		panel[#panel+1] = H.LabelText{Name="Name"..i, Px=11, Tint=H.Ink}
		panel[#panel+1] = H.DisplayText{Name="Score"..i, Px=15, Tint=H.Ink, Align=right}
	end

	-- The player's own line, shown only when their best sits outside the rows
	-- above it.
	panel[#panel+1] = H.Rule{Name="SelfRule"}
	panel[#panel+1] = Def.Quad{
		Name="SelfHighlight",
		InitCommand=function(self)
			self:align(0,0.5):diffuse(accent):diffusealpha(selfHighlightAlpha)
				:diffuserightedge(transparent):visible(false)
		end,
	}
	panel[#panel+1] = Def.Quad{
		Name="SelfBar",
		InitCommand=function(self)
			self:align(0,0.5):diffuse(accent):visible(false)
		end,
	}
	panel[#panel+1] = H.LabelText{Name="SelfRank", Px=10, Tint=accent, Align=right}
	panel[#panel+1] = H.LabelText{Name="SelfName", Px=11, Tint=accent}
	panel[#panel+1] = H.DisplayText{Name="SelfScore", Px=15, Tint=accent, Align=right}
	return panel
end

local function layOutPanel(panel, top, height, entries)
	panel.layoutTop, panel.layoutHeight = top, height
	entries = entries or {}
	panel:GetChild("HeaderRule"):xy(cellX, top + headerH):zoomto(cellW, 1)
	panel:GetChild("Caption"):xy(cellX, top + headerH/2)
	panel:GetChild("Status"):xy(scoreRight, top + headerH/2)

	-- Spread the available scores through the body. Reserve the personal row
	-- only when it exists outside the visible top ten.
	local rowsTop = top + headerH + 4
	local selfY = top + height - rowH/2 - 6
	local rows = math.max(1, math.min(maxEntries,
		math.floor((selfY - rowH/2 - selfGap - rowsTop)/rowH)))
	local shown = math.min(rows, #entries)
	local hasSelf = false
	for i, entry in ipairs(entries) do
		if entry.IsSelf then hasSelf = i > shown; break end
	end
	local rowsBottom = hasSelf and (selfY-rowH/2-selfGap) or (top+height-6)
	local pitch = (rowsBottom-rowsTop)/math.max(1, shown)

	for i=1, maxEntries do
		local y = rowsTop + (i-0.5)*pitch
		panel:GetChild("RowRule"..i):xy(cellX, rowsTop+i*pitch):zoomto(cellW, 1):visible(i < shown)
		panel:GetChild("Highlight"..i):xy(panelX, y):zoomto(panelW, pitch)
		panel:GetChild("HighlightBar"..i):xy(panelX, y):zoomto(3, pitch)
		panel:GetChild("Rank"..i):xy(rankRight, y)
		panel:GetChild("Name"..i):xy(nameX, y)
		panel:GetChild("Score"..i):xy(scoreRight, y)
	end

	panel:GetChild("Message"):xy(panelX + panelW/2, (rowsTop + top + height)/2)
	panel:GetChild("SelfRule"):xy(cellX, selfY - rowH/2 - selfGap/2):zoomto(cellW, 1)
	panel:GetChild("SelfHighlight"):xy(panelX, selfY):zoomto(panelW, rowH)
	panel:GetChild("SelfBar"):xy(panelX, selfY):zoomto(3, rowH)
	panel:GetChild("SelfRank"):xy(rankRight, selfY)
	panel:GetChild("SelfName"):xy(nameX, selfY)
	panel:GetChild("SelfScore"):xy(scoreRight, selfY)
	return rows
end

local function clearRow(panel, i)
	panel:GetChild("Highlight"..i):visible(false)
	panel:GetChild("HighlightBar"..i):visible(false)
	H.SetLabel(panel:GetChild("Rank"..i), "", 10)
	H.SetLabel(panel:GetChild("Name"..i), "", 11, nameW)
	H.SetDisplay(panel:GetChild("Score"..i), "", 15)
end

local function setRow(panel, i, entry)
	local isSelf = entry.IsSelf
	panel:GetChild("Highlight"..i):visible(isSelf)
	panel:GetChild("HighlightBar"..i):visible(isSelf)

	local rank = panel:GetChild("Rank"..i)
	H.SetLabel(rank, tostring(entry.Rank), 10)
	rank:diffuse(isSelf and accent or H.Dim)

	local name = panel:GetChild("Name"..i)
	H.SetLabel(name, entry.Name, 11, nameW)
	name:diffuse(isSelf and H.Ink or (entry.IsRival and H.Mute or H.Ink))

	local score = panel:GetChild("Score"..i)
	H.SetDisplay(score, string.format("%.2f%%", entry.Percent), 15)
	score:diffuse(entry.IsFail and H.P1 or (isSelf and accent or H.Ink))
end

local function setSelfRow(panel, entry)
	local shown = entry ~= nil
	panel:GetChild("SelfRule"):visible(shown)
	panel:GetChild("SelfHighlight"):visible(shown)
	panel:GetChild("SelfBar"):visible(shown)
	H.SetLabel(panel:GetChild("SelfRank"), shown and tostring(entry.Rank) or "", 10)
	H.SetLabel(panel:GetChild("SelfName"), shown and entry.Name or "", 11, nameW)
	H.SetDisplay(panel:GetChild("SelfScore"), shown and string.format("%.2f%%", entry.Percent) or "", 15)
end

-- state = {Caption, Status, StatusTint, Entries, Message}
local function fillPanel(panel, rows, state)
	local status = panel:GetChild("Status")
	H.SetLabel(status, state.Status or "", 9, 90)
	status:diffuse(state.StatusTint or H.Dim)
	H.SetLabel(panel:GetChild("Caption"), state.Caption, 9,
		cellW - (state.Status and state.Status ~= "" and status:GetZoomedWidth()+12 or 0))

	local entries = state.Entries or {}
	if panel.layoutTop then
		rows = layOutPanel(panel, panel.layoutTop, panel.layoutHeight, entries)
	end
	local shown = math.min(rows, #entries)
	for i=1, maxEntries do
		if i <= shown then setRow(panel, i, entries[i]) else clearRow(panel, i) end
	end

	-- The player's own line goes underneath only when it is not already on
	-- screen above.
	local mine = nil
	for i, entry in ipairs(entries) do
		if entry.IsSelf then
			if i > shown then mine = entry end
			break
		end
	end
	setSelfRow(panel, mine)

	local message = panel:GetChild("Message")
	local empty = #entries == 0
	message:visible(empty)
	if empty then H.SetLabel(message, state.Message or "NO SCORES", 10, panelW - 24) end
end

-- --------------------------------------------------------------------- frame

-- Both lists sit inside the card, in the column the radar vacates: no ground and
-- no box of their own, just a rule between them, the way the readings and the
-- graph are separated on the other side of the divider.
local af = Def.ActorFrame{
	Name=pn.."Leaderboards",
	LayOutCommand=function(self, p)
		self.layoutParams = p
		local solo = p.Solo and GAMESTATE:IsHumanPlayer(player)
		self:visible(solo)
		if not solo then return end

		local count = self.localCount or 0
		local height = math.min((p.BodyHeight-panelGap)/2,
			headerH + (count == 0 and 52 or (math.min(maxEntries, count)+1)*rowH + selfGap + 12))
		self:GetChild("Divider"):xy(panelX, p.BodyTop + height + panelGap/2):zoomto(panelW, 1)
		self.rowsLocal = layOutPanel(self:GetChild("Local"), p.BodyTop, height)
		self.rowsGs = layOutPanel(self:GetChild("GrooveStats"), p.BodyTop + height + panelGap, p.BodyHeight-height-panelGap)
		-- The spinner rides in the GrooveStats header, where the status text
		-- would otherwise sit.
		self:GetChild("Request"):xy(scoreRight - 8, p.BodyTop + height + panelGap + headerH/2)
	end,
	FillCommand=function(self, p)
		if not (p.Solo and GAMESTATE:IsHumanPlayer(player)) then return end
		self.fillParams = p
		local entries = localEntries() or {}
		self.localCount = #entries
		self:playcommand("LayOut", self.layoutParams)
		fillPanel(self:GetChild("Local"), self.rowsLocal or maxEntries, {
			Caption="LOCAL - MACHINE BEST",
			Status=#entries > 0 and (#entries.." SCORES") or "",
			Entries=entries,
			Message="NO SCORES YET",
		})
		self:playcommand("RefreshGrooveStats")
	end,

	-- GrooveStats is asked about the chart the player has settled on, once per
	-- chart.  Anything that stops that from happening -- no key, service off,
	-- course mode -- is stated in the panel rather than left blank.
	RefreshGrooveStatsCommand=function(self)
		if not (H.IsSolo() and GAMESTATE:IsHumanPlayer(player) and H.Item()) then return end
		local panel = self:GetChild("GrooveStats")
		local rows = self.rowsGs or maxEntries
		local function say(status, message)
			fillPanel(panel, rows, {Caption="GROOVESTATS", Status=status, Entries={}, Message=message})
		end

		if not IsServiceAllowed(SL.GrooveStats.Leaderboard) then
			say("OFFLINE", "GROOVESTATS UNAVAILABLE")
			return
		end
		if not (SL[pn] and SL[pn].ApiKey and SL[pn].ApiKey ~= "") then
			say("NO KEY", "NO API KEY FOR THIS PROFILE")
			return
		end

		local hash = chartHash()
		if not hash then
			say("", "NO CHART HASH")
			return
		end

		local key = cacheKey(hash)
		local record = gsCache[key]
		local now = GetTimeSinceStart()
		if record and record.State == "error" and now - (record.Time or 0) > errorRetryAfter then
			record = nil
		end

		if record then
			if record.State == "loading" then
				say("", "LOADING")
			elseif record.State == "ok" then
				fillPanel(panel, rows, {
					Caption="GROOVESTATS",
					Status=record.Status,
					StatusTint=accent,
					Entries=record.Entries,
					Message="NO SCORES",
				})
			else
				say(record.Status or "ERROR", "COULD NOT LOAD")
			end
			return
		end

		gsCache[key] = {State="loading", Time=now}
		say("", "LOADING")

		local query = {maxLeaderboardResults=maxEntries}
		query["chartHashP"..(player == PLAYER_1 and 1 or 2)] = hash
		local headers = {}
		headers["x-api-key-player-"..(player == PLAYER_1 and 1 or 2)] = SL[pn].ApiKey

		self:GetChild("Request"):playcommand("MakeGrooveStatsRequest", {
			endpoint="?action=playerLeaderboards&"..NETWORK:EncodeQueryParameters(query),
			method="GET",
			headers=headers,
			timeout=10,
			callback=gsProcessor,
			args={Key=key},
		})
	end,
	VOLT26LeaderboardUpdatedMessageCommand=function(self)
		if self.fillParams then self:playcommand("RefreshGrooveStats") end
	end,
}

af[#af+1] = H.Rule{Name="Divider"}
af[#af+1] = panelActor("Local")
af[#af+1] = panelActor("GrooveStats")

local request = RequestResponseActor(0, 0)
request.Name = "Request"
af[#af+1] = request

return af
