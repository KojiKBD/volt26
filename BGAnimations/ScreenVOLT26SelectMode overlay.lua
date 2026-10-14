-- ScreenVOLT26SelectMode: one page for how the session is played.
--
--   REGULAR / MARATHON         (PlayMode_Regular / PlayMode_Nonstop)
--   CAROUSEL / SIMPLY LOVE     (the music selection layout for the session,
--                               VOLT26.MusicSelection.SetSessionLayout)
--   OK
--
-- The rule set is always ITG: the owner removed the ITG / FA+ choice on
-- 2026-10-14 (the artboard's "itg" and "faplus" states are no longer drawn).
--
-- Left/Right changes the focused row's choice, Start confirms it and moves the
-- focus down; Start on OK applies the choice and moves on to profile load.
-- Back (or Up) moves the focus up, and Back on the first row leaves the screen.
-- Each play-mode choice is a pre-rendered state from the artboard
-- (Graphics/VOLT26/ModeSelect, rendered from charter_card.ai "MODES" and its
-- state column), placed so its white plate sits where the artboard's plate
-- is.  The layout row has no artwork yet: its states are drawn as plain white
-- plates with the layout's title and subtitle (placeholder() below) until the
-- owner's graphics arrive.  Coordinates are design pixels on the 1920x1080
-- artboard.

local scale = SCREEN_HEIGHT / 1080
local originX = (SCREEN_WIDTH - 1920 * scale) / 2

local function art(name) return THEME:GetPathG("", "VOLT26/ModeSelect/" .. name .. ".png") end

-- Row centres are the artboard plates' centres; each state is drawn from its
-- top-left corner at `x, y` with zoom `k` (its plate is larger in the state
-- column than on the artboard).  The layout row takes the place of the former
-- rules row (ITG / FA+, removed on 2026-10-14).
local layouts = VOLT26.MusicSelection.Layouts
local layoutStates = {}
local layoutChoice = 1
for index, layout in ipairs(layouts) do
	layoutStates[index] = { title = layout.Title, subtitle = layout.Subtitle, value = layout.Value }
	if layout.Value == VOLT26.MusicSelection.GetLayout() then layoutChoice = index end
end

local rows = {
	{
		name = "PlayMode", cx = 960.0, cy = 459.7,
		states = {
			{ file = "regular",  x = 595.0, y = 362.5, k = 0.7326 },
			{ file = "marathon", x = 601.1, y = 362.1, k = 0.7326 },
		},
	},
	{ name = "Layout", cx = 960.0, cy = 638.5, states = layoutStates },
}
local ok = { cx = 960.0, cy = 1006.4, x = 743.5, y = 877.9 }

-- The placeholder plate of a layout state, about the size of the play-mode
-- plates.
local PLATE = { W = 660, H = 150 }

local choice = { 1, layoutChoice }   -- Regular; the layout the session has
local focus = 1               -- 1..#rows are rows, #rows + 1 is OK
local finished = false
local af

local function refresh()
	for index, row in ipairs(rows) do
		local frame = af:GetChild(row.name)
		for s = 1, #row.states do
			frame:GetChild("State" .. s):visible(choice[index] == s)
		end
		frame:playcommand(focus == index and "Focus" or "Blur")
	end
	local okFrame = af:GetChild("OK")
	okFrame:GetChild("Idle"):visible(focus ~= #rows + 1)
	okFrame:GetChild("Focus"):visible(focus == #rows + 1)
	okFrame:playcommand(focus == #rows + 1 and "Focus" or "Blur")
end

local function finish()
	if finished then return end
	finished = true
	VOLT26.ThemePrefs.ApplyGameMode("ITG")
	THEME:ReloadMetrics()
	GAMESTATE:SetCurrentPlayMode(choice[1] == 1 and "PlayMode_Regular" or "PlayMode_Nonstop")
	VOLT26.MusicSelection.SetSessionLayout(layoutStates[choice[2]].value)
	af:GetChild("Start"):play()
	local screen = SCREENMAN:GetTopScreen()
	screen:SetNextScreenName("ScreenProfileLoad")
	screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local input
input = function(event)
	if finished or not event or not event.PlayerNumber then return false end
	if event.type ~= "InputEventType_FirstPress" then return false end
	local button = event.GameButton
	if button == "MenuLeft" or button == "MenuRight" then
		if focus <= #rows then
			local count = #rows[focus].states
			local step = button == "MenuRight" and 1 or -1
			choice[focus] = (choice[focus] - 1 + step) % count + 1
			af:GetChild("Change"):play()
			refresh()
		end
	elseif button == "Start" then
		if focus <= #rows then
			focus = focus + 1
			af:GetChild("Change"):play()
			refresh()
		else
			finish()
		end
	elseif button == "MenuDown" then
		if focus <= #rows then focus = focus + 1; af:GetChild("Change"):play(); refresh() end
	elseif button == "MenuUp" or button == "Back" then
		if focus > 1 then
			focus = focus - 1
			af:GetChild("Change"):play()
			refresh()
		elseif button == "Back" then
			finished = true
			local screen = SCREENMAN:GetTopScreen()
			screen:RemoveInputCallback(input)
			screen:Cancel()
		end
	end
	return false
end

-- The focused element breathes; the others rest.
local function focusable(frame)
	frame.FocusCommand = function(self)
		self:stoptweening():decelerate(0.12):zoom(1.06):diffusealpha(1)
			:effectclock("timer"):pulse():effectmagnitude(1, 1.025, 1):effectperiod(1.2)
	end
	frame.BlurCommand = function(self)
		self:stoptweening():stopeffect():decelerate(0.12):zoom(1):diffusealpha(0.85)
	end
	return frame
end

local t = Def.ActorFrame{
	InitCommand=function(self)
		af = self
		self:xy(originX, 0):zoom(scale)
	end,
	OnCommand=function(self)
		refresh()
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		if VOLT26.MenuTimer.IsEnabled() then self:queuecommand("Listen") end
	end,
	ListenCommand=function(self)
		local timer = SCREENMAN:GetTopScreen():GetChild("Timer")
		if timer and timer:GetSeconds() <= 0 then
			finish()
		elseif not finished then
			self:sleep(0.25):queuecommand("Listen")
		end
	end,
	OffCommand=function(self)
		SCREENMAN:GetTopScreen():RemoveInputCallback(input)
	end,
}

for _, row in ipairs(rows) do
	local frame = focusable(Def.ActorFrame{
		Name=row.name,
		InitCommand=function(self) self:xy(row.cx, row.cy) end,
	})
	for s, state in ipairs(row.states) do
		if state.file then
			frame[#frame+1] = Def.Sprite{
				Name="State" .. s,
				Texture=art(state.file),
				InitCommand=function(self)
					self:align(0, 0):xy(state.x - row.cx, state.y - row.cy):zoom(state.k)
				end,
			}
		else
			-- Placeholder until the artwork: a white plate, the title in
			-- black and the subtitle under it, centred on the row.
			frame[#frame+1] = Def.ActorFrame{
				Name="State" .. s,
				Def.Quad{ InitCommand=function(self)
					self:zoomto(PLATE.W + 12, PLATE.H + 12):diffuse(Color.Black)
				end },
				Def.Quad{ InitCommand=function(self)
					self:zoomto(PLATE.W, PLATE.H):diffuse(Color.White)
				end },
				LoadFont("Common Bold")..{
					Text=state.title:upper(),
					InitCommand=function(self)
						self:y(-22):zoom(1.5):maxwidth((PLATE.W - 40) / 1.5):diffuse(Color.Black)
					end,
				},
				LoadFont("Common Normal")..{
					Text=state.subtitle,
					InitCommand=function(self)
						self:y(38):zoom(0.9):maxwidth((PLATE.W - 40) / 0.9):diffuse(color("#444444"))
					end,
				},
			}
		end
	end
	t[#t+1] = frame
end

local okFrame = focusable(Def.ActorFrame{
	Name="OK",
	InitCommand=function(self) self:xy(ok.cx, ok.cy) end,
})
for _, part in ipairs({ {"Idle", "ok"}, {"Focus", "ok_focus"} }) do
	okFrame[#okFrame+1] = Def.Sprite{
		Name=part[1],
		Texture=art(part[2]),
		InitCommand=function(self) self:align(0, 0):xy(ok.x - ok.cx, ok.y - ok.cy) end,
	}
end
t[#t+1] = okFrame

t[#t+1] = LoadActor(THEME:GetPathS("ScreenSelectMaster", "change"))..{ Name="Change", IsAction=true, SupportPan=false }
t[#t+1] = LoadActor(THEME:GetPathS("common", "start"))..{ Name="Start", IsAction=true, SupportPan=false }

return t
