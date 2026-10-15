-- The hidden song's lyrics (VOLT26.Secret.Lyrics, from the song's .lrc), one
-- line at a time in the middle of the screen, over the arrows -- the same
-- place with or without Reverse.  A heavy condensed sans (Fonts/Secret
-- Lyrics Fill / Edge, tools/secret/build_lyrics_font.py) in upper case with a
-- light RGB split: each new line lands with a jolt and a wider split that
-- settles at once, and the line trembles more as the song goes on.  The
-- lines the song leans on are bigger and red.  Loaded by SecretFX.lua, under
-- its flash and its fade to black.
local song = GAMESTATE:GetCurrentSong()
local length = song and tonumber(song:MusicLengthSeconds()) or 0
if not length or length <= 0 then length = 1 end

local scale = SCREEN_HEIGHT / 1080
local W = SCREEN_WIDTH
local LYRIC_CAP = 56                  -- cap height, in 1920x1080 design pixels
local FONT_CAP = 78                   -- the font's cap height at zoom 1
local lyricZoom = LYRIC_CAP * scale / FONT_CAP
local SPLIT = 1.6                     -- resting RGB split, design pixels
local SPLIT_HIT = 8                   -- extra split when a line lands
local SETTLE = 0.12                   -- how fast it settles, seconds
local TREMBLE = { 0.4, 2.2 }          -- jitter at the start and at the end, design pixels
local TREMBLE_RATE = 1 / 14           -- seconds between jitter steps

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

return Def.ActorFrame{
	Name="SecretLyrics",
	InitCommand=function(self) self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):diffusealpha(0) end,
	OnCommand=function(self)
		local lines = VOLT26.Secret.Lyrics()
		local shown, landed, nextJitter = -1, -10, 0
		local jx, jy = 0, 0
		self:SetUpdateFunction(function(lyric)
			local music = GAMESTATE:GetCurMusicSeconds()
			local clock = GetTimeSinceStart()
			local p = math.max(0, math.min(1, (tonumber(music) or 0) / length))
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
			local hit = math.exp(-math.max(0, clock - landed) / SETTLE)
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

	lyricText("Secret Lyrics Edge", "Edge", Color.Black),
	lyricText("Secret Lyrics Fill", "Cyan", color("#00e6ff8c")),
	lyricText("Secret Lyrics Fill", "Red", color("#ff00288c")),
	lyricText("Secret Lyrics Fill", "Fill", Color.White),
}
