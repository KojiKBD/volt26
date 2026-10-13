-- VOLT26.Glitch: short, rare signal-corruption bursts over the menu screens.
--
-- The vocabulary comes from the volt26.it overlay: horizontal tears tinted red or
-- cyan, solid black/white/red blocks, a grain flash and a one-beat inversion of
-- the whole picture. Everything here is a handful of pooled Quads plus one tiled
-- 128px texture; nothing is loaded, created or destroyed while a burst plays.
--
-- Rules this module enforces by construction:
--   * Screens are opt-in. A screen without an entry in `profiles` never shows a
--     burst, and gameplay-like screens are refused even if someone adds one.
--   * The layer lives in ScreenSystemLayer and runs from an update function. It
--     queues no tweens, so it cannot lengthen ScreenSelectMaster's
--     m_fLockInputSecs (= GetTweenTimeLeft() at BeginScreen) on any screen.
--   * The GlitchIntensity preference can turn it off.

VOLT26.Glitch = VOLT26.Glitch or {}
local Glitch = VOLT26.Glitch

local red = color("#FF0000")
local cyan = color("#00FFFF")

-- Per-preference tuning. `pace` scales the time between bursts.
local levels = {
	Light = {
		slices = 2, blocks = 3, steps = {2, 4}, pace = 1.0,
		noiseChance = 0.35, noiseAlpha = 0.05,
		invertSliceChance = 0.10, flashChance = 0.25, flashCooldown = 60,
	},
	Full = {
		slices = 3, blocks = 6, steps = {3, 7}, pace = 0.55,
		noiseChance = 0.60, noiseAlpha = 0.09,
		invertSliceChance = 0.22, flashChance = 0.40, flashCooldown = 30,
	},
}

-- Seconds between bursts (before `pace`), an optional burst shortly after the
-- screen appears, whether the full-picture inversion may fire, and a gate.
local title = {
	interval = {7, 16}, flash = true,
	gate = function() return not _G.Volt26TitleIntroActive end,
}
local evaluation = { entry = 0.35 }
local profiles = {
	ScreenTitleMenu = title,
	ScreenTitleJoin = title,
	ScreenSelectMusic = { interval = {22, 48}, flash = false },
	ScreenSelectCourse = { interval = {22, 48}, flash = false },
	ScreenSelectCourseNonstop = { interval = {22, 48}, flash = false },
	ScreenEvaluationStage = evaluation,
	ScreenEvaluationNonstop = evaluation,
	ScreenEvaluationSummary = evaluation,
}

-- Never, whatever `profiles` says: nothing may cover notes while a chart plays.
local never = {
	ScreenGameplay = true, ScreenPractice = true, ScreenDemonstration = true,
	ScreenGameplaySyncMachine = true, ScreenEdit = true,
}

local stepSeconds = {0.045, 0.090}
local flashSeconds = 0.030 -- two frames at 60 Hz

local function rnd(low, high)
	return low + (high - low) * math.random()
end

function Glitch.GetLevel()
	return levels[VOLT26.ThemePrefs.Get("GlitchIntensity")]
end

function Glitch.IsAllowedOn(screenName)
	if not screenName or never[screenName] then return false end
	if Branch and Branch.GameplayScreen and screenName == Branch.GameplayScreen() then
		return false
	end
	return profiles[screenName] ~= nil
end

-- Ask for one burst right now, for a screen that wants to land it on a beat.
-- It is still refused where bursts are not allowed.
function Glitch.Kick(steps)
	MESSAGEMAN:Broadcast("VOLT26_GlitchKick", {steps=steps})
end

-- BlendMode_InvertDest is src - dst under OpenGL, so a white Quad is a true
-- negative of whatever is behind it. Direct3D has no such path and would paint
-- the Quad itself, so the inverting pieces are simply left out there.
local function CanInvert()
	local renderers = PREFSMAN:GetPreference("VideoRenderers") or ""
	return renderers:sub(1, 3):lower() ~= "d3d"
end

function Glitch.CreateLayer()
	local maxSlices, maxBlocks = levels.Full.slices, levels.Full.blocks
	local canInvert = CanInvert()

	local level, profile
	local nextIn        -- seconds until the next burst, nil when none is due
	local burst         -- {stepsLeft, stepTime, noise, flashTime}
	local sinceFlash = math.huge
	local paused, broken = false, false
	local slices, blocks, noise, flash = {}, {}, nil, nil

	local function HideAll(frame)
		for _, slice in ipairs(slices) do slice:visible(false) end
		for _, block in ipairs(blocks) do block:visible(false) end
		if noise then noise:visible(false) end
		if flash then flash:visible(false) end
		frame:xy(0, 0)
	end

	local function EndBurst(frame)
		burst = nil
		HideAll(frame)
		if profile and profile.interval then
			nextIn = rnd(profile.interval[1], profile.interval[2]) * level.pace
		else
			nextIn = nil
		end
	end

	local function RollStep(frame)
		burst.stepTime = rnd(stepSeconds[1], stepSeconds[2])

		local sliceCount = math.random(1, level.slices)
		for i, slice in ipairs(slices) do
			if i <= sliceCount then
				local band = slice:GetChild("Band")
				local height = rnd(4, 21)
				band:zoomto(_screen.w, height)
				local roll = math.random()
				if canInvert and roll < level.invertSliceChance then
					band:blend("BlendMode_InvertDest"):diffuse(1, 1, 1, 1)
				elseif roll < 0.55 then
					band:blend("BlendMode_Normal"):diffuse(red):diffusealpha(0.22)
				elseif roll < 0.85 then
					band:blend("BlendMode_Normal"):diffuse(cyan):diffusealpha(0.14)
				else
					band:blend("BlendMode_Normal"):diffuse(1, 1, 1, 0.06)
				end
				-- The sideways shove is what reads as a tear: one end of the band
				-- leaves the picture and uncovers the untouched image.
				local shove = rnd(2, 12) * (math.random() < 0.5 and -1 or 1)
				slice:xy(shove, rnd(0, _screen.h - height)):visible(true)
			else
				slice:visible(false)
			end
		end

		local blockCount = math.random(0, level.blocks)
		for i, block in ipairs(blocks) do
			if i <= blockCount then
				local roll = math.random()
				if roll < 0.55 then block:diffuse(0, 0, 0, 1)
				elseif roll < 0.75 then block:diffuse(1, 1, 1, 1)
				else block:diffuse(red) end
				block:zoomto(rnd(4, 38), rnd(4, 36))
					:xy(rnd(0, _screen.w), rnd(0, _screen.h)):visible(true)
			else
				block:visible(false)
			end
		end

		if burst.noise and noise then
			local u, v = math.random(), math.random()
			noise:customtexturerect(u, v, u + _screen.w / 192, v + _screen.h / 192)
				:diffusealpha(level.noiseAlpha):visible(true)
		end

		frame:xy(rnd(-2, 2), rnd(-1, 1))
	end

	local function StartBurst(frame, steps)
		burst = {
			stepsLeft = steps or math.random(level.steps[1], level.steps[2]),
			noise = math.random() < level.noiseChance,
			flashTime = 0,
		}
		if flash and profile.flash and sinceFlash >= level.flashCooldown
		and math.random() < level.flashChance then
			burst.flashTime = flashSeconds
			sinceFlash = 0
			flash:visible(true)
		end
		RollStep(frame)
	end

	local function Update(frame, delta)
		delta = math.min(delta or 0, 0.1)
		sinceFlash = sinceFlash + delta
		if not profile or paused then return end

		if burst then
			if burst.flashTime > 0 then
				burst.flashTime = burst.flashTime - delta
				if burst.flashTime <= 0 then flash:visible(false) end
			end
			burst.stepTime = burst.stepTime - delta
			if burst.stepTime <= 0 then
				burst.stepsLeft = burst.stepsLeft - 1
				if burst.stepsLeft <= 0 then EndBurst(frame) else RollStep(frame) end
			end
		elseif nextIn then
			nextIn = nextIn - delta
			if nextIn <= 0 then
				if profile.gate and not profile.gate() then
					nextIn = 1
				else
					StartBurst(frame)
				end
			end
		end
	end

	local layer = Def.ActorFrame{
		Name="VOLT26_GlitchLayer",
		InitCommand=function(self)
			self:visible(false)
			-- This actor is alive on every screen for the whole session, so an
			-- error here must not repeat sixty times a second.
			self:SetUpdateFunction(function(frame, delta)
				if broken then return end
				local ok, message = pcall(Update, frame, delta)
				if not ok then
					broken = true
					pcall(HideAll, frame)
					frame:visible(false)
					lua.ReportScriptError("VOLT26.Glitch disabled: "..tostring(message))
				end
			end)
		end,
		ScreenChangedMessageCommand=function(self)
			if broken then return end
			if #slices == 0 then
				for i = 1, maxSlices do slices[i] = self:GetChild("Slice"..i) end
				for i = 1, maxBlocks do blocks[i] = self:GetChild("Block"..i) end
				noise, flash = self:GetChild("Noise"), self:GetChild("Flash")
			end
			burst, nextIn, paused = nil, nil, false
			HideAll(self)
			local screen = SCREENMAN:GetTopScreen()
			local name = screen and screen:GetName()
			level = Glitch.GetLevel()
			profile = level and Glitch.IsAllowedOn(name) and profiles[name] or nil
			self:visible(profile ~= nil)
			if not profile then return end
			if profile.entry then
				nextIn = profile.entry
			elseif profile.interval then
				nextIn = rnd(profile.interval[1], profile.interval[2]) * level.pace
			end
		end,
		VOLT26_GlitchKickMessageCommand=function(self, params)
			if broken or not profile or paused or burst then return end
			StartBurst(self, params and params.steps)
		end,
		-- The idle video on the title screen is its own picture; leave it alone.
		VOLT26_ShowAFKMessageCommand=function(self)
			paused = true
			if burst then EndBurst(self) end
		end,
		VOLT26_HideAFKMessageCommand=function(self)
			paused = false
		end,
	}

	layer[#layer+1] = Def.Sprite{
		Name="Noise",
		Texture=THEME:GetPathG("", "VOLT26/glitch_noise.png"),
		InitCommand=function(self)
			self:halign(0):valign(0):zoomto(_screen.w, _screen.h)
			self:blend("BlendMode_Add")
			self:SetTextureFiltering(false)
			self:visible(false)
		end,
	}

	for i = 1, maxBlocks do
		layer[#layer+1] = Def.Quad{
			Name="Block"..i,
			InitCommand=function(self) self:halign(0):valign(0):visible(false) end,
		}
	end

	for i = 1, maxSlices do
		layer[#layer+1] = Def.ActorFrame{
			Name="Slice"..i,
			InitCommand=function(self) self:visible(false) end,
			Def.Quad{
				Name="Band",
				InitCommand=function(self) self:halign(0):valign(0) end,
			},
			Def.Quad{
				Name="Edge",
				InitCommand=function(self)
					self:halign(0):valign(0):zoomto(_screen.w, 1)
						:diffuse(1, 1, 1, 0.35)
				end,
			},
		}
	end

	if canInvert then
		layer[#layer+1] = Def.Quad{
			Name="Flash",
			InitCommand=function(self)
				self:halign(0):valign(0):zoomto(_screen.w, _screen.h)
					:blend("BlendMode_InvertDest"):diffuse(1, 1, 1, 1):visible(false)
			end,
		}
	end

	return layer
end
