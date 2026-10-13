-- The GrooveStats page of one side: Simply Love's QR pane and its best
-- scores, in the artwork's QR box and its two lists split by the bolt.
--
--   * QR code: the GrooveStats upload URL (Simply Love's
--     Pane7/GrooveStatsURL.lua), white on the black box as drawn.  A play
--     GrooveStats would not accept shows why instead; once the score is
--     submitted automatically the code makes way for "already submitted".
--   * GS BEST: the chart's GrooveStats leaderboard, filled in when the
--     automatic submission answers (VOLT26GrooveStatsLeaderboard, sent by
--     Shared/AutoSubmitScore.lua); dashes until then.
--   * MACHINE BEST: the machine's best scores on the chart; this play's
--     entry is highlighted.
--
-- p = { Art, T, player, mirror }
local p = ...
local Art, T, player, mirror = p.Art, p.T, p.player, p.mirror
local qr = Art.qr
local ROWS = 6
local WHITE, RED, DIM = color("#ffffff"), color("#ff0000"), color("#6a6a6a")
local SELF, RIVAL, THIS = color("#a1ff94"), color("#bd94ff"), color("#ffd400")

local status = VOLT26.EvaluationPage.GetGrooveStatsStatus(player)
local url = nil
if status.valid then
	local ok, value = pcall(LoadActor, THEME:GetPathB("ScreenEvaluation", "common/Panes/Pane7/GrooveStatsURL.lua"), player)
	if ok and type(value) == "string" then url = value end
end

local function mx(x) return mirror and 1920 - x or x end

local af = Def.ActorFrame{ Name="Qr" }

-- A block of lines from a text anchor, each line a run of segments.
local function lineAnchor(a, index)
	local r = math.rad(a.rot)
	local gap = (index - 1) * a.lineGap
	return { x = a.x - math.sin(r) * gap, y = a.y + math.cos(r) * gap, rot = a.rot, sx = a.sx, sy = a.sy }
end

-- The code.
local code = Def.ActorFrame{
	Name="Code",
	InitCommand=function(self)
		self:xy(mx(qr.code.cx), qr.code.cy):rotationz(mirror and -qr.code.rot or qr.code.rot)
	end,
	-- The page turned in: the code spins up into place.
	PageShownCommand=function(self)
		local rot = mirror and -qr.code.rot or qr.code.rot
		self:finishtweening():zoom(0.2):rotationz(rot + (mirror and 90 or -90)):sleep(0.08)
			:decelerate(0.2):zoom(1.06):rotationz(rot):accelerate(0.07):zoom(1)
	end,
	VOLT26GrooveStatsSubmittedMessageCommand=function(self, params)
		if params.Player ~= player then return end
		self:GetChild("Modules"):visible(false)
		self:GetChild("Done"):visible(true)
	end,
}
if url then
	local qrencode = loadfile(THEME:GetPathB("", "_modules/QR Code/qrencode.lua"))()
	local ok, matrix = qrencode.qrcode(url)
	if ok and type(matrix) == "table" then
		local n = #matrix
		local cell = qr.code.size / n
		local vertices = {}
		for c, column in ipairs(matrix) do
			for m, module in ipairs(column) do
				if module > 0 then
					local x0, y0 = (m - 1) * cell - qr.code.size / 2, (c - 1) * cell - qr.code.size / 2
					vertices[#vertices+1] = { { x0, y0, 0 }, WHITE }
					vertices[#vertices+1] = { { x0 + cell, y0, 0 }, WHITE }
					vertices[#vertices+1] = { { x0 + cell, y0 + cell, 0 }, WHITE }
					vertices[#vertices+1] = { { x0, y0 + cell, 0 }, WHITE }
				end
			end
		end
		code[#code+1] = Def.ActorMultiVertex{
			Name="Modules",
			InitCommand=function(self) self:SetDrawState{ Mode="DrawMode_Quads" }:SetVertices(vertices) end,
		}
	end
end
if not code[1] then code[#code+1] = Def.Actor{ Name="Modules" } end
code[#code+1] = LoadFont(T.Font.Bold)..{
	Name="Done",
	InitCommand=function(self)
		self:visible(not url):zoom(30 / T.EM.Bold):wrapwidthpixels(qr.code.size / (30 / T.EM.Bold))
			:diffuse(url and WHITE or RED)
			:settext(url and THEME:GetString("GrooveStats", "ScoreAlreadySubmitted") or "NOT VALID FOR\nGROOVESTATS")
	end,
}
af[#af+1] = code

-- The help text: the artwork's four lines, or why the score is not valid.
local help = qr.help
if url then
	local lines = { { "Scan with your " }, { "phone to upload " }, { "this score to " }, { "your ", "GrooveStats." } }
	for index, line in ipairs(lines) do
		local segments = { { font = "Bold", size = help.size, color = WHITE, text = line[1] } }
		if line[2] then segments[2] = { font = "Bold", size = help.size, color = RED, text = line[2] } end
		af[#af+1] = T.Run(lineAnchor(help, index), segments, mirror)
	end
else
	local reasons = {}
	for _, index in ipairs(status.reasons) do
		local ok, text = pcall(function() return THEME:GetString("ScreenEvaluation", "QRInvalidScore" .. index) end)
		if ok and text and not text:find("%%s") then reasons[#reasons+1] = text end
	end
	if #reasons == 0 then reasons[1] = "This score cannot be uploaded." end
	af[#af+1] = LoadFont(T.Font.Bold)..{
		InitCommand=function(self)
			local zoom = help.size * 0.8 / T.EM.Bold
			self:halign(mirror and 1 or 0):valign(0):xy(mx(help.x), help.y - help.size * T.CAP.Bold)
				:rotationz(mirror and -help.rot or help.rot):zoom(zoom):zoomx(zoom * help.sx)
				:wrapwidthpixels(190 / zoom):maxheight(150 / zoom):diffuse(WHITE)
				:settext(table.concat(reasons, "\n"))
		end,
	}
end

-- A best-scores list: a red title, then ROWS lines "NAME  99.53%".
local function list(name, a, title)
	local frame = Def.ActorFrame{ Name=name }
	frame[#frame+1] = T.Run(lineAnchor(a, 1), { { font = "Label", size = a.size, color = RED, text = title } }, mirror)
	for index = 1, ROWS do
		frame[#frame+1] = Def.ActorFrame{
			Name="Row" .. index,
			T.Run(lineAnchor(a, index + 1), { { font = "Label", size = a.size, color = DIM, text = "----" } }, mirror)..{
				Name="Text",
			},
		}
	end
	return frame
end

local function setRow(frame, index, text, tint)
	local run = frame:GetChild("Row" .. index):GetChild("Text")
	local bmt = run:GetChild("Segment1")
	bmt:settext(text):diffuse(tint)
	-- Re-align a mirrored run to its anchor after the text changed.
	if mirror then bmt:x(-bmt:GetZoomedWidth()) end
end

local machine = list("MachineBest", qr.machine, "MACHINE BEST")
machine.OnCommand = function(self)
	for index, entry in ipairs(VOLT26.EvaluationPage.GetBestScores(player, ROWS)) do
		setRow(self, index, entry.name .. "  " .. entry.percent .. "%", entry.isThisPlay and THIS or WHITE)
	end
end
af[#af+1] = machine

local gs = list("GrooveStatsBest", qr.gs, "GS BEST")
gs.VOLT26GrooveStatsLeaderboardMessageCommand = function(self, params)
	if params.Player ~= player then return end
	for index = 1, ROWS do
		local entry = params.Entries[index]
		if entry then
			local tint = entry.isSelf and SELF or entry.isRival and RIVAL or WHITE
			if entry.isFail then tint = RED end
			setRow(self, index, ("%s  %.2f%%"):format(entry.name or "----", entry.score or 0), tint)
		else
			setRow(self, index, "----", DIM)
		end
	end
end
af[#af+1] = gs

return af
