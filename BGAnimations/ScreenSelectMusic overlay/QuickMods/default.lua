------------------------------------------------------------
-- Quick Mods.
--
-- The handful of settings a player actually changes between songs -- how fast
-- the arrows come, how big they are, which skin and which fonts -- without
-- leaving song select for the options screen.  It is raised from the sort menu
-- as a layer over the screen, like the leaderboard and the input test, and
-- every change lands on the engine as it is made: the note field beside the
-- rows is already showing the result, so there is nothing to confirm.
--
-- The field scrolls a demonstration chart rather than the selected song, so the
-- picture is the same every time and can be compared against what the player
-- saw last time.  Its density follows the difficulty they have chosen.
--
-- Which rows appear is read from ./Other/QuickMods.lua so an operator can
-- shorten or reorder the menu without touching this file.

local L = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SortMenu/Layout.lua"))
local Sources = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/QuickMods/NoteSkinSources.lua"))
local RowDefinitions = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/QuickMods/Rows.lua"))

-- The operator's list, or the built-in order when the file is missing or does
-- not answer with a list of names.  A bad configuration never takes the menu
-- away; it falls back and carries on.
local function configuredNames()
	local path = THEME:GetCurrentThemeDirectory() .. "Other/QuickMods.lua"
	if not FILEMAN:DoesFileExist(path) then return nil end
	local ok, configured = pcall(LoadActor, path)
	if not ok or type(configured) ~= "table" then return nil end
	return configured
end

local rows = RowDefinitions.Resolve(configuredNames())

local state = {
	P1 = {Index = 1, ExitChoice = "Close"},
	P2 = {Index = 1, ExitChoice = "Close"},
}

-- The note skin samples every preview draws through.  One set for the screen,
-- found again by the previews through this table once it has been built.
local shared = {}

local input = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/QuickMods/InputHandler.lua"),
	{State = state, Rows = rows})

local af = Def.ActorFrame{
	Name = "QuickMods",
	InitCommand = function(self)
		self:draworder(6):visible(false)
	end,
	ShowQuickModsCommand = function(self)
		if self:GetVisible() then return end
		-- The cursor starts at the top every time, which is what makes Start's
		-- walk through the settings a walk rather than a resumption.
		for _, side in pairs(state) do
			side.Index = 1
			side.ExitChoice = "Close"
		end
		self:visible(true):finishtweening():diffusealpha(0):linear(0.10):diffusealpha(1)
		local composition = self:GetChild("Composition")
		if composition then
			composition:finishtweening():y(_screen.cy + 34*L.Scale)
				:decelerate(0.14):y(_screen.cy)
		end
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,
	HideQuickModsCommand = function(self)
		if not self:GetVisible() then return end
		self:finishtweening():visible(false):diffusealpha(1)
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:RemoveInputCallback(input) end
	end,
	-- Leaving song select with the menu still open would leave its callback on a
	-- screen that is going away.
	OffCommand = function(self) self:playcommand("HideQuickMods") end,

	Def.Quad{
		InitCommand = function(self) self:FullScreen():diffuse(L.Bg):diffusealpha(0.84) end,
	},
}

local composition = Def.ActorFrame{
	Name = "Composition",
	InitCommand = function(self) self:xy(_screen.cx, _screen.cy):zoom(L.Scale) end,
}

composition[#composition+1] = Sources.Build(shared)

-- Each player owns one half of the screen, the halves ScreenGameplay itself
-- uses, so P2's note field stands where P2's note field always stands.  A lone
-- player's half slides to the middle, which is also what keeps a late join from
-- finding the screen laid out for one.
for player in ivalues(PlayerNumber) do
	composition[#composition+1] = LoadActor(
		THEME:GetPathB("ScreenSelectMusic", "overlay/QuickMods/Panel.lua"),
		{
			L = L, Player = player, State = state, Rows = rows,
			Sources = shared, SourcesModule = Sources,
		}
	)
end

af[#af+1] = composition
return af
