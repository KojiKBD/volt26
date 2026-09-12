-- What each SortMenu option is, in the terms the dock draws.
--
-- Every tile and every pill is rendered from one descriptor, so a new option
-- only has to say what it is here and it gets the same treatment as everything
-- else: the word under its icon, the figure beside its name in a category
-- strip, and whether it can be chosen at all.
--
-- Descriptor fields:
--   Key      the option's own key, which is also what picks its icon
--   Name     the option's full name, as a category strip sets it
--   Short    the word the dock puts under the tile
--   Meta     the figure drawn beside the name in a category strip
--   Enabled  false greys the option out and refuses to activate it
--   Active   marks the option that is already in force
--   Action   the verb this option would perform, kept for the input handler's
--            sake and for anything that wants to name the choice

local L = ...

local D = {}

local function S(key) return L.String(key) end

------------------------------------------------------------
-- Song library figures.
--
-- The library does not change while Song Select is open -- loading new songs
-- leaves the screen -- so each of these is measured once and kept.

local groupCache = nil
local genreCache = nil

local function groups()
	if groupCache then return groupCache end
	groupCache = {}
	local ok, names = pcall(function() return SONGMAN:GetSongGroupNames() end)
	if ok and names then
		for _, name in ipairs(names) do
			groupCache[#groupCache+1] = name
		end
	end
	return groupCache
end

local function genres()
	if genreCache then return genreCache end
	genreCache = {}
	local seen = {}
	local ok, songs = pcall(function() return SONGMAN:GetAllSongs() end)
	if ok and songs then
		for _, song in ipairs(songs) do
			local genre = song.GetGenre and song:GetGenre() or ""
			if genre ~= "" and not seen[genre] then
				seen[genre] = true
				genreCache[#genreCache+1] = genre
			end
		end
	end
	return genreCache
end

------------------------------------------------------------
-- Names.
--
-- The Languages files already name every option.  The dock also wants a short
-- word -- "ADVANCED" rather than "ADVANCED OPTIONS" -- which is a separate
-- string so a translation can shorten its own way; where none exists the full
-- name is used and the tile's maxwidth deals with it.

function D.NameOf(option)
	local key = option[2]
	if THEME:HasString("ScreenSelectMusic", key) then
		return THEME:GetString("ScreenSelectMusic", key)
	end
	if THEME:HasString("ScreenSelectPlayMode", key) then
		return THEME:GetString("ScreenSelectPlayMode", key)
	end
	return (tostring(key):gsub("^Category", ""))
end

function D.ShortOf(option, name)
	local key = "SortMenuTile" .. tostring(option[2])
	if THEME:HasString("ScreenSelectMusic", key) then
		return THEME:GetString("ScreenSelectMusic", key)
	end
	return name or D.NameOf(option)
end

------------------------------------------------------------
-- Sorts.
--
-- Each sort says what it orders by rather than repeating "sort by", and the one
-- currently in force is marked so the player can see it without hunting.

local sortMeta = {
	Series      = function() return #groups(), "SortMenuGroups" end,
	Group       = function() return #groups(), "SortMenuPacks" end,
	Title       = function() return nil, "SortMenuAZ" end,
	Artist      = function() return nil, "SortMenuAZ" end,
	Genre       = function() return #genres(), "SortMenuGenres" end,
	BPM         = function() return nil, "SortMenuAscending" end,
	Length      = function() return nil, "SortMenuAscending" end,
	Meter       = function() return nil, "SortMenuAscending" end,
	Popularity  = function() return nil, "SortMenuMostPlayed" end,
	Recent      = function() return nil, "SortMenuRecent" end,
	TopGrades   = function() return nil, "SortMenuPlayedOnly" end,
	PopularityP1= function() return nil, "SortMenuMostPlayed" end,
	PopularityP2= function() return nil, "SortMenuMostPlayed" end,
	RecentP1    = function() return nil, "SortMenuRecent" end,
	RecentP2    = function() return nil, "SortMenuRecent" end,
	TopP1Grades = function() return nil, "SortMenuPlayedOnly" end,
	TopP2Grades = function() return nil, "SortMenuPlayedOnly" end,
}

local function describeSort(option, ctx)
	local key = option[2]
	local meta = sortMeta[key]
	local count, unit = nil, nil
	if meta then count, unit = meta() end

	local text
	if count and unit then
		text = count .. " " .. S(unit)
	elseif unit then
		text = S(unit)
	end

	local enabled = not (count ~= nil and count == 0)
	if not enabled then text = S("SortMenuUnavailable") end

	local name = D.NameOf(option)
	return {
		Key     = key,
		Name    = name,
		Short   = D.ShortOf(option, name),
		Meta    = text,
		Enabled = enabled,
		Active  = (ctx.SortOrder == key) and enabled,
		Action  = "SortMenuApplySort",
	}
end

------------------------------------------------------------
-- Everything that is not a sort.

local function describeCategory(option, ctx)
	local entries = ctx.CategoryEntries(option[2]) or {}
	local name = D.NameOf(option)
	return {
		Key        = option[2],
		Name       = name,
		Short      = D.ShortOf(option, name),
		Meta       = #entries .. " " .. S("SortMenuEntries"),
		Enabled    = #entries > 0,
		Active     = ctx.OpenCategory == option[2],
		Action     = ctx.OpenCategory == option[2] and "SortMenuCloseCategory" or "SortMenuOpenCategory",
		IsCategory = true,
	}
end

local function describeStyle(option)
	local name = D.NameOf(option)
	return {
		Key     = option[2],
		Name    = name,
		Short   = D.ShortOf(option, name),
		Meta    = S("SortMenuReloads"),
		Enabled = true,
		Action  = "SortMenuActivate",
	}
end

local function describePlaylist(option, kind)
	return {
		Key     = option[2],
		Name    = option[2],
		Short   = option[2],
		Meta    = S(kind),
		Enabled = true,
		Action  = "SortMenuActivate",
	}
end

local function describeFavorites(option)
	local name = D.NameOf(option)
	return {
		Key     = option[2],
		Name    = name,
		Short   = D.ShortOf(option, name),
		Meta    = S("SortMenuLoadsList"),
		Enabled = true,
		Action  = "SortMenuActivate",
	}
end

-- Options that simply do a thing: the verb the choice carries, and the label
-- the option sits under in the languages files.
local actions = {
	GoBack        = {Label="SortMenuNavigation", Action="SortMenuBack"},
	SwitchProfile = {Label="NextPlease",         Action="SortMenuOpen"},
	Leaderboard   = {Label="GrooveStats",        Action="SortMenuOpen"},
	SongSearch    = {Label="WhereforeArtThou",   Action="SortMenuOpen"},
	AddFavorite   = {Label="ImLovinIt",          Action="SortMenuActivate"},
	TestInput     = {Label="FeelingSalty",       Action="SortMenuOpen"},
	PracticeMode  = {Label="HardTime",           Action="SortMenuActivate"},
	LoadNewSongs  = {Label="TakeABreather",      Action="SortMenuActivate"},
	ViewDownloads = {Label="NeedMoreRam",        Action="SortMenuOpen"},
	SetSummary    = {Label="SetSummaryText",     Action="SortMenuOpen"},
	OnlineLobbies = {Label="BottomText",         Action="SortMenuOpen"},
	Regular       = {Label="ChangePlayMode",     Action="SortMenuActivate"},
	Nonstop       = {Label="ChangePlayMode",     Action="SortMenuActivate"},
}

local function describeAction(option)
	local spec = actions[option[2]]
	local name = D.NameOf(option)
	return {
		Key     = option[2],
		Name    = name,
		Short   = D.ShortOf(option, name),
		Meta    = spec and S(spec.Action) or S("SortMenuAction"),
		Enabled = true,
		Action  = spec and spec.Action or "SortMenuActivate",
		IsBack  = option[2] == "GoBack",
	}
end

------------------------------------------------------------

-- ctx: {SortOrder=<short sort order>, OpenCategory=<key or nil>,
--       CategoryEntries=function(key) -> array of options}
function D.Describe(option, ctx)
	local kind = option[1]

	if kind == "SortBy" then
		return describeSort(option, ctx)
	elseif kind == "ChangeStyle" then
		return describeStyle(option)
	elseif kind == "MachinePlaylist" then
		return describePlaylist(option, "MachinePlaylist")
	elseif kind == "PersonalPlaylist" then
		return describePlaylist(option, "PersonalPlaylist")
	elseif kind == "MixTape" then
		return describeFavorites(option)
	elseif kind == "" and tostring(option[2]):match("^Category") then
		return describeCategory(option, ctx)
	end

	return describeAction(option)
end

function D.ForgetLibrary()
	groupCache = nil
	genreCache = nil
end

return D
