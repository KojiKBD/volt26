-- ScreenSelectPlayMode / ScreenSelectPlayMode2.
--
-- ScreenSelectMaster owns the choices and the cursor: the rows in the left
-- column are its IconChoice actors (Graphics/ScreenSelectPlayMode Icon.lua),
-- placed by metrics.ini.  This file draws everything around them -- the title
-- block, the panel that describes whatever the cursor is on, and the key hints
-- -- and keeps the panel in step with the engine's selection.
--
-- Both screens share this file.  ScreenSelectPlayMode2 asks how a set is played
-- (Regular or Marathon) and is the one players actually reach.
-- ScreenSelectPlayMode asks which rule set is in force; VOLT26 exposes only
-- ITG, so Navigation skips it, but the screen still exists and still works.

local Chrome = LoadActor(THEME:GetPathB("", "_volt26 select chrome"))

local TopScreen = nil
local ScreenName = "ScreenSelectPlayMode"
local choices = {}

local cursor = { index = 0 }

local panel = { x = 440, y = Chrome.Metrics.BodyY, w = 394, h = 186 }
local inner = { x = 16, w = panel.w - 32 }

-- ----------------------------------------------------------------------------
-- What the panel says about each choice.
--
-- Everything here is read from live state rather than written into the layout,
-- so the panel describes the session the player is actually about to start.

local function String(key, fallback)
	if THEME:HasString("ScreenSelectPlayMode", key) then
		return THEME:GetString("ScreenSelectPlayMode", key)
	end
	return fallback or ""
end

local function PlayerCount()
	local joined = math.max(#GAMESTATE:GetHumanPlayers(), 1)
	return joined .. "P"
end

-- Stages are a preference the operator sets and a count the engine decrements,
-- and either can be absent depending on coin mode, so both are read defensively.
local function Stages()
	local total = 3
	local ok, preference = pcall(function() return PREFSMAN:GetPreference("SongsPerPlay") end)
	if ok and tonumber(preference) then total = tonumber(preference) end

	local left = total
	local okLeft, remaining = pcall(function()
		return GAMESTATE:GetSmallestNumStagesLeftForAnyHumanPlayer()
	end)
	if okLeft and tonumber(remaining) and tonumber(remaining) > 0 then left = tonumber(remaining) end

	return left, total
end

local function Describe(choice)
	local eventMode = PREFSMAN:GetPreference("EventMode")

	if choice == "Marathon" then
		return {
			blurb = String("MarathonBlurb", "A fixed course played end to end. No breaks, one life bar, one score at the finish."),
			meter = { caption = String("MeterCourse", "Course"), value = String("OneRun", "One run"), fraction = 1 },
			tiles = {
				{ value = String("FixedCourse", "Course"), caption = String("CaptionSet", "Fixed set") },
				{ value = String("OneBar", "One bar"),     caption = String("CaptionLife", "Life") },
				{ value = String("Locked", "Locked"),      caption = String("CaptionDifficulty", "Difficulty") },
				{ value = PlayerCount(),                   caption = String("CaptionPlayers", "Players") },
			},
		}
	end

	if choice == "Casual" then
		return {
			blurb = String("CasualBlurb", "Relaxed scoring with no failing. Play for the music, not the percentage."),
			meter = { caption = String("MeterJudgment", "Judgment"), value = String("Forgiving", "Forgiving"), fraction = 0.35 },
			tiles = {
				{ value = String("Wide", "Wide"),       caption = String("CaptionTiming", "Timing") },
				{ value = String("NoFail", "No fail"),  caption = String("CaptionLife", "Life") },
				{ value = String("Percent", "Percent"), caption = String("CaptionGrading", "Grading") },
				{ value = PlayerCount(),                caption = String("CaptionPlayers", "Players") },
			},
		}
	end

	if choice == "ITG" then
		return {
			blurb = String("ITGBlurb", "Standard ITG rules. Tight timing windows, a real life bar, and a score that means something."),
			meter = { caption = String("MeterJudgment", "Judgment"), value = String("Tight", "Tight"), fraction = 0.88 },
			tiles = {
				{ value = String("ITGWindows", "ITG"),   caption = String("CaptionTiming", "Timing") },
				{ value = String("NormalBar", "Normal"), caption = String("CaptionLife", "Life") },
				{ value = String("ExScore", "EX"),       caption = String("CaptionGrading", "Grading") },
				{ value = PlayerCount(),                 caption = String("CaptionPlayers", "Players") },
			},
		}
	end

	-- Regular, and anything an operator adds that this file has not met.
	local left, total = Stages()
	return {
		blurb = String("RegularBlurb", "Pick a song, play it, pick the next one. A short break between each."),
		meter = {
			caption = String("MeterStages", "Stages left"),
			value = eventMode and String("EventMode", "Event") or (left .. " / " .. total),
			fraction = eventMode and 1 or (total > 0 and left/total or 1),
		},
		tiles = {
			{ value = eventMode and String("NoLimit", "No limit") or (total .. " " .. String("Songs", "songs")),
			  caption = String("CaptionSet", "Per set") },
			{ value = String("NormalBar", "Normal"), caption = String("CaptionLife", "Life") },
			{ value = String("Free", "Free"),        caption = String("CaptionDifficulty", "Difficulty") },
			{ value = PlayerCount(),                 caption = String("CaptionPlayers", "Players") },
		},
	}
end

-- ----------------------------------------------------------------------------
-- Keeping the panel in step with the engine's cursor.

local Update = function(af, delta)
	if not TopScreen then return end

	local index = TopScreen:GetSelectionIndex( GAMESTATE:GetMasterPlayerNumber() )
	if index ~= cursor.index then
		cursor.index = index
		af:playcommand("SetChoice", { Choice = choices[cursor.index+1] })
	end
end

-- ScreenSelectPlayMode is the screen that decides the rule set, so a choice
-- made there has to be applied before the screen transitions.  VOLT26 exposes
-- ITG only, so in practice this runs for a single choice.
local InputHandler = function(event)
	if not event or not event.PlayerNumber or not event.button then return false end
	if event.type ~= "InputEventType_FirstPress" then return false end
	if event.GameButton ~= "Start" then return false end
	if ScreenName ~= "ScreenSelectPlayMode" then return false end

	-- ApplyGameMode() is the CORE entry point; the old SetGameModePreferences()
	-- global this screen used to call no longer exists.
	VOLT26.State.Global.GameMode = choices[cursor.index+1]
	VOLT26.ThemePrefs.ApplyGameMode()
	THEME:ReloadMetrics()
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	return false
end

-- ----------------------------------------------------------------------------

local t = Def.ActorFrame{
	InitCommand=function(self) self:SetUpdateFunction( Update ) end,
	OnCommand=function(self)
		TopScreen = SCREENMAN:GetTopScreen()
		ScreenName = TopScreen:GetName()

		for choice in THEME:GetMetric(ScreenName, "ChoiceNames"):gmatch('([^,]+)') do
			choices[#choices+1] = choice
		end

		TopScreen:AddInputCallback(InputHandler)

		cursor.index = TopScreen:GetSelectionIndex( GAMESTATE:GetMasterPlayerNumber() )
		self:playcommand("SetChoice", { Choice = choices[cursor.index+1] })
	end,
}

t[#t+1] = Chrome.TitleBlock{
	title = THEME:GetString("ScreenSelectPlayMode", "TitleMode"),
	tabs = { "Profile", "Mode" },
	active = "Mode",
}

t[#t+1] = Chrome.SectionLabel( THEME:GetString("ScreenSelectPlayMode", "SectionHowYouPlay") )

-- ----------------------------------------------------------------------------
-- The panel.  Built once, repopulated on every cursor move.

local detail = Chrome.Box{ name="Detail", x=panel.x, y=panel.y, w=panel.w, h=panel.h }

detail.SetChoiceCommand=function(self, params)
	local description = Describe(params.Choice)

	local blurb = self:GetChild("Blurb")
	VOLT26.Type.SetDisplay(blurb, description.blurb, 13)
	blurb:_wrapwidthpixels(inner.w / blurb:GetZoom())

	local meter = self:GetChild("Meter")
	VOLT26.Type.SetLabel(meter:GetChild("Caption"), description.meter.caption:upper(), 9)
	VOLT26.Type.SetDisplay(meter:GetChild("Value"), description.meter.value, 18)
	meter:GetChild("Fill"):stoptweening():linear(0.12)
		:zoomtowidth(inner.w * clamp(description.meter.fraction, 0, 1))

	for i, tile in ipairs(description.tiles) do
		Chrome.SetTile(self:GetChild("Tile"..i), tile.value, tile.caption)
	end
end

detail[#detail+1] = Chrome.Display{
	name="Blurb", text="", px=13,
	x=inner.x, y=16, wrap=inner.w, vertspacing=2,
}

detail[#detail+1] = Chrome.Meter{
	name="Meter", x=inner.x, y=88, w=inner.w, fraction=0,
	caption="", value="",
}

local tile = { w = (inner.w - 18) / 4, h = 40, y = 128 }
for i = 1, 4 do
	detail[#detail+1] = Chrome.Tile{
		name="Tile"..i,
		x = inner.x + (tile.w + 6) * (i-1),
		y = tile.y, w = tile.w, h = tile.h,
	}
end

t[#t+1] = detail

-- ----------------------------------------------------------------------------

t[#t+1] = Chrome.Hints{
	button = THEME:GetString("ScreenSelectPlayMode", "HintButton"),
	action = THEME:GetString("ScreenSelectPlayMode", "HintConfirm"),
	center = PREFSMAN:GetPreference("EventMode")
		and THEME:GetString("ScreenSelectPlayMode", "EventMode")
		or VOLT26.Gameplay.GetMode(),
}

return t
