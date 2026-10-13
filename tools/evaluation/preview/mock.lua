-- Engine mocks for the WANTED page harness.
local unpack = unpack or table.unpack

PLAYER_1, PLAYER_2 = "PlayerNumber_P1", "PlayerNumber_P2"
PlayerNumber = { PLAYER_1, PLAYER_2 }
_screen = { w = SCREEN_WIDTH, h = SCREEN_HEIGHT, cx = SCREEN_WIDTH / 2, cy = SCREEN_HEIGHT / 2 }
SCREEN_CENTER_X, SCREEN_CENTER_Y = _screen.cx, _screen.cy
SCREEN_RIGHT, SCREEN_BOTTOM = SCREEN_WIDTH, SCREEN_HEIGHT
left, right, center, top, bottom = "left", "right", "center", "top", "bottom"

function ToEnumShortString(e) return tostring(e):match("_([^_]+)$") or tostring(e) end
function ivalues(t) local i = 0 return function() i = i + 1 return t[i] end end
function clamp(v, a, b) return math.max(a, math.min(b, v)) end
function scale(v, a, b, c, d) return c + (v - a) * (d - c) / (b - a) end
function color(s)
	if type(s) == "table" then return s end
	local h = s:gsub("#", "")
	local function c(i) return tonumber(h:sub(i, i + 1), 16) / 255 end
	return { c(1), c(3), c(5), #h >= 8 and c(7) or 1 }
end
function DeepCopy(t)
	if type(t) ~= "table" then return t end
	local r = {} for k, v in pairs(t) do r[k] = DeepCopy(v) end return r
end
Color = { Black = { 0, 0, 0, 1 }, White = { 1, 1, 1, 1 }, Red = { 1, 0, 0, 1 } }

-- ------------------------------------------------------------------ actors
local Actor = {}
local ActorMT = { __index = Actor }
local defMT = {}
defMT.__concat = function(a, b)
	local r = {}
	for k, v in pairs(a) do r[k] = v end
	for k, v in pairs(b) do
		if type(k) == "number" then r[#r + 1] = v else r[k] = v end
	end
	return setmetatable(r, defMT)
end
local function def(cls, t) t = t or {} t.__class = t.__class or cls return setmetatable(t, defMT) end
Def = setmetatable({}, { __index = function(_, cls) return function(t) return def(cls, t) end end })

function LoadFont(name) return def("BitmapText", { Font = name }) end

local fileStack = {}
local function dirOf(p) return p:match("^(.*)/[^/]*$") or "." end
function RunScript(path, ...)
	local f = assert(loadfile(path))
	fileStack[#fileStack + 1] = dirOf(path)
	local r = { f(...) }
	fileStack[#fileStack] = nil
	return unpack(r)
end
function LoadActor(path, ...)
	if path:match("ScreenEvaluation common/?$") then return def("ActorFrame", { Name = "ScreenEval Common" }) end
	if path:match("GrooveStatsURL.lua$") then return "https://groovestats.com/?h=0123456789abcdef&s=9953&j=480,32,41,6,2,1,3" end
	-- A noteskin arrow: a white square in the preview.
	if path:match("NoteSkinPreview.lua$") then
		return def("Quad", { InitCommand = function(self) self:zoomto(52, 52):diffuse({ 1, 1, 1, 1 }) end })
	end
	if not path:match("^/") then
		path = fileStack[#fileStack] .. "/" .. path:gsub("^%./", "")
	end
	if not path:match("%.lua$") then
		if py_exists(path .. "/default.lua") then path = path .. "/default.lua"
		elseif py_exists(path .. ".lua") then path = path .. ".lua" end
	end
	if path:match("ScreenEvaluation common/default.lua$") then
		return def("ActorFrame", { Name = "ScreenEval Common" })
	end
	local r = RunScript(path, ...)
	if type(r) == "table" and getmetatable(r) == nil and r.__class then setmetatable(r, defMT) end
	return r
end

THEME = {}
function THEME:GetPathB(a, b)
	if a == "" then return py_find("BGAnimations/" .. b) end
	return THEME_DIR .. "/BGAnimations/" .. a .. " " .. b
end
function THEME:GetPathG(a, b) return py_find("Graphics/" .. b) end
function THEME:GetPathS(a, b) return py_find("Sounds/" .. b) end
function THEME:GetString(a, b) return b end

BroadcastLog = {}
local allActors = {}
function Broadcast(name, params)
	BroadcastLog[#BroadcastLog + 1] = name
	for _, a in ipairs(allActors) do
		local cmd = a.def[name .. "MessageCommand"]
		if cmd then cmd(a, params or {}) end
	end
end
MESSAGEMAN = { Broadcast = function(_, name, params) Broadcast(name, params) end }

local function newActor(d, parent)
	local a = setmetatable({ def = d, cls = d.__class or "ActorFrame", name = d.Name, parent = parent,
		px = 0, py = 0, prot = 0, zx = 1, zy = 1, ha = 0.5, va = 0.5, shown = true,
		col = { 1, 1, 1, 1 }, txt = d.Text or "", attrs = {}, kids = {}, font = d.Font,
		texture = d.Texture, blendmode = "normal", lw = 1 }, ActorMT)
	if a.cls == "ActorFrame" or a.cls == "ActorFrameTexture" then a.ha, a.va = 0, 0 end
	if a.texture then local s = py_img_size(a.texture) a.iw, a.ih = s[1], s[2] end
	allActors[#allActors + 1] = a
	for _, c in ipairs(d) do
		if type(c) == "table" then a.kids[#a.kids + 1] = newActor(c, a) end
	end
	return a
end

local function run(a, name, params)
	local cmd = a.def[name .. "Command"]
	if cmd then cmd(a, params) end
end
local function init(a)
	for _, c in ipairs(a.kids) do init(c) end
	run(a, "Init")
end
local function on(a)
	run(a, "On")
	for _, c in ipairs(a.kids) do on(c) end
end
function BuildScreenLayer(path)
	local d = RunScript(path)
	local a = newActor(d, nil)
	init(a); on(a)
	return a
end

local function ret(f) return function(self, ...) f(self, ...) return self end end
local function al(v)
	if v == "left" or v == "top" then return 0 elseif v == "right" or v == "bottom" then return 1
	elseif v == "center" or v == "middle" then return 0.5 end
	return v
end
for name, f in pairs({
	xy = function(s, x, y) s.px, s.py = x, y end, x = function(s, v) s.px = v end, y = function(s, v) s.py = v end,
	addx = function(s, v) s.px = s.px + v end, addy = function(s, v) s.py = s.py + v end,
	zoom = function(s, v) s.zx, s.zy = v, v end, zoomx = function(s, v) s.zx = v end, zoomy = function(s, v) s.zy = v end,
	rotationz = function(s, v) s.prot = v end, addrotationz = function(s, v) s.prot = s.prot + v end,
	align = function(s, h, v) s.ha, s.va = al(h), al(v) end,
	halign = function(s, v) s.ha = al(v) end, valign = function(s, v) s.va = al(v) end,
	horizalign = function(s, v) s.ha = al(v) end, vertalign = function(s, v) s.va = al(v) end,
	diffuse = function(s, c) s.col = { c[1], c[2], c[3], c[4] or 1 } end,
	diffusealpha = function(s, a) s.col[4] = a end,
	settext = function(s, t) s.txt = tostring(t) s.attrs = {} end,
	AddAttribute = function(s, start, at) s.attrs[#s.attrs + 1] = { start, at.Length, at.Diffuse } end,
	zoomto = function(s, w, h) s.w, s.h = w, h end, setsize = function(s, w, h) s.w, s.h = w, h end,
	visible = function(s, v) s.shown = v end,
	sleep = function() end, decelerate = function() end, accelerate = function() end, linear = function() end,
	bounceend = function() end, finishtweening = function() end, stoptweening = function() end,
	stopeffect = function() end, queuecommand = function() end,
	playcommand = function(s, name, p) run(s, name, p) end,
	SetDrawState = function(s, t) s.mode = t.Mode end,
	SetVertices = function(s, v) s.verts = v end, SetNumVertices = function() end,
	SetLineWidth = function(s, w) s.lw = w end,
	SetTexture = function(s, t) s.amvtexture = t.path end,
	blend = function(s, b) s.blendmode = (b == "BlendMode_Add") and "add" or "normal" end,
	wrapwidthpixels = function(s, w) s.wrap = w end, maxheight = function(s, h) s.maxh = h end,
	maxwidth = function(s, w) s.maxw = w end, vertspacing = function() end,
	rainbow = function() end, effectperiod = function() end, effectoffset = function() end,
	diffuseshift = function() end, effectcolor1 = function() end, effectcolor2 = function() end,
	spin = function() end, wag = function() end, effectmagnitude = function() end,
	-- Masks are not drawn; the preview does not clip to them.
	MaskSource = function(s) s.shown = false end, MaskDest = function() end,
	FullScreen = function(s) s.px, s.py, s.w, s.h = _screen.cx, _screen.cy, SCREEN_WIDTH, SCREEN_HEIGHT end,
	Center = function(s) s.px, s.py = _screen.cx, _screen.cy end,
}) do Actor[name] = ret(f) end

function Actor:GetChild(name) for _, c in ipairs(self.kids) do if c.name == name then return c end end return nil end
function Actor:GetParent() return self.parent end
function Actor:GetX() return self.px end
function Actor:GetY() return self.py end
function Actor:GetZoomY() return self.zy end
function Actor:GetZoomX() return self.zx end
function Actor:GetText() return self.txt end
function WrappedLines(a)
	local out = {}
	for para in (a.txt .. "\n"):gmatch("(.-)\n") do
		if a.wrap then
			local line = ""
			for word in para:gmatch("%S+") do
				local try = line == "" and word or line .. " " .. word
				if line ~= "" and py_text_width(a.font, try) > a.wrap then out[#out + 1] = line line = word else line = try end
			end
			out[#out + 1] = line
		else out[#out + 1] = para end
	end
	return out
end
function Actor:GetWidth()
	if self.cls == "BitmapText" then
		local w = 0
		for _, l in ipairs(WrappedLines(self)) do w = math.max(w, py_text_width(self.font, l)) end
		return w
	end
	return self.w or self.iw or 0
end
function Actor:GetHeight()
	if self.cls == "BitmapText" then return py_font_spacing(self.font) * #WrappedLines(self) end
	return self.h or self.ih or 0
end
function Actor:GetZoomedWidth() return self:GetWidth() * self.zx end
function Actor:GetZoomedHeight() return self:GetHeight() * self.zy end
function Actor:GetTexture()
	if not self.texture then return nil end
	local s = self
	local function pot(n) local p = 1 while p < n do p = p * 2 end return p end
	return { path = s.texture,
		GetImageWidth = function() return s.iw end, GetImageHeight = function() return s.ih end,
		GetTextureWidth = function() return pot(s.iw) end, GetTextureHeight = function() return pot(s.ih) end }
end

-- ------------------------------------------------------------------ game state
local function steps()
	return {
		GetMeter = function() return 15 end,
		GetDifficulty = function() return "Difficulty_Challenge" end,
		GetTimingData = function() return { GetElapsedTimeFromBeat = function(_, b) return b * 0.375 end } end,
		GetPeakNps = function() return 12 end,
		GetRadarValues = function() return { GetValue = function() return 0 end } end,
	}
end
local song = {
	GetDisplayMainTitle = function() return HARNESS_TITLE end,
	GetDisplayFullTitle = function() return HARNESS_TITLE end,
	GetBackgroundPath = function() return HARNESS_BG ~= "" and HARNESS_BG or nil end,
	HasJacket = function() return false end, HasBanner = function() return false end,
	GetFirstSecond = function() return 2 end, GetLastSecond = function() return 120 end,
}
local humans = HARNESS_PLAYERS == 2 and { PLAYER_1, PLAYER_2 } or { PLAYER_1 }
GAMESTATE = {
	GetHumanPlayers = function() return humans end,
	GetMasterPlayerNumber = function() return PLAYER_1 end,
	IsCourseMode = function() return false end,
	GetCurrentSong = function() return song end,
	GetCurrentCourse = function() return nil end,
	GetCurrentSteps = function() return steps() end,
	GetCurrentTrail = function() return nil end,
	GetPlayerState = function() return { GetPlayerOptionsArray = function()
		return { "C660", "Mini", "Distant", "Cel", "Overhead" } end,
		GetCurrentPlayerOptions = function() return { NoteSkin = function() return "Cel" end } end } end,
	GetCurrentStyle = function() return { ColumnsPerPlayer = function() return 4 end,
		GetColumnInfo = function(_, _, i) return { Name = ({ "Left", "Down", "Up", "Right" })[i] } end } end,
}
function ValidForGrooveStats() return { true, true, true, true, true, true, true }, true, "" end
local function hs(name, pct) return {
	GetName = function() return name end, GetPercentDP = function() return pct end,
	GetScore = function() return math.floor(pct * 1000) end, GetDate = function() return "2026-10-13" end } end
PROFILEMAN = {
	GetMachineProfile = function() return { GetHighScoreList = function() return { GetHighScores = function()
		return { hs("KOJI", 0.9953), hs("RIKA", 0.978), hs("MRXN", 0.972), hs("TOMO", 0.9588), hs("ABCD", 0.91) } end } end } end, GetPlayerName = function(_, p) return p == PLAYER_1 and "USERNAME" or "RIVAL" end }
PREFSMAN = { GetPreference = function() return 1 end }

-- Simply Love helpers the data layer uses.
function GetTimingWindow(n, mode)
	local w = mode == "FA+" and { 0.015, 0.0225, 0.045, 0.090, 0.135 } or { 0.0215, 0.043, 0.102, 0.135, 0.180 }
	return w[n]
end
function DetermineTimingWindow(o)
	for i = 1, 5 do if math.abs(o) <= GetTimingWindow(i) then return i end end
	return 5
end

-- ------------------------------------------------------------------ VOLT26 data
VOLT26 = {
	Gameplay = { GetMode = function() return "ITG" end, IsCasual = function() return false end },
	MusicSelection = { GetMusicRate = function() return 1 end },
	Options = { GetPlayerModifiers = function() return { SpeedModType = "C", SpeedMod = 660, Mini = "30%",
		TimingWindows = { true, true, true, true, true }, ShowFaPlusWindow = true, ShowFaPlusPane = true } end },
	Cutout = {
		GradeLetters = { Grade_Tier05 = "S+", Grade_Tier06 = "S", Grade_Failed = "F" },
		StyleDesign = {
			EvalName = { MaxW = 360, MaxH = 118, Base = 62, Tilt = 3, MaxChars = 16 },
			EvalGrade = { MaxW = 250, MaxH = 170, Base = 120, Tilt = -10, MaxChars = 2 },
			EvalLabel = { MaxW = 250, MaxH = 100, Base = 70, Tilt = -5, MaxChars = 8 },
		},
	},
	CutoutMetrics = { upper = {} },
	Failure = {},
	Gameplay2 = nil,
	Results = {},
	Analysis = {},
	ChartData = {},
}
function VOLT26.Cutout.Style(name)
	local d = VOLT26.Cutout.StyleDesign[name]
	local s = math.min(SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080)
	return { maxW = d.MaxW * s, maxH = d.MaxH * s, maxChars = d.MaxChars, opts = { base = d.Base * s, tiltDeg = d.Tilt } }
end
-- A cutout slot: drawn as plain bold text in the harness.
function VOLT26.Cutout.CreateSlot(p)
	return def("ActorFrame", {
		InitCommand = function(self) if p.onInit then p.onInit(self) end self:rotationz(p.opts.tiltDeg or 0) end,
		CutoutSetCommand = function(self, params)
			local t = self:GetChild("Text")
			t:settext(params.text)
			local z = p.opts.base / 48
			t:zoom(z)
			if t:GetZoomedWidth() > p.maxW then t:zoom(z * p.maxW / t:GetZoomedWidth()) end
		end,
		def("Quad", { Name = "Back", InitCommand = function(self) self:zoomto(0, 0) end }),
		def("BitmapText", { Name = "Text", Font = "VOLT26 Eval Bold",
			InitCommand = function(self) self:valign(0.5):diffuse({ 0.05, 0.05, 0.05, 1 }) end }),
	})
end

local judgments = { W1 = 512, W2 = 41, W3 = 6, W4 = 2, W5 = 1, Miss = HARNESS_FAIL and 40 or 3 }
function VOLT26.Results.GetCurrent(player)
	return {
		failed = HARNESS_FAIL, percentDP = HARNESS_FAIL and 0.4321 or 0.9953, exPercent = HARNESS_FAIL and 41.07 or 99.67,
		grade = HARNESS_FAIL and "Grade_Failed" or "Grade_Tier05",
		judgments = judgments, exJudgments = { W0 = 480 },
		columnJudgments = {
			{ W0 = 120, W1 = 8, W2 = 10, W3 = 2, W4 = 1, W5 = 0, Miss = 1, Early = {}, MissBecauseHeld = 0 },
			{ W0 = 118, W1 = 9, W2 = 11, W3 = 1, W4 = 0, W5 = 1, Miss = 0, Early = {}, MissBecauseHeld = 0 },
			{ W0 = 121, W1 = 7, W2 = 9, W3 = 2, W4 = 1, W5 = 0, Miss = 1, Early = {}, MissBecauseHeld = 0 },
			{ W0 = 121, W1 = 8, W2 = 11, W3 = 1, W4 = 0, W5 = 0, Miss = 1, Early = {}, MissBecauseHeld = 0 },
		},
		radar = { actual = { Holds = 181, Mines = 81, Rolls = 5, Hands = 10 }, possible = { Holds = 183, Mines = 183, Rolls = 6, Hands = 10 } },
		timingWindows = { true, true, true, true, true },
	}
end
function VOLT26.Results.GetStageStats()
	return { GetHighScore = function() return { GetScore = function() return 995 end, GetDate = function() return "2026-10-13" end } end,
		GetLifeRecord = function(_, last, n)
		local r = {}
		for i = 1, n do
			local t = (i - 1) / (n - 1)
			local v = 1 - 0.25 * math.max(0, math.sin(t * 9)) - (HARNESS_FAIL and t * 1.5 or 0)
			r[i] = math.max(0, math.min(1, v))
		end
		return r
	end }
end
function VOLT26.ChartData.Refresh()
	local nps = {}
	for i = 1, 80 do
		local base = (i < 5) and 0 or 6 + 5 * math.sin(i / 6) + ((i % 16 < 8) and 3 or 0)
		if i > 74 then base = 0 end
		nps[i] = math.max(0, base)
	end
	return { NPSperMeasure = nps, PeakNPS = 14 }
end
function VOLT26.Analysis.GetTimeline() return { firstSecond = 0, lastSecond = 120, segments = {} } end
function VOLT26.Analysis.GetTimingOffsets()
	local out, seed = {}, 7
	local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end
	for i = 1, 560 do
		local t = 8 + i * 0.19
		local o = (rnd() + rnd() + rnd() - 1.5) * 0.02
		if i % 140 == 0 then out[#out + 1] = { position = t, offset = "Miss" }
		else out[#out + 1] = { position = t, offset = o } end
	end
	return out
end
function VOLT26.Analysis.GetWorstJudgment() return 3 end
function VOLT26.Analysis.AnalyzeTiming(offsets)
	local n, sum, abs, mx = 0, 0, 0, 0
	for _, s in ipairs(offsets) do if s.offset ~= "Miss" then n = n + 1 sum = sum + s.offset abs = abs + math.abs(s.offset) mx = math.max(mx, math.abs(s.offset)) end end
	local mean = sum / n
	local sq = 0
	for _, s in ipairs(offsets) do if s.offset ~= "Miss" then sq = sq + (s.offset - mean) ^ 2 end end
	return { count = n, meanOffsetMs = mean * 1000, meanAbsoluteMs = abs / n * 1000, sigmaMs = math.sqrt(sq / (n - 1)) * 1000, maxErrorMs = mx * 1000 }
end
function VOLT26.Analysis.BuildHistogram(offsets, worst, binCount)
	local bins, peak, width = {}, 0, worst * 2 / binCount
	for i = 1, binCount do bins[i] = { center = -worst + (i - 0.5) * width, count = 0 } end
	for _, s in ipairs(offsets) do
		if s.offset ~= "Miss" then
			local i = clamp(math.floor((s.offset + worst) / width) + 1, 1, binCount)
			bins[i].count = bins[i].count + 1 peak = math.max(peak, bins[i].count)
		end
	end
	return { bins = bins, peak = peak }
end
function VOLT26.Analysis.BuildScatterBatches(offsets, timeline, width, height, worstWindow)
	local batch = {}
	local lastSecond = math.max(timeline.lastSecond, timeline.firstSecond + 0.001)
	for _, sample in ipairs(offsets or {}) do
		local isMiss = sample.offset == "Miss"
		local noteSecond = sample.position - (isMiss and worstWindow or sample.offset)
		batch[#batch + 1] = {
			x = clamp(scale(noteSecond, timeline.firstSecond, lastSecond + 0.05, 0, width), 0, width),
			y = isMiss and 0 or clamp(scale(sample.offset, worstWindow, -worstWindow, 0, height), 0, height),
			offset = sample.offset, isMiss = isMiss,
		}
	end
	return { batch }
end
function VOLT26.Failure.GetSnapshot()
	if not HARNESS_FAIL then return nil end
	return { total_seconds = 120, death_second = 84 }
end
