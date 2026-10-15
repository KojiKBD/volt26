-- The hidden song's effects over and on the arrows (VOLT26.Secret): a light
-- modchart that turns hard in the breakdown, and the screen effects that
-- must draw over the notefield.  The moments come from VOLT26.Secret.Timeline
-- (taken from the lyrics), the rhythm from the song's beat (185 BPM).
--
--   first verse   the notes wobble (Drunk, Tipsy), as if drugged
--   red lines     "Red crescent moons..." and every "Why am I this way?": the
--                 arrows turn blood red for the line (a modulating red
--                 filter over the field: the notefield ignores the player
--                 frame's diffuse)
--   choruses      zoom punches and a small shake on every beat
--   breakdown     the field sways and tilts, Drunk/Tipsy/Beat rise (kept
--                 readable: the first version was unplayable); each
--                 "break down" hits it (tilt, zoom, shake) and glitch bars
--                 tear across the screen; the second half is a little harder
--   end           the arrows dim, one white flash on the last line, black
-- A vignette breathes on the beat throughout.  No strobes: the only flash is
-- single.  Any other song gets an empty actor.
if not VOLT26.Secret.IsHiddenSong(GAMESTATE:GetCurrentSong()) or GAMESTATE:IsCourseMode() then
	return Def.Actor{}
end

local S = VOLT26.Secret
local scale = SCREEN_HEIGHT / 1080
local W, H = SCREEN_WIDTH, SCREEN_HEIGHT
local BARS = 6

local function decay(since, rate)
	if not since or since < 0 then return 0 end
	return math.exp(-since / rate)
end

-- Song-level modifiers, set only when they change (they ease in by themselves
-- at the given speed).
local current = {}
local function setMods(player, mods)
	local po = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Song")
	current[player] = current[player] or {}
	for name, value in pairs(mods) do
		if current[player][name] ~= value then
			current[player][name] = value
			pcall(function() po[name](po, value, 1.5) end)
		end
	end
end

local function vignetteQuad(name, w, h, x, y, edge)
	return Def.Quad{
		Name = name,
		InitCommand = function(self)
			self:zoomto(w, h):xy(x, y):diffuse(Color.Black)
			if edge == "left" then self:diffuserightedge(color("0,0,0,0"))
			elseif edge == "right" then self:diffuseleftedge(color("0,0,0,0"))
			elseif edge == "top" then self:diffusebottomedge(color("0,0,0,0"))
			else self:diffusetopedge(color("0,0,0,0")) end
		end,
	}
end

local af = Def.ActorFrame{
	Name = "SecretFX",
	OnCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		local T = S.Timeline()
		local players = {}
		for _, player in ipairs(GAMESTATE:GetHumanPlayers()) do
			local field = screen and screen:GetChild("Player" .. ToEnumShortString(player))
			if field then players[#players+1] = { pn = player, af = field } end
		end
		local vignette = self:GetChild("Vignette")
		local tint = self:GetChild("Tint")
		local bars = self:GetChild("Bars")
		local flash, black = self:GetChild("Flash"), self:GetChild("Black")
		local lastBeat, flashed, blacked = -1, false, false
		local barUntil = 0

		self:SetUpdateFunction(function(frame)
			local t = GAMESTATE:GetCurMusicSeconds()
			local beat = GAMESTATE:GetSongBeat()
			local frac = beat % 1
			local onBeat = math.floor(beat) ~= lastBeat
			if onBeat then lastBeat = math.floor(beat) end
			local pulse = math.exp(-frac * 4)            -- 1 on the beat, falling

			local drunk = S.Within(T.Drunk, t, 1.2)
			local moons = 0
			for _, range in ipairs(T.Red) do moons = math.max(moons, S.Within(range, t, 0.4)) end
			local chorus = 0
			for _, range in ipairs(T.Chorus) do chorus = math.max(chorus, S.Within(range, t, 0.3)) end
			local breakdown = S.Within(T.Breakdown, t, 0.6)
			local hard = (T.Whoa and t >= T.Whoa) and breakdown or 0
			local hit = decay(breakdown > 0 and S.SinceLast(T.Breaks, t) or nil, 0.35)
			local dim = T.Darken and math.max(0, math.min(1, (t - T.Darken) / 6)) or 0

			-- The field --------------------------------------------------
			local zoom = 1 + 0.05 * pulse * chorus + 0.025 * pulse * breakdown + 0.07 * hit
			local sway = math.sin(beat * math.pi / 2) * (3 * breakdown + 2.5 * hard)
			local side = (math.floor(beat) % 2 == 0) and 1 or -1
			local rot = sway + 7 * hit * side
			local shakeAmp = (3 * pulse * chorus + 6 * hit + 1 * hard) * scale
			for i, p in ipairs(players) do
				if not p.base then p.base = { x = p.af:GetX(), y = p.af:GetY(), zoom = p.af:GetZoom() } end
				local dx = (math.random() * 2 - 1) * shakeAmp
				local dy = (math.random() * 2 - 1) * shakeAmp * 0.6
				p.af:x(p.base.x + dx):y(p.base.y + dy):zoom(p.base.zoom * zoom):rotationz(rot * (i == 2 and -1 or 1))
				setMods(p.pn, {
					Drunk = (drunk > 0 and 0.5 or 0) + (breakdown > 0 and 0.35 or 0) + (hard > 0 and 0.15 or 0),
					Tipsy = (drunk > 0 and 0.3 or 0) + (breakdown > 0 and 0.25 or 0) + (hard > 0 and 0.1 or 0),
					Beat = (breakdown > 0 and 0.3 or 0) + (hard > 0 and 0.25 or 0),
				})
			end

			-- Blood-red arrows on the moons line, and the dimming at the end:
			-- a filter that multiplies what is under it (the field and the
			-- blood), white when idle.
			local light = 1 - 0.45 * dim
			tint:visible(moons > 0 or dim > 0)
			tint:diffuse(light * (1 - 0.25 * moons), light * (1 - 0.95 * moons), light * (1 - 0.93 * moons), 1)

			-- The vignette breathes on the beat -------------------------------
			vignette:diffusealpha(0.55 + 0.25 * pulse * math.max(chorus, breakdown, 0.4) + 0.3 * dim)

			-- Glitch bars in the breakdown ---------------------------------------
			local now = GetTimeSinceStart()
			if breakdown > 0 and ((onBeat and math.random() < 0.45 + 0.3 * hard) or hit > 0.97) then
				barUntil = now + 0.07 + 0.05 * hit
				for b = 1, BARS do
					local bar = bars:GetChild("Bar" .. b)
					local show = math.random() < 0.6
					bar:visible(show)
					if show then
						bar:y(math.random() * H):zoomto(W, (3 + math.random() * 18) * scale)
							:x(W / 2 + (math.random() * 2 - 1) * 40 * scale)
							:diffuse(math.random() < 0.5 and color("#ff00284d") or color("#00e6ff4d"))
					end
				end
			end
			bars:visible(now < barUntil)

			-- The end ------------------------------------------------------------
			if T.Flash and t >= T.Flash and not flashed then
				flashed = true
				flash:stoptweening():diffusealpha(0.85):linear(0.4):diffusealpha(0)
			end
			if T.Black and t >= T.Black and not blacked then
				blacked = true
				black:stoptweening():linear(0.6):diffusealpha(1)
			end
		end)
	end,
	OffCommand = function(self) self:SetUpdateFunction(nil) end,
}

-- The filter for the red arrows and the dimming: multiplies what is under it.
af[#af+1] = Def.Quad{
	Name = "Tint",
	InitCommand = function(self) self:FullScreen():blend("BlendMode_Modulate"):visible(false) end,
}

-- A frame of black that darkens towards the edges.
local vignette = Def.ActorFrame{ Name = "Vignette" }
local VW, VH = W * 0.22, H * 0.3
vignette[#vignette+1] = vignetteQuad("Left", VW, H, VW / 2, H / 2, "left")
vignette[#vignette+1] = vignetteQuad("Right", VW, H, W - VW / 2, H / 2, "right")
vignette[#vignette+1] = vignetteQuad("Top", W, VH, W / 2, VH / 2, "top")
vignette[#vignette+1] = vignetteQuad("Bottom", W, VH, W / 2, H - VH / 2, "bottom")
af[#af+1] = vignette

local bars = Def.ActorFrame{ Name = "Bars", InitCommand = function(self) self:visible(false) end }
for b = 1, BARS do
	bars[#bars+1] = Def.Quad{ Name = "Bar" .. b, InitCommand = function(self) self:visible(false) end }
end
af[#af+1] = bars

-- The lyrics, over the arrows and the vignette, under the flash and the black.
af[#af+1] = LoadActor(THEME:GetPathB("ScreenGameplay", "overlay/SecretLyrics.lua"))

af[#af+1] = Def.Quad{
	Name = "Flash",
	InitCommand = function(self) self:FullScreen():diffuse(Color.White):diffusealpha(0) end,
}
af[#af+1] = Def.Quad{
	Name = "Black",
	InitCommand = function(self) self:FullScreen():diffuse(Color.Black):diffusealpha(0) end,
}

return af
