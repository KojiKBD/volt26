-- Extra mocks for the end-of-session screens.
local unpack = unpack or table.unpack
local Actor = getmetatable(BuildProbe()).__index
local function ret(f) return function(self, ...) f(self, ...) return self end end
for name, f in pairs({
	draworder = function(s, v) s.dord = v end,
	SortByDrawOrder = function(s) table.sort(s.kids, function(a, b) return (a.dord or 0) < (b.dord or 0) end) end,
	Load = function(s, p) s.texture = p local sz = py_img_size(p) s.iw, s.ih = sz[1], sz[2] end,
	animate = function() end, setstate = function(s, v) s.state = v end,
	cropleft = function() end, cropright = function() end, croptop = function() end, cropbottom = function() end,
	shadowlength = function() end, ClearAttributes = function(s) s.attrs = {} end,
	glowblink = function() end, hibernate = function() end,
}) do Actor[name] = ret(f) end
function Actor:GetDiffuseAlpha() return self.col[4] end

THEME.GetMetric = function() return 23 end
function ScreenString(k)
	return ({ EnterName = "Enter your name", OutOfRanking = "Out of Ranking", HeaderText = HARNESS_HEADER,
		Session = "Session", StatSongs = "Songs", StatNotes = "Notes", StatTime = "Time",
		StatTotal = "Total songs", StatCalories = "Kcal" })[k] or k
end
function GetPlayerAvatarPath() return nil end
SCREENMAN = { GetTopScreen = function() return { AddInputCallback = function() end, GetChild = function() return nil end } end }
PROFILEMAN.IsPersistentProfile = function() return true end
PROFILEMAN.GetProfile = function(_, p) return { GetLastUsedHighScoreName = function() return p == PLAYER_1 and "KOJI" or "" end,
	GetDisplayName = function() return p == PLAYER_1 and "Koji" or "SilverFox" end } end
SL = { P1 = { HighScores = { EnteringName = true, Name = "" } }, P2 = { HighScores = { EnteringName = HARNESS_P2_ENTER, Name = "" } } }
VOLT26.Type = {}
VOLT26.Cutout.GradeLetters = {
	Grade_Tier05 = "S+", Grade_Tier06 = "S", Grade_Tier07 = "S-", Grade_Tier08 = "A+", Grade_Tier09 = "A",
	Grade_Tier10 = "A-", Grade_Tier17 = "D", Grade_Failed = "F" }
VOLT26.Cutout.StyleDesign.SongCardName = { MaxW = 330, MaxH = 54, Base = 36, Tilt = -3, MaxChars = 16 }
VOLT26.Cutout.StyleDesign.GameOverTitle = { MaxW = 700, MaxH = 92, Base = 64, Tilt = -3, MaxChars = 24 }
-- Cutout lettering stand-in: white bold text on a black box.
function VOLT26.Cutout.CreateSlot(p)
	return setmetatable({ __class = "ActorFrame",
		InitCommand = function(self) self:rotationz(p.opts.tiltDeg or 0) end,
		CutoutSetCommand = function(self, params)
			local t, b = self:GetChild("Text"), self:GetChild("Back")
			t:settext(params.text)
			local z = p.opts.base / 40
			t:zoom(z)
			if t:GetZoomedWidth() > p.maxW then t:zoom(z * p.maxW / t:GetZoomedWidth()) end
			local w, h = t:GetZoomedWidth() + 14, t:GetZoomedHeight() * 0.9
			t:halign(p.halign or 0.5)
			b:zoomto(w, h):halign(p.halign or 0.5):x((p.halign == 0 and -7) or (p.halign == 1 and 7) or 0)
		end,
		setmetatable({ __class = "Quad", Name = "Back", InitCommand = function(self) self:zoomto(0, 0):diffuse({ 0, 0, 0, 1 }) end }, getmetatable(Def.Quad{})),
		setmetatable({ __class = "BitmapText", Name = "Text", Font = "VOLT26 Eval Bold",
			InitCommand = function(self) self:valign(0.5):diffuse({ 1, 1, 1, 1 }) end }, getmetatable(Def.Quad{})),
	}, getmetatable(Def.Quad{}))
end

local titles = { "Agony", "A Cruel Angel's Thesis", "Feryquitous", "Hyper Bass With You", "All I Want Is You" }
local function song(i) return { GetDisplayMainTitle = function() return titles[i] end,
	GetDisplayFullTitle = function() return titles[i] end, HasJacket = function() return false end, HasBanner = function() return false end } end
local grades = { "Grade_Tier05", "Grade_Tier02", "Grade_Tier00", "Grade_Tier09", "Grade_Failed" }
local meters = { 12, 10, 14, 11, 13 }
VOLT26.Evaluation = {
	GetStageCount = function() return #titles end,
	GetStageContext = function(i) return { item = song(i) } end,
	GetPlayerStageSnapshot = function(p, i)
		if p == PLAYER_2 and i == 1 then return nil end
		return { profile = p == PLAYER_1 and "Koji" or "SilverFox", grade = grades[i], meter = meters[i],
			score = 0.9953 - i * 0.01, exscore = 99.67 - i * 1.3, steps = {} }
	end,
}
VOLT26.Session = {
	GetSummary = function() return { songs_played = 5, tap_hits = 3412, active_seconds = 1834 } end,
	GetProfileSummary = function() return { display_name = "Koji", total_songs = 4218, calories = 312 } end,
	FormatDuration = function(s) return { hours = math.floor(s / 3600), minutes = math.floor(s % 3600 / 60), seconds = s % 60 } end,
}
setmetatable(VOLT26.Cutout.StyleDesign, { __index = function() return { MaxW = 300, MaxH = 60, Base = 36, Tilt = -3, MaxChars = 16 } end })
local realLoadActor = LoadActor
function LoadActor(path, ...)
	if tostring(path):match("/Sounds/") then return Def.Actor{} end
	return realLoadActor(path, ...)
end
