-- First launch only ([Common] InitialScreen, VOLT26.MusicSelection.GetInitialScreen):
-- the players choose how songs are picked, the Carousel layout (pack carousel
-- plus song wheel) or the Simply Love layout (one wheel of packs and songs).
-- The choice is recorded by VOLT26.MusicSelection.ChooseLayout and can be
-- changed later in VOLT26 Options (theme preference MusicSelectionLayout).
-- The screen runs before the warm-up, so it draws only plain text and quads.
local layouts = VOLT26.MusicSelection.Layouts
local selected = 1
for index, layout in ipairs(layouts) do
	if layout.Value == VOLT26.MusicSelection.GetLayout() then selected = index end
end

local RED = color("#ff2020")
local previous = { MenuLeft=true, MenuUp=true, Left=true, Up=true }
local following = { MenuRight=true, MenuDown=true, Right=true, Down=true }

local function text(name)
	return THEME:GetString("ScreenVOLT26LayoutSetup", name)
end

local function announce()
	MESSAGEMAN:Broadcast("VOLT26LayoutChoiceChanged", { Index = selected })
end

local input
input = function(event)
	if not event or event.type ~= "InputEventType_FirstPress" then return false end
	local button = event.GameButton
	if previous[button] then
		selected = selected == 1 and #layouts or selected - 1
		announce()
	elseif following[button] then
		selected = selected == #layouts and 1 or selected + 1
		announce()
	elseif button == "Start" then
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return false end
		screen:RemoveInputCallback(input)
		VOLT26.MusicSelection.ChooseLayout(layouts[selected].Value)
		screen:SetNextScreenName("ScreenVOLT26Warmup")
		screen:StartTransitioningScreen("SM_GoToNextScreen")
	end
	return false
end

local af = Def.ActorFrame{
	Name = "VOLT26LayoutSetup",
	InitCommand = function(self) self:Center() end,
	OnCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:AddInputCallback(input) end
		announce()
	end,
	OffCommand = function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:RemoveInputCallback(input) end
	end,
}

af[#af+1] = LoadFont("Common Bold")..{
	Text = text("Heading"),
	InitCommand = function(self)
		self:y(-_screen.h * 0.30):zoom(0.72):maxwidth(_screen.w * 1.05)
			:diffuse(Color.White):shadowlength(2)
	end,
}

af[#af+1] = LoadFont("Common Normal")..{
	Text = text("ChangeLater"),
	InitCommand = function(self)
		self:y(-_screen.h * 0.235):zoom(0.43):maxwidth(_screen.w * 1.45)
			:diffuse(color("#a8a8a8"))
	end,
}

local CARD_W, CARD_H = _screen.w * 0.34, _screen.h * 0.30

for index, layout in ipairs(layouts) do
	local x = (index - (#layouts + 1) / 2) * _screen.w * 0.40
	local card = Def.ActorFrame{
		Name = "Choice" .. index,
		InitCommand = function(self) self:x(x) end,
		VOLT26LayoutChoiceChangedMessageCommand = function(self, params)
			local focused = params.Index == index
			self:stoptweening():decelerate(0.12):zoom(focused and 1 or 0.94)
				:diffusealpha(focused and 1 or 0.55)
			self:GetChild("Frame"):stoptweening():decelerate(0.12)
				:diffuse(focused and RED or color("#3a3a3a"))
			self:GetChild("Title"):stoptweening():decelerate(0.12)
				:diffuse(focused and RED or Color.White)
		end,
	}
	-- A thin outline: the frame colour behind a slightly smaller dark panel.
	card[#card+1] = Def.Quad{
		Name = "Frame",
		InitCommand = function(self) self:zoomto(CARD_W + 6, CARD_H + 6):diffuse(color("#3a3a3a")) end,
	}
	card[#card+1] = Def.Quad{
		InitCommand = function(self) self:zoomto(CARD_W, CARD_H):diffuse(color("#121212")) end,
	}
	card[#card+1] = LoadFont("Common Bold")..{
		Name = "Title",
		Text = layout.Title,
		InitCommand = function(self)
			self:y(-CARD_H * 0.16):zoom(0.80):maxwidth(CARD_W * 0.92 / 0.80)
				:diffuse(Color.White):shadowlength(1)
		end,
	}
	card[#card+1] = LoadFont("Common Normal")..{
		Text = layout.Subtitle,
		InitCommand = function(self)
			self:y(CARD_H * 0.12):zoom(0.50):maxwidth(CARD_W * 0.92 / 0.50)
				:diffuse(color("#c8c8c8"))
		end,
	}
	af[#af+1] = card
end

af[#af+1] = LoadFont("Common Bold")..{
	Text = text("Controls"),
	InitCommand = function(self)
		self:y(_screen.h * 0.32):zoom(0.40):maxwidth(_screen.w * 1.55)
			:diffuse(color("#ff3030"))
	end,
}

return af
