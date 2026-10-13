-- ScreenTitleJoin: the title screen in Free Play and Pay modes.
--
-- [ScreenTitleJoin] falls back to ScreenTitleMenu, so it shares the title
-- menu's underlay (the city, the intro camera, the menu sounds) but hides the
-- menu scroller: one Start joins.  Its overlay used to be a single plain
-- prompt, which also replaced the title menu's own overlay -- the opening vow,
-- the logo and the disclaimer never appeared in these modes.  This overlay
-- draws the title menu's overlay first and then the join prompt, in cutout
-- lettering (project rule: on-screen prompts are cutout), once the intro has
-- finished.

local style = VOLT26.Cutout.Style("TitleJoinPrompt")

local function promptText()
	local text
	if GAMESTATE:GetCoinMode() ~= "CoinMode_Free" and GetCredits().Credits <= 0 then
		text = THEME:GetString("ScreenLogo", "EnterCreditsToPlay")
	else
		text = THEME:GetString("ScreenTitleJoin", "Press Start")
	end
	-- Button tags such as &START; have no cutout letters: spell them out.
	text = text:gsub("&(%u+);", "%1"):gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

local prompt = Def.ActorFrame{
	Name = "JoinPrompt",
	InitCommand = function(self)
		self:xy(_screen.cx, _screen.h - 80):visible(false)
	end,
	OnCommand = function(self)
		self:diffuseshift():effectperiod(1.333)
			:effectcolor1(1, 1, 1, 0.25):effectcolor2(1, 1, 1, 1)
		self:queuecommand("Refresh")
	end,
	OffCommand = function(self) self:visible(false) end,
	CoinsChangedMessageCommand = function(self) self:queuecommand("Refresh") end,
	CoinModeChangedMessageCommand = function(self) self:queuecommand("Refresh") end,
	VOLT26_TitleIntroCompleteMessageCommand = function(self) self:queuecommand("Refresh") end,
	RefreshCommand = function(self)
		self:visible(not IsHome() and not _G.Volt26TitleIntroActive)
		self:GetChild("Text"):playcommand("CutoutSet", { text = promptText() })
	end,
	VOLT26.Cutout.CreateSlot{
		maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
		halign = 0.5, valign = 0.5, opts = style.opts,
		fallbackZoom = 0.7,
	}..{ Name = "Text" },
}

return Def.ActorFrame{
	LoadActor(THEME:GetPathB("ScreenTitleMenu", "overlay")),
	prompt,
}
