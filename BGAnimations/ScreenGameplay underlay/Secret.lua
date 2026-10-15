-- The hidden song's gameplay (VOLT26.Secret): nothing but the arrows over its
-- own scenery.  The gameplay interface is not built for it (ScreenGameplay
-- underlay/default.lua), and the engine's judgment, combo and lyrics are
-- hidden here.
--
--   * Blood rises from the bottom of a black screen as the song plays and
--     reaches the top as the music ends: a dark liquid whose surface sways in
--     two slow waves, with a lighter sheen on it and a darker layer behind.
--   * The lyrics (VOLT26.Secret.Lyrics, from the song's .lrc) show one line at
--     a time behind the arrows, in a heavy condensed sans (Fonts/Secret
--     Lyrics Fill / Edge, tools/secret/build_lyrics_font.py) with a light RGB
--     split: each new line lands with a jolt and a wider split that settles
--     at once, and the line trembles a little more as the blood rises.
local song = GAMESTATE:GetCurrentSong()
local length = song and tonumber(song:MusicLengthSeconds()) or 0
if not length or length <= 0 then length = 1 end

local scale = SCREEN_HEIGHT / 1080
local W, H, BOTTOM = SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_BOTTOM

-- Blood ------------------------------------------------------------------------
local COLUMNS = 48
local SURFACE = color("#9e0008")      -- at the surface
local DEPTH = color("#330002")        -- at the bottom
local BACK = color("#4d0004")         -- the layer behind
local SHEEN = color("#ff3a3a59")      -- the line along the surface
local WAVE = { 9, 0.0042, 1.1, 5, 0.011, -1.7 }   -- amp, freq (per unit), speed; twice

-- `rough` scales the waves (the breakdown churns the surface).
local rough = 1

local function surfaceY(x, t, level, phase)
	local a1, k1, w1, a2, k2, w2 = WAVE[1], WAVE[2], WAVE[3], WAVE[4], WAVE[5], WAVE[6]
	local wave = a1 * math.sin(x / scale * k1 + t * w1 + phase)
		+ a2 * rough * math.sin(x / scale * k2 + t * w2 * (0.5 + rough * 0.5) + phase * 2)
	return level + wave * rough * scale
end

local function fill(amv, level, t, phase, top, bottom)
	local v = {}
	for i = 0, COLUMNS do
		local x = W * i / COLUMNS
		local y = math.min(BOTTOM, surfaceY(x, t, level, phase))
		v[#v+1] = { { x, y, 0 }, top }
		v[#v+1] = { { x, BOTTOM, 0 }, bottom }
	end
	amv:SetVertices(v)
	amv:SetDrawState{ Mode = "DrawMode_QuadStrip", First = 1, Num = #v }
end

local function sheen(amv, level, t)
	local v = {}
	for i = 0, COLUMNS do
		local x = W * i / COLUMNS
		v[#v+1] = { { x, math.min(BOTTOM, surfaceY(x, t, level, 0)) + 2 * scale, 0 }, SHEEN }
	end
	amv:SetVertices(v)
	amv:SetDrawState{ Mode = "DrawMode_LineStrip", First = 1, Num = #v }
end

-- Lyrics ----------------------------------------------------------------------------
local LYRIC_Y = 0.72                  -- of the screen height
local LYRIC_CAP = 56                  -- cap height, in 1920x1080 design pixels
local FONT_CAP = 78                   -- the font's cap height at zoom 1
local lyricZoom = LYRIC_CAP * scale / FONT_CAP
local SPLIT = 1.6                     -- resting RGB split, design pixels
local SPLIT_HIT = 8                   -- extra split when a line lands
local SETTLE = 0.12                   -- how fast it settles, seconds
local TREMBLE = { 0.4, 2.2 }          -- jitter at the start and at the end, design pixels
local TREMBLE_RATE = 1 / 14           -- seconds between jitter steps

-- Lines the song leans on, lettered bigger and in red.
local EMPHASIS = { "why am i this way", "break down", "terribly lost" }
local function emphasised(text)
	local lower = text:lower()
	for _, key in ipairs(EMPHASIS) do
		if lower:find(key, 1, true) then return true end
	end
	return false
end

local function lyricText(font, name, tint)
	return LoadFont(font)..{
		Name = name,
		InitCommand = function(self)
			self:zoom(lyricZoom):maxwidth(W * 0.92 / lyricZoom):diffuse(tint)
		end,
	}
end

local function progress(t)
	return math.max(0, math.min(1, (tonumber(t) or 0) / length))
end

return Def.ActorFrame{
	Name="SecretUnderlay",
	OnCommand=function(self)
		-- Only the arrows: the engine's judgment, combo and its own lyrics go.
		local screen = SCREENMAN:GetTopScreen()
		local engineLyrics = screen and screen:GetChild("LyricDisplay")
		if engineLyrics then engineLyrics:visible(false) end
		for _, player in ipairs(GAMESTATE:GetHumanPlayers()) do
			local af = screen and screen:GetChild("Player" .. ToEnumShortString(player))
			if af then
				for _, name in ipairs({ "Judgment", "Combo" }) do
					local child = af:GetChild(name)
					if child then child:visible(false) end
				end
			end
		end

		local blood = self:GetChild("Blood")
		local lyric = self:GetChild("Lyric")
		local lines = VOLT26.Secret.Lyrics()
		local T = VOLT26.Secret.Timeline()
		local shown, landed, nextJitter = -1, -10, 0
		local jx, jy = 0, 0
		self:SetUpdateFunction(function(frame)
			local music = GAMESTATE:GetCurMusicSeconds()
			local clock = GetTimeSinceStart()
			local p = progress(music)

			-- Blood: the breakdown churns it, and each "break down" makes it
			-- surge up for a moment.
			local breakdown = VOLT26.Secret.Within(T.Breakdown, music, 0.6)
			local since = breakdown > 0 and VOLT26.Secret.SinceLast(T.Breaks, music) or nil
			local surge = since and math.exp(-since / 0.6) or 0
			rough = 1 + 1.6 * breakdown + 1.5 * surge
			local level = BOTTOM - H * p - H * 0.05 * surge
			fill(blood:GetChild("Back"), level - 7 * scale, clock, 1.9, BACK, DEPTH)
			fill(blood:GetChild("Front"), level, clock, 0, SURFACE, DEPTH)
			sheen(blood:GetChild("Sheen"), level, clock)
			blood:visible(p > 0)

			-- Lyrics
			local index = VOLT26.Secret.LyricIndexAt(music)
			if index ~= shown then
				shown = index
				local line = lines[index]
				local text = line and line.Text or ""
				lyric:stoptweening()
				if text == "" then
					lyric:linear(0.15):diffusealpha(0)
				else
					local strong = emphasised(text)
					local size = strong and 1.25 or 1
					text = text:upper()
					for _, name in ipairs({ "Edge", "Cyan", "Red", "Fill" }) do
						-- The frame's zoom grows emphasised lines; the width
						-- limit shrinks to match, so a long one still fits.
						lyric:GetChild(name):maxwidth(W * 0.92 / (lyricZoom * size)):settext(text)
					end
					lyric:GetChild("Fill"):diffuse(strong and color("#ff2a2a") or Color.White)
					landed = clock
					lyric:diffusealpha(0):zoom(size * 1.12):decelerate(0.1):diffusealpha(1):zoom(size)
				end
			end
			local since = clock - landed
			local hit = math.exp(-math.max(0, since) / SETTLE)
			if clock >= nextJitter then
				nextJitter = clock + TREMBLE_RATE
				local amp = (TREMBLE[1] + (TREMBLE[2] - TREMBLE[1]) * p + 10 * hit) * scale
				jx, jy = (math.random() * 2 - 1) * amp, (math.random() * 2 - 1) * amp * 0.5
			end
			local split = (SPLIT + SPLIT_HIT * hit) * scale
			lyric:GetChild("Cyan"):xy(jx - split, jy)
			lyric:GetChild("Red"):xy(jx + split, jy + split * 0.3)
			lyric:GetChild("Fill"):xy(jx, jy)
			lyric:GetChild("Edge"):xy(jx, jy)
		end)
	end,
	OffCommand=function(self) self:SetUpdateFunction(nil) end,

	Def.Quad{
		Name="Ground",
		InitCommand=function(self) self:FullScreen():diffuse(Color.Black) end,
	},
	Def.ActorFrame{
		Name="Blood",
		InitCommand=function(self) self:visible(false) end,
		Def.ActorMultiVertex{ Name="Back" },
		Def.ActorMultiVertex{ Name="Front" },
		Def.ActorMultiVertex{
			Name="Sheen",
			InitCommand=function(self) self:SetLineWidth(3 * scale) end,
		},
	},
	Def.ActorFrame{
		Name="Lyric",
		InitCommand=function(self) self:xy(SCREEN_CENTER_X, H * LYRIC_Y):diffusealpha(0) end,
		lyricText("Secret Lyrics Edge", "Edge", Color.Black),
		lyricText("Secret Lyrics Fill", "Cyan", color("#00e6ff8c")),
		lyricText("Secret Lyrics Fill", "Red", color("#ff00288c")),
		lyricText("Secret Lyrics Fill", "Fill", Color.White),
	},
}
