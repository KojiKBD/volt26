-- The hidden song's gameplay (VOLT26.Secret): nothing but the arrows over its
-- own scenery.  The gameplay interface is not built for it (ScreenGameplay
-- underlay/default.lua), and the engine's judgment, combo and lyrics are
-- hidden here.  The lyrics draw over the arrows (ScreenGameplay overlay/
-- SecretLyrics.lua).
--
-- Blood rises from the bottom of a black screen as the song plays and reaches
-- the top as the music ends: thick, dirty blood -- a clotted texture
-- (Graphics/VOLT26/Secret/blood.png, tools/secret/build_blood_texture.py)
-- drifting slowly inside a liquid with a lumpy, swaying surface, a darker
-- crust along it, a faint sheen on top and a darker layer behind.  The
-- breakdown churns it and each "break down" makes it surge.
local song = GAMESTATE:GetCurrentSong()
local length = song and tonumber(song:MusicLengthSeconds()) or 0
if not length or length <= 0 then length = 1 end

local scale = SCREEN_HEIGHT / 1080
local W, H, BOTTOM = SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_BOTTOM

local COLUMNS = 72
local TILE = 420 * scale              -- the texture's size on screen
local SURFACE = color("#a3000b")      -- at the surface
local DEPTH = color("#2e0002")        -- at the bottom
local BACK = color("#450003")         -- the layer behind
local CRUST = color("#1c0000b0")      -- the clotted band under the surface
local CRUST_DEPTH = 34                -- its depth, design pixels
local SHEEN = color("#ff4a4a40")      -- the line along the surface
local WAVE = { 8, 0.0042, 1.0, 4, 0.011, -1.6 }   -- amp, freq (per unit), speed; twice
local LUMPS = 7                       -- design pixels of lumpiness

-- Lumps: a fixed, smoothed random height per column that breathes slowly.
math.randomseed(26)
local lumps = {}
for i = 0, COLUMNS do lumps[i] = math.random() * 2 - 1 end
for _ = 1, 2 do
	local smooth = {}
	for i = 0, COLUMNS do
		smooth[i] = (lumps[math.max(0, i - 1)] + 2 * lumps[i] + lumps[math.min(COLUMNS, i + 1)]) / 4
	end
	lumps = smooth
end

-- `rough` scales the waves (the breakdown churns the surface).
local rough = 1

local function surfaceY(i, x, t, level, phase)
	local a1, k1, w1, a2, k2, w2 = WAVE[1], WAVE[2], WAVE[3], WAVE[4], WAVE[5], WAVE[6]
	local wave = a1 * math.sin(x / scale * k1 + t * w1 + phase)
		+ a2 * rough * math.sin(x / scale * k2 + t * w2 * (0.5 + rough * 0.5) + phase * 2)
	local lump = LUMPS * lumps[i] * (0.75 + 0.25 * math.sin(t * 0.5 + i * 0.9 + phase))
	return level + (wave * rough + lump) * scale
end

-- The liquid, textured: the texture drifts slowly with time.
local function fill(amv, level, t, phase, top, bottom, textured)
	local v = {}
	local du, dv = t * 0.012, -t * 0.02
	for i = 0, COLUMNS do
		local x = W * i / COLUMNS
		local y = math.min(BOTTOM, surfaceY(i, x, t, level, phase))
		if textured then
			v[#v+1] = { { x, y, 0 }, top, { x / TILE + du, y / TILE + dv } }
			v[#v+1] = { { x, BOTTOM, 0 }, bottom, { x / TILE + du, BOTTOM / TILE + dv } }
		else
			v[#v+1] = { { x, y, 0 }, top }
			v[#v+1] = { { x, BOTTOM, 0 }, bottom }
		end
	end
	amv:SetVertices(v)
	amv:SetDrawState{ Mode = "DrawMode_QuadStrip", First = 1, Num = #v }
end

-- A band that follows the surface: from it to `depth` below, `top` fading
-- to transparent.
local function band(amv, level, t, depth, top)
	local v = {}
	local clear = { top[1], top[2], top[3], 0 }
	for i = 0, COLUMNS do
		local x = W * i / COLUMNS
		local y = math.min(BOTTOM, surfaceY(i, x, t, level, 0))
		v[#v+1] = { { x, y, 0 }, top }
		v[#v+1] = { { x, math.min(BOTTOM, y + depth), 0 }, clear }
	end
	amv:SetVertices(v)
	amv:SetDrawState{ Mode = "DrawMode_QuadStrip", First = 1, Num = #v }
end

local function sheen(amv, level, t)
	local v = {}
	for i = 0, COLUMNS do
		local x = W * i / COLUMNS
		v[#v+1] = { { x, math.min(BOTTOM, surfaceY(i, x, t, level, 0)) + 1.5 * scale, 0 }, SHEEN }
	end
	amv:SetVertices(v)
	amv:SetDrawState{ Mode = "DrawMode_LineStrip", First = 1, Num = #v }
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
		local T = VOLT26.Secret.Timeline()
		self:SetUpdateFunction(function(frame)
			local music = GAMESTATE:GetCurMusicSeconds()
			local clock = GetTimeSinceStart()
			local p = progress(music)
			local breakdown = VOLT26.Secret.Within(T.Breakdown, music, 0.6)
			local since = breakdown > 0 and VOLT26.Secret.SinceLast(T.Breaks, music) or nil
			local surge = since and math.exp(-since / 0.6) or 0
			rough = 1 + 1.6 * breakdown + 1.5 * surge
			local level = BOTTOM - H * p - H * 0.05 * surge
			fill(blood:GetChild("Back"), level - 8 * scale, clock, 1.9, BACK, DEPTH, false)
			fill(blood:GetChild("Front"), level, clock, 0, SURFACE, DEPTH, true)
			band(blood:GetChild("Crust"), level, clock, CRUST_DEPTH * scale, CRUST)
			sheen(blood:GetChild("Sheen"), level, clock)
			blood:visible(p > 0)
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
		Def.ActorMultiVertex{
			Name="Front",
			InitCommand=function(self)
				self:LoadTexture(THEME:GetPathG("", "VOLT26/Secret/blood.png"))
				self:texturewrapping(true)
			end,
		},
		Def.ActorMultiVertex{ Name="Crust" },
		Def.ActorMultiVertex{
			Name="Sheen",
			InitCommand=function(self) self:SetLineWidth(2.5 * scale) end,
		},
	},
}
