-- VOLT26 result panel: one panel per joined player on the right of the song card.
-- Each player pages through their own panel with MenuLeft / MenuRight.  The
-- panels stay hidden until the evaluation sequence reports that it has finished.
--
-- Behavior (results, records) comes from VOLT26.Results; this file owns only
-- actors, layout, animation, and the paging input.

local players = GAMESTATE:GetHumanPlayers()
if #players == 0 then return Def.ActorFrame{} end

local ink = color("#140505")
local red = color("#FC0000")
local white = color("#FFFFFF")
local dim = color("#8A7F7F")

local judgmentColors = {
	ITG = {"#21CCE8", "#E29C18", "#66C955", "#B45CFF", "#C9855E", "#FF3030"},
	["FA+"] = {"#21CCE8", "#FFFFFF", "#E29C18", "#66C955", "#B45CFF", "#FF3030"},
}
local windows = {"W1", "W2", "W3", "W4", "W5", "Miss"}

local mode = VOLT26.Gameplay.GetMode()
local windowColors = judgmentColors[mode] or judgmentColors.ITG
local windowStrings = "TapNoteScore" .. (mode == "ITG" and "" or mode)

local panelWidth, panelHeight = 222, 336
local panelGap, screenMargin = 10, 12
local headerHeight = 26
local pad = 12
local slide = 40

-- Left edge of each panel: two panels sit side by side against the right edge;
-- a single panel is centered in the same area.
local function panelLeft(index)
	local right = _screen.w - screenMargin
	if #players == 1 then
		return right - panelWidth - (panelWidth + panelGap) / 2
	end
	return right - panelWidth * (3 - index) - panelGap * (2 - index)
end

local function label(text, x, y, px, align, tint, width)
	return LoadFont(VOLT26.Type.Label)..{
		InitCommand=function(self)
			self:xy(x, y):horizalign(align):diffuse(tint)
			VOLT26.Type.SetLabel(self, text, px, width)
		end,
	}
end

local function row(af, name, value, y, tint)
	af[#af+1] = label(name:upper(), pad, y, 14, "left", tint, 120)
	af[#af+1] = label(value, panelWidth - pad, y, 19, "right", white, 80)
end

local function percentText(value)
	return ("%.2f%%"):format(math.floor((value or 0) * 10000) / 100)
end

local function scorePage(player, result)
	local af = Def.ActorFrame{}
	af[#af+1] = LoadActor(THEME:GetPathG("", "_grades/" .. result.grade .. ".lua"),
		VOLT26.Results.GetStageStats(player))..{
		InitCommand=function(self) self:xy(pad + 34, 76) end,
		OnCommand=function(self) self:zoom(0.28) end,
	}
	af[#af+1] = LoadFont(VOLT26.Type.Display)..{
		InitCommand=function(self)
			self:xy(panelWidth - pad, 76):horizalign("right"):diffuse(white)
			VOLT26.Type.SetDisplay(self, percentText(result.percentDP), 40, 130)
		end,
	}
	for index, window in ipairs(windows) do
		local enabled = index == #windows or result.timingWindows[index] ~= false
		local tint = enabled and color(windowColors[index]) or dim
		row(af, THEME:GetString(windowStrings, window), tostring(result.judgments[window]),
			132 + (index - 1) * 31, tint)
	end
	return af
end

local function detailPage(player, result)
	local af = Def.ActorFrame{}
	local y = 62
	for _, category in ipairs({"Holds", "Rolls", "Mines", "Hands"}) do
		local value = ("%d / %d"):format(result.radar.actual[category], result.radar.possible[category])
		row(af, THEME:GetString("ScreenEvaluation", category), value, y, white)
		y = y + 34
	end
	row(af, THEME:GetString("ScreenEvaluation", "Max Combo"),
		tostring(VOLT26.Results.GetStageStats(player):MaxCombo()), y + 12, red)
	row(af, "EX Score", ("%.2f%%"):format(result.exPercent or 0), y + 46, red)
	return af
end

local function playPage(player)
	local af = Def.ActorFrame{}
	local steps = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)
		or GAMESTATE:GetCurrentSteps(player)
	local chart = steps
		and (ToEnumShortString(steps:GetDifficulty()):upper() .. "  /  " .. tostring(steps:GetMeter()))
		or "-"

	local record = VOLT26.Results.GetRecordStatus(player)
	local records = {}
	if record.earnedMachine and record.machineIndex >= 0 then
		records[#records+1] = THEME:GetString("ScreenEvaluation", "MachineRecord"):format(record.machineIndex + 1)
	end
	if record.earnedPersonal and record.personalIndex >= 0 then
		records[#records+1] = THEME:GetString("ScreenEvaluation", "PersonalRecord"):format(record.personalIndex + 1)
	end

	local modifiers = GAMESTATE:GetPlayerState(player):GetPlayerOptionsString("ModsLevel_Preferred")
	local bodyWidth = panelWidth - pad * 2

	af[#af+1] = label("CHART", pad, 56, 11, "left", red)
	af[#af+1] = label(chart, pad, 73, 15, "left", white, bodyWidth)
	af[#af+1] = label("RECORD", pad, 104, 11, "left", red)
	af[#af+1] = label(#records > 0 and records[1]:upper() or "-", pad, 121, 13, "left", white, bodyWidth)
	af[#af+1] = label(records[2] and records[2]:upper() or "", pad, 139, 13, "left", white, bodyWidth)
	af[#af+1] = label("MODIFIERS", pad, 170, 11, "left", red)
	af[#af+1] = LoadFont(VOLT26.Type.Label)..{
		InitCommand=function(self)
			local zoom = VOLT26.Type.LabelZoom(12)
			self:xy(pad, 181):align(0, 0):diffuse(white):zoom(zoom)
			self:wrapwidthpixels(bodyWidth / zoom):settext(modifiers)
		end,
	}
	return af
end

local pageTitles = {"SCORE", "DETAILS", "PLAY"}
local panels = {}
local revealed = false

local function buildPanel(player, index)
	local result = VOLT26.Results.GetCurrent(player)
	local pages = {scorePage(player, result), detailPage(player, result), playPage(player)}
	local state = {page = 1, actors = {}}
	panels[player] = state

	local name = PROFILEMAN:GetPlayerName(player)
	if not name or name == "" then name = ToEnumShortString(player) end

	local af = Def.ActorFrame{
		InitCommand=function(self)
			state.frame = self
			self:xy(panelLeft(index) + slide, (_screen.h - panelHeight) / 2):diffusealpha(0)
		end,
		VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
			self:finishtweening():sleep((index - 1) * 0.08):decelerate(0.25)
			self:addx(-slide):diffusealpha(1)
		end,
		ShowPageCommand=function(self)
			for number, page in ipairs(state.actors) do page:visible(number == state.page) end
			state.title:settext(pageTitles[state.page])
			state.counter:settext(("< %d/%d >"):format(state.page, #pages))
		end,
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):zoomto(panelWidth, panelHeight):diffuse(ink):diffusealpha(0.94)
			end,
		},
		Def.Quad{
			InitCommand=function(self) self:align(0, 0):zoomto(panelWidth, headerHeight):diffuse(red) end,
		},
		label(name:upper(), pad, headerHeight / 2, 13, "left", ink, 90),
		LoadFont(VOLT26.Type.Label)..{
			InitCommand=function(self)
				state.title = self
				self:xy(panelWidth / 2 + 14, headerHeight / 2):diffuse(ink)
				VOLT26.Type.SetLabel(self, "", 13, 60)
			end,
		},
		LoadFont(VOLT26.Type.Label)..{
			InitCommand=function(self)
				state.counter = self
				self:xy(panelWidth - pad, headerHeight / 2):horizalign("right"):diffuse(ink)
				VOLT26.Type.SetLabel(self, "", 12, 56)
			end,
		},
	}

	for number, page in ipairs(pages) do
		page.InitCommand = function(self) state.actors[number] = self end
		af[#af+1] = page
	end
	state.count = #pages
	return af
end

local function input(event)
	if not revealed or not event or event.type ~= "InputEventType_FirstPress" then return false end
	local direction = event.GameButton == "MenuRight" and 1 or event.GameButton == "MenuLeft" and -1
	if not direction then return false end

	-- With one player joined, either side's buttons page the only panel.
	local state = panels[event.PlayerNumber] or (#players == 1 and panels[players[1]])
	if not state then return false end

	state.page = (state.page - 1 + direction) % state.count + 1
	state.frame:playcommand("ShowPage")
	return false
end

local root = Def.ActorFrame{
	Name="VOLT26ResultPanels",
	OnCommand=function(self)
		self:playcommand("ShowPage")
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	VOLT26EvaluationSequenceFinishedMessageCommand=function(self) revealed = true end,
	OffCommand=function(self)
		revealed = false
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:RemoveInputCallback(input) end
	end,
}

for index, player in ipairs(players) do
	root[#root+1] = buildPanel(player, index)
end

return root
