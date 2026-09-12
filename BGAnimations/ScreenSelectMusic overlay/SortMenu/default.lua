------------------------------------------------------------
-- The VOLT26 SortMenu.
--
-- Every option the menu can offer -- sorts, profile entries, styles, playlists,
-- the advanced actions -- is reached from one dock: a row of square tiles
-- pinned to the bottom of the screen, one tile per option, each an icon and a
-- word.  Categories are tiles too; opening one raises a strip of text pills
-- above the dock and moves the cursor into it, so the player can always see
-- where they came from.
--
-- Tiles hold their places and the cursor travels, which is the behavioural
-- promise the layout makes: an option can be found by where it sits rather than
-- by reading the whole row.  Only the tile under the cursor moves, and only by
-- growing.
--
-- The option tree below is unchanged from the wheel this replaces: conditions,
-- categories and the keys the input handler branches on all keep their meaning.

local L      = LoadActor("./Layout.lua")
local Icons  = LoadActor("./Icons.lua")
local D      = LoadActor("./Descriptors.lua", L)
local Tile   = LoadActor("./Tile.lua", L, Icons)
local Strip  = LoadActor("./Strip.lua", L)

------------------------------------------------------------
-- The menu model.
--
-- The input handler talks to this and nothing else, so the tiles stay a drawing
-- concern.  Focused() answers in the same shape the wheel's focused actor did
-- -- kind, sort_by, change, new_overlay -- so the handler's branches did not
-- have to be rewritten to follow it.

local menu = {
	root = {items = {}, descriptors = {}, index = 1},
	sub  = {items = {}, descriptors = {}, index = 1},
	level = 1,            -- 1: the dock.  2: the open category's strip.
	open = nil,           -- the key of the open category, if any
	custom_functions = {},
	frame = nil,
}

function menu:Active()
	return (self.level == 2 and #self.sub.items > 0) and self.sub or self.root
end

function menu:Move(delta)
	local row = self:Active()
	local count = #row.items
	if count == 0 then return end
	row.index = ((row.index - 1 + delta) % count) + 1

	-- Stepping off the category that raised the strip puts it away: the strip
	-- belongs to the tile under the cursor, and nothing else.
	if row == self.root and self.open ~= nil then
		local option = row.items[row.index]
		if not (option and option[2] == self.open) then
			self:CloseCategory()
			return
		end
	end
	self:Redraw()
end

function menu:HasOpenCategory()
	return self.open ~= nil and #self.sub.items > 0
end

-- Into the strip and back out of it.  Neither closes the category: the strip
-- stays raised while the cursor is on the tile that raised it.
function menu:Ascend()
	if self.level == 1 and self:HasOpenCategory() then
		self.level = 2
		self:Redraw()
		return true
	end
	return false
end

function menu:Descend()
	if self.level == 2 then
		self.level = 1
		self:Redraw()
		return true
	end
	return false
end

function menu:CloseCategory()
	if self.open == nil then return false end
	self.open = nil
	self.sub = {items = {}, descriptors = {}, index = 1}
	self.level = 1
	self:Redraw()
	return true
end

function menu:FocusedOption()
	local row = self:Active()
	return row.items[row.index]
end

function menu:FocusedDescriptor()
	local row = self:Active()
	return row.descriptors[row.index]
end

function menu:IsFocusEnabled()
	local descriptor = self:FocusedDescriptor()
	return descriptor == nil or descriptor.Enabled ~= false
end

-- The shape the input handler reads.
function menu:Focused()
	local option = self:FocusedOption()
	if not option then return {} end

	local focus = {kind = option[1]}
	if focus.kind == "SortBy" then
		focus.sort_by = option[2]
	elseif focus.kind == "ChangeMode" or focus.kind == "ChangeStyle" or focus.kind == "ChangePlayMode" then
		focus.change = option[2]
	else
		focus.new_overlay = option[2]
	end
	return focus
end

function menu:Redraw()
	if self.frame then self.frame:playcommand("RedrawList") end
end

------------------------------------------------------------
-- Input.
--
-- Navigating the menu, and the TestInput and Leaderboard overlays it can open,
-- are each complex enough to live in their own file.

local sortmenu_input    = LoadActor("SortMenu_InputHandler.lua", menu)
local testinput_input   = LoadActor("TestInput_InputHandler.lua")
local leaderboard_input = LoadActor("Leaderboard_InputHandler.lua")

local SongSearchSettings = LoadActor("../SongSearch/SongSearchSettings.lua")

local IsActionEnabled = VOLT26.SongBrowsing.IsActionEnabled

-- General purpose function to redirect input back to the engine.
-- "self" here should refer to the SortMenu ActorFrame.
local DirectInputToEngine = function(self)
	local screen = SCREENMAN:GetTopScreen()
	local overlay = self:GetParent()

	screen:RemoveInputCallback(sortmenu_input)
	screen:RemoveInputCallback(testinput_input)
	screen:RemoveInputCallback(leaderboard_input)

	for player in ivalues(PlayerNumber) do
		SCREENMAN:set_input_redirected(player, false)
	end
	self:playcommand("HideSortMenu")
	overlay:playcommand("HideTestInput")
	overlay:playcommand("HideLeaderboard")
	MESSAGEMAN:Broadcast("VOLT26ModalOverlayClosed")
end

------------------------------------------------------------
-- The option tree.

local function AddFavorites()
	if not IsActionEnabled("Preferred") or GAMESTATE:IsCourseMode() then return false end

	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		if VOLT26.Favorites.HasAny(player) then
			return true
		end
	end
	return false
end

local function ChangePlayModeAvailable()
	return GAMESTATE:IsEventMode() and
		ThemePrefs.Get("AllowScreenSelectPlayMode2")
end

local function AddSorts()
	if not IsActionEnabled("SortBy") then return {} end
	-- Most sort orders don't currently work in course mode, they cause the
	-- wheel to change to song mode instead. The ones that seem work are
	-- AllCourses, Nonstop, Oni, and Endless. I don't know if those are useful
	-- so let's just disable the sort orders for course mode.
	if GAMESTATE:IsCourseMode() then return {} end

	return {
		{ {"SortBy", "Series"} },
		{ {"SortBy", "Group"} },
		{ {"SortBy", "Title"} },
		{ {"SortBy", "Artist"} },
		{ {"SortBy", "Genre"} },
		{ {"SortBy", "BPM"} },
		{ {"SortBy", "Length"} },
		{ {"SortBy", "Meter"} },
		{ {"SortBy", "Popularity"} },
		{ {"SortBy", "Recent"} },
		{ {"SortBy", "TopGrades"} },
	}
end

local function AddProfileEntries()
	if GAMESTATE:IsCourseMode() then return {} end

	return {
		{ {"NextPlease", "SwitchProfile"}, IsActionEnabled("SwitchProfile") and ThemePrefs.Get("AllowScreenSelectProfile") },
		{ {"SortBy", "PopularityP1"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_1) end },
		{ {"SortBy", "RecentP1"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_1) end },
		{ {"SortBy", "TopP1Grades"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_1) end },
		{ {"SortBy", "PopularityP2"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_2) end },
		{ {"SortBy", "RecentP2"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_2) end },
		{ {"SortBy", "TopP2Grades"}, function() return PROFILEMAN:IsPersistentProfile(PLAYER_2) end },
		{ {"MixTape", "Preferred"}, AddFavorites },
	}
end

local function AddPlaylists()
	if not (IsActionEnabled("MachinePlaylist") or IsActionEnabled("PersonalPlaylist"))
		or GAMESTATE:IsCourseMode() then return {} end

	-- First add the machine playlists
	local player_sort_options = {}
	-- Get the name of every file in the Other/Playlists directory
	local files = FILEMAN:GetDirListing(THEME:GetCurrentThemeDirectory().."Other/Playlists/")
	-- Add each file to the wheel options
	for i=1, #files do
		local file = files[i]
		if file:match("%.txt$") then
			local playlist = file:gsub("%.txt$", "")
			table.insert(player_sort_options, {{"MachinePlaylist", playlist}})
		end
	end

	-- Then add the personal playlists
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local playlistPath = PROFILEMAN:GetProfileDir(ProfileSlot[PlayerNumber:Reverse()[player] + 1]) .."/Playlists/";
		local playerPlaylists = FILEMAN:GetDirListing(playlistPath)
		for i=1, #playerPlaylists do
			local file = playerPlaylists[i]
			if file:match("%.txt$") then
				local playlist = file:gsub("%.txt$", "")
				table.insert(player_sort_options, {{"PersonalPlaylist", playlist}})
			end
		end
	end

	-- Favorites are basically a playlist so include those too
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		if VOLT26.Favorites.HasAny(player) then
			table.insert(player_sort_options, {{"MixTape", "Preferred"}})
			break
		end
	end
	return player_sort_options
end

local function GetChangeableStyles()
	if not IsActionEnabled("ChangeStyle") then return {} end
	local style = GAMESTATE:GetCurrentStyle():GetName():gsub("8", "")
	local available_styles = {}
	-- Allow players to switch from single to double and from double to single
	-- but only present these options if Joint Double or Joint Premium is enabled
	-- and we're not in "AutoSetStyle" mode (all styles presented simultaneously like PIU does)

	if ThemePrefs.Get("PreferredStyle")=="auto" then
		-- Check number of players
		if ThemePrefs.Get("AllowDanceSolo") then
			table.insert(available_styles, {{"ChangeStyle", "Solo"}, GAMESTATE:GetNumPlayersEnabled() == 1  })
		end
		table.insert(available_styles, {{"ChangeStyle", "Single"}, GAMESTATE:GetNumPlayersEnabled() == 1  })

		table.insert(available_styles, {{"ChangeStyle", "Double"}, GAMESTATE:GetNumPlayersEnabled() == 1  })
		table.insert(available_styles, {{"ChangeStyle", "Versus"}, not (GAMESTATE:GetNumPlayersEnabled() == 1)  })
		table.insert(available_styles, {{"ChangeStyle", "Routine"}, not (GAMESTATE:GetNumPlayersEnabled() == 1)  })
		table.insert(available_styles, {{"ChangeStyle", "Couple"}, not (GAMESTATE:GetNumPlayersEnabled() == 1) })
	else
		if not (PREFSMAN:GetPreference("Premium") == "Premium_Off" and GAMESTATE:GetCoinMode() == "CoinMode_Pay") then
			if style == "single" then
				table.insert(available_styles, {{"ChangeStyle", "Double"}})
				if ThemePrefs.Get("AllowDanceSolo") then
					table.insert(available_styles, {{"ChangeStyle", "Solo"}})
				end
			elseif style == "double" then
				table.insert(available_styles, {{"ChangeStyle", "Single"}})
				if ThemePrefs.Get("AllowDanceSolo") then
					table.insert(available_styles, {{"ChangeStyle", "Solo"}})
				end
			elseif style == "solo" then
				table.insert(available_styles, {{"ChangeStyle", "Single"}})
				table.insert(available_styles, {{"ChangeStyle", "Double"}})
			-- Couple doesn't have enough content for people to be able to switch into it
			-- However, if for some reason you end up in couples mode, you should be able to
			-- escape
			elseif style == "couple" then
				table.insert(available_styles, {{"ChangeStyle", "Versus"}})
				table.insert(available_styles, {{"ChangeStyle", "Routine"}})
				table.insert(available_styles, {{"ChangeStyle", "All"}})
			elseif style == "routine" then
				table.insert(available_styles, {{"ChangeStyle", "Versus"}})
				table.insert(available_styles, {{"ChangeStyle", "Couple"}})
				table.insert(available_styles, {{"ChangeStyle", "All"}})
			elseif style == "versus" then
				-- table.insert(available_styles, {{"ChangeStyle", "Routine"}})
				-- table.insert(available_styles, {{"ChangeStyle", "Couple"}})
			end
			--table.insert(available_styles, {{"ChangeStyle", "All"}})

		end
	end

	return available_styles
end

local function ResolveVisibleSubOptions(option)
	local source_sub_options = nil
	if type(option[2]) == "function" and option[1][1] == "" then
		source_sub_options = option[2]() or {}
	elseif type(option[2]) == "table" then
		source_sub_options = option[2]
	end

	local sub_options = {}
	if source_sub_options ~= nil then
		for j=1, #source_sub_options do
			local sub_option = source_sub_options[j]
			if type(sub_option[2]) == "function" then
				if sub_option[2]() then
					table.insert(sub_options, sub_option[1])
				end
			elseif sub_option[2] == nil or sub_option[2] == true then
				table.insert(sub_options, sub_option[1])
			end
		end
	end

	return sub_options
end

------------------------------------------------------------

local t = Def.ActorFrame {
	Name="SortMenu",
	wheel_options = {},
	custom_functions = {},
	InitCommand=function(self)
		self:draworder(5)
		self.custom_functions = menu.custom_functions
		menu.frame = self
		self.wheel_options = {
			-- This is the master table that controls the SortMenu's choices
			-- The structure is as follows:
			-- The top level table contains the options that will be displayed in the SortMenu.
			-- For instance: { {"SortBy", "Group"} } adds the SortBy (label) Group (name) option to the SortMenu.

			-- If a second element is present, this means we're either providing a condition determining whether or not the option is displayed.
			-- or we're creating a submenu.
			-- If the second element is a table, it's a submenu, if it equates to a boolean, it's a condition.

			-- Conditions:
			-- These determine whether or not the option will be displayed.
			-- For instance: { {"SortBy", "Group"}, GAMESTATE:IsCourseMode() } will only display the Group option in CourseMode.
			-- You can use any Lua expression that equates to a boolean value here.
			-- Alternatively, you may provide a function that returns a boolean value for more complex and timely conditions.

			-- Submenus:
			-- We can create categories within the SortMenu by providing a table as the second element
			-- The first element becomes the label and name for the category.
			-- The second element's table contains that options will show under this category.
			-- It follows the same structure as the top level table.

			-- Casual players often choose the wrong mode and an experienced player in the area may notice this
			-- and offer to switch them back to casual mode. This allows them to do so again.
			-- It's technically not possible to reach the sort menu in Casual Mode, but juuust in case let's still
			-- include the check.
			--
			-- Only show GoBack if we're in 3 key navigation mode, as it's redundant in 5 key.
			{ { "", "GoBack" }, PREFSMAN:GetPreference("ThreeKeyNavigation") },
			{ {"NextPlease", "SwitchProfile"}, IsActionEnabled("SwitchProfile") and ThemePrefs.Get("AllowScreenSelectProfile") },
			{ {"GrooveStats", "Leaderboard"}, function() return IsActionEnabled("Leaderboard") and GAMESTATE:GetCurrentSong() ~= nil end },
			{ {"WhereforeArtThou", "SongSearch"}, IsActionEnabled("SongSearch") and not GAMESTATE:IsCourseMode() and ThemePrefs.Get("KeyboardFeatures") },
			{ {"ImLovinIt", "AddFavorite"}, function() return IsActionEnabled("AddFavorite") and GAMESTATE:GetCurrentSong() ~= nil end},
			{ {"MixTape", "Preferred"}, AddFavorites },
			{ {"ChangePlayMode", "Nonstop"}, IsActionEnabled("ChangePlayMode") and not GAMESTATE:IsCourseMode() and ChangePlayModeAvailable() },
			{ {"ChangePlayMode", "Regular"}, IsActionEnabled("ChangePlayMode") and GAMESTATE:IsCourseMode() and ChangePlayModeAvailable() },
			{
				{"", "CategorySorts"},
				AddSorts(),
			},
			{
				{"", "CategoryProfile"},
				AddProfileEntries(),
			},
			{
				{"", "CategoryAdvanced"},
				{
					{ {"FeelingSalty", "TestInput"}, IsActionEnabled("TestInput") and GAMESTATE:IsEventMode() },
					{ {"HardTime", "PracticeMode"}, IsActionEnabled("PracticeMode") },
					-- Loading songs doesn't work from course mode because it invalidates autogen courses,
					-- which could delete the currently selected course.
					{ {"TakeABreather", "LoadNewSongs"}, IsActionEnabled("LoadNewSongs") and not GAMESTATE:IsCourseMode() },
					{ {"NeedMoreRam", "ViewDownloads"}, IsActionEnabled("ViewDownloads") },
					{ {"SetSummaryText", "SetSummary"}, IsActionEnabled("SetSummary") and VOLT26.State.Global.Stages.PlayedThisGame > 0 },
					{ {"BottomText", "OnlineLobbies"}, IsActionEnabled("OnlineLobbies") and ThemePrefs.Get("EnableOnlineLobbies") and GAMESTATE:IsEventMode() and not GAMESTATE:IsCourseMode() },
				}
			},
			{
				{"", "CategoryStyles"},
				GetChangeableStyles,
			},
			{
				{"", "CategoryPlaylists"},
				AddPlaylists,
			}
		}
		self:visible(false)
	end,
	-- Always ensure player input is directed back to the engine when leaving SelectMusic.
	OffCommand=function(self) self:playcommand("DirectInputToEngine") end,
	-- Figure out which choices to put in the dock based on various current conditions.
	OnCommand=function(self) self:playcommand("AssessAvailableChoices") end,
	ShowSortMenuCommand=function(self)
		self:visible(true):finishtweening():diffusealpha(0):linear(0.10):diffusealpha(1)
		local composition = self:GetChild("Composition")
		if composition then
			composition:finishtweening():y(_screen.cy + 40*L.Scale)
				:decelerate(0.14):y(_screen.cy)
		end
	end,
	HideSortMenuCommand=function(self) self:finishtweening():visible(false):diffusealpha(1) end,
	ToggleCategoryCommand=function(self, params)
		if not (params and params.Category) then return end
		if menu.open == params.Category then
			menu:CloseCategory()
		else
			menu.open = params.Category
			self:playcommand("AssessAvailableChoices")
			-- The strip is raised for the player to act in, so the cursor follows
			-- it up rather than making them press again to get there.
			menu.level = #menu.sub.items > 0 and 2 or 1
			menu:Redraw()
		end
	end,
	EnterCategoryMessageCommand=function(self, params)
		self:playcommand("ToggleCategory", params)
	end,
	DirectInputToSortMenuCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local overlay = self:GetParent()
		screen:RemoveInputCallback(testinput_input)
		screen:RemoveInputCallback(leaderboard_input)
		screen:AddInputCallback(sortmenu_input)
		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, true)
		end
		-- Stop the music wheel in case it's still spinning.
		screen:GetMusicWheel():Move(0)
		self:queuecommand("AssessAvailableChoices"):queuecommand("ShowSortMenu")
		overlay:playcommand("HideTestInput")
		overlay:playcommand("HideLeaderboard")
		MESSAGEMAN:Broadcast("VOLT26ModalOverlayOpened")
	end,
	DirectInputToTestInputCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local overlay = self:GetParent()
		screen:RemoveInputCallback(sortmenu_input)
		screen:AddInputCallback(testinput_input)
		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, true)
		end
		self:playcommand("HideSortMenu")

		overlay:playcommand("ShowTestInput")
	end,
	DirectInputToLeaderboardCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local overlay = self:GetParent()
		screen:RemoveInputCallback(sortmenu_input)
		screen:AddInputCallback(leaderboard_input)
		for player in ivalues(PlayerNumber) do
			SCREENMAN:set_input_redirected(player, true)
		end
		self:playcommand("HideSortMenu")

		overlay:playcommand("ShowLeaderboard")
	end,
	-- this returns input back to the engine and its ScreenSelectMusic
	DirectInputToEngineCommand=function(self)
		DirectInputToEngine(self)
	end,
	DirectInputToEngineForSongSearchCommand=function(self)
		DirectInputToEngine(self)

		-- Then add the ScreenTextEntry on top.
		SCREENMAN:AddNewScreenToTop("ScreenTextEntry")
		SCREENMAN:GetTopScreen():Load(SongSearchSettings)
	end,
	DirectInputToEngineForSelectProfileCommand=function(self)
		DirectInputToEngine(self)

		-- Then add the ScreenSelectProfile on top.
		SCREENMAN:AddNewScreenToTop("ScreenSelectProfile")
	end,

	AssessAvailableChoicesCommand=function(self)
		local ctx = {
			SortOrder = ToEnumShortString(GAMESTATE:GetSortOrder()),
			OpenCategory = menu.open,
			CategoryEntries = function(key)
				for i=1, #self.wheel_options do
					local option = self.wheel_options[i]
					if option and option[1] and option[1][2] == key then
						return ResolveVisibleSubOptions(option)
					end
				end
				return {}
			end,
		}

		-- The dock: every top level option the current state can offer, with a
		-- category kept only while it has something in it.
		local tiles = {}
		for i=1, #self.wheel_options do
			local option = self.wheel_options[i]
			if option ~= nil then
				-- If this is a category (empty label) and uses either
				-- a table or a function as its submenu source, resolve it
				local is_category = type(option[1]) == "table" and option[1][1] == "" and option[1][2] ~= nil
				if is_category and (type(option[2]) == "table" or type(option[2]) == "function") then
					if #ResolveVisibleSubOptions(option) > 0 then
						table.insert(tiles, {option[1][1], option[1][2]})
					end
				elseif type(option[2]) == "function" then
					if option[2]() then
						table.insert(tiles, {option[1][1], option[1][2]})
					end
				elseif option[2] == nil or option[2] == true then
					table.insert(tiles, {option[1][1], option[1][2]})
				end
			end
		end

		-- Which tile holds the cursor: the one it was already on, if the rebuild
		-- kept it, and otherwise the first option that is not the way out.
		local wanted = menu.root.items[menu.root.index]
		wanted = wanted and wanted[2] or nil
		local index = nil
		for i=1, #tiles do
			if tiles[i][2] == wanted then index = i break end
		end
		if index == nil then
			index = 1
			for i=1, #tiles do
				if tiles[i][2] ~= "GoBack" then index = i break end
			end
		end

		local descriptors = {}
		for i, option in ipairs(tiles) do
			descriptors[i] = D.Describe(option, ctx)
		end
		menu.root = {items = tiles, descriptors = descriptors, index = math.max(1, math.min(index, math.max(1, #tiles)))}

		-- The strip, when a category is open and still has entries.  A category
		-- that has just emptied -- the last playlist deleted, a song deselected
		-- -- puts itself away rather than leaving an empty bar on screen.
		local entries = menu.open and ctx.CategoryEntries(menu.open) or {}
		if #entries == 0 then
			menu.open = nil
			menu.sub = {items = {}, descriptors = {}, index = 1}
			menu.level = 1
		else
			local previous = menu.sub.items[menu.sub.index]
			previous = previous and previous[2] or nil
			local subIndex = 1
			for i=1, #entries do
				if entries[i][2] == previous then subIndex = i break end
			end

			local subDescriptors = {}
			for i, option in ipairs(entries) do
				subDescriptors[i] = D.Describe(option, ctx)
			end
			menu.sub = {items = entries, descriptors = subDescriptors, index = subIndex}
		end

		menu:Redraw()
	end,

	-- Repainting is all this does: the descriptors were built when the menu was
	-- assembled, so moving the cursor costs one row of tiles and a strip.
	RedrawListCommand=function(self)
		local composition = self:GetChild("Composition")
		if not composition then return end

		local dock = composition:GetChild("Dock")
		local descriptors = menu.root.descriptors
		local count = #descriptors

		-- A dock wider than the pool is shown through a window that keeps the
		-- cursor near its middle; in practice the option tree never fills it.
		local first = 1
		if count > L.MaxTiles then
			first = math.max(1, math.min(menu.root.index - math.floor(L.MaxTiles/2), count - L.MaxTiles + 1))
		end
		local shown = math.min(L.MaxTiles, count)

		local contentW = shown > 0 and (shown*L.TileSize + (shown-1)*L.TileGap) or 0
		local barWidth = math.min(L.MaxBarW, contentW + L.BarPadX*2)
		local left = -contentW/2 + L.TileSize/2

		local fill = dock:GetChild("BarFill")
		fill:finishtweening():decelerate(0.12):zoomto(barWidth, L.DockH)
		L.SizeFrame(dock:GetChild("BarEdge"), barWidth, L.DockH, 1, L.Line)

		local cursorOnDock = menu.level == 1 or #menu.sub.items == 0
		for slot = 1, L.MaxTiles do
			local item_index = first + slot - 1
			local descriptor = slot <= shown and descriptors[item_index] or nil
			Tile.Apply(dock:GetChild("Tile"..slot), descriptor, {
				X        = left + (slot-1)*(L.TileSize + L.TileGap),
				Focused  = cursorOnDock and item_index == menu.root.index,
				Distance = math.abs(item_index - menu.root.index),
				Open     = descriptor ~= nil and menu.open ~= nil and descriptor.Key == menu.open,
			})
		end

		Strip.Apply(composition:GetChild("Strip"), menu.sub.descriptors, menu.sub.index, not cursorOnDock)
	end,

	CurrentSongChangedMessageCommand=function(self)
		if self:GetVisible() then
			self:queuecommand("AssessAvailableChoices")
		end
	end,

	-- The scrim sits outside the design-space frame so it covers the whole
	-- screen whatever the aspect ratio letterboxes away.  The song select screen
	-- stays readable underneath: the dock is a layer over the screen, not a
	-- replacement for it.
	Def.Quad {
		InitCommand=function(self) self:FullScreen():diffuse(L.Bg):diffusealpha(0.6) end
	},
}

------------------------------------------------------------
-- The composition, in design space.

local composition = Def.ActorFrame{
	Name="Composition",
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy):zoom(L.Scale) end,
}

-- Every icon the dock can ask for, loaded once so swapping a tile's texture
-- mid-menu never reads a file.
local preload = Def.ActorFrame{
	Name="IconPreload",
	InitCommand=function(self) self:visible(false) end,
}
for _, name in ipairs(Icons.All()) do
	preload[#preload+1] = Def.Sprite{
		InitCommand=function(self) self:Load(Icons.Path(name)):zoom(0.01) end,
	}
end
composition[#composition+1] = preload

composition[#composition+1] = Strip.Build()

local dock = Def.ActorFrame{Name="Dock"}
dock[#dock+1] = Def.Quad{
	Name="BarFill",
	InitCommand=function(self)
		self:y(L.DockTop + L.DockH/2):zoomto(100, L.DockH):diffuse(L.Panel):diffusealpha(0.96)
	end,
}
local dockEdge = L.Frame("BarEdge", L.Line)
dockEdge.InitCommand = function(self)
	self:y(L.DockTop + L.DockH/2)
	L.SizeFrame(self, 100, L.DockH, 1)
end
dock[#dock+1] = dockEdge
for index = 1, L.MaxTiles do
	dock[#dock+1] = Tile.Build(index)
end
composition[#composition+1] = dock

t[#t+1] = composition

t[#t+1] = LoadActor( THEME:GetPathS("ScreenSelectMaster", "change") )..{ Name="change_sound", IsAction=true, SupportPan=false }
t[#t+1] = LoadActor( THEME:GetPathS("common", "start") )..{ Name="start_sound", IsAction=true, SupportPan=false }
return t
