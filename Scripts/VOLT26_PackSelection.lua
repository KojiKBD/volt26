-- VOLT26.PackSelection: the behaviour behind the pack (song group) step of
-- music selection.
--
-- Music selection is split in two screens.  ScreenVOLT26SelectPack lets the
-- players choose a pack; ScreenSelectMusic then opens the engine MusicWheel on
-- that pack alone (see [VOLT26SongWheel] in metrics.ini).  This module owns the
-- data side of the first step: which packs exist, what artwork represents each
-- one, a short summary of its contents, and handing the chosen pack to the
-- engine.  It never builds actors, reads coordinates, or picks theme graphics;
-- the screens own all of that.
--
-- The first step follows the song wheel's sort.  Under the group sort it lists
-- packs; under the title, artist, genre, BPM, length and meter sorts it lists
-- the sections that sort divides the library into (initials, genres, BPM and
-- length ranges, meters), and the song wheel then opens on the chosen section
-- alone.  Every function below that takes a pack name takes such a section's
-- key as well; only packs have artwork.

VOLT26.PackSelection = VOLT26.PackSelection or {}
local PackSelection = VOLT26.PackSelection

-- Artwork and summaries are cached per pack for as long as the theme stays
-- loaded.  ScreenReloadSongs rebuilds the song list, so PackSelection.List()
-- clears both caches whenever the pack screen asks for a fresh list.
local artworkCache = {}
local summaryCache = {}
-- What the song wheel's section rows hold (WheelSectionContents) and the
-- packs of every series (SeriesPacks), cleared with the others.
local contentsCache = {}
local seriesCache = nil

local imageExtensions = { png=true, jpg=true, jpeg=true, gif=true, bmp=true }
local movieExtensions = {
	avi=true, f4v=true, flv=true, mkv=true, mp4=true, mpeg=true,
	mpg=true, mov=true, ogv=true, ogg=true, webm=true, wmv=true,
}

-- File names that mark an image in a pack folder as the pack's jacket, best
-- first.  Anything ending in "jacket" (for example "MyPack-jacket.png") ranks
-- after the exact names.
local jacketNameRank = { jacket=1, cover=2, folder=3, jk=4 }

local function extensionOf(path)
	return (tostring(path or ""):match("%.([^./\\]+)$") or ""):lower()
end

local function isMovie(path)
	return movieExtensions[extensionOf(path)] == true
end

local function usablePath(path)
	return type(path) == "string" and path ~= "" and not isMovie(path)
end

-- The hidden song's pack (VOLT26.Secret) holds no songs as far as music
-- selection is concerned, so it is never listed, previewed or counted.
local function songsInGroup(group)
	if VOLT26.Secret and VOLT26.Secret.IsHiddenGroup(group) then return {} end
	local ok, songs = pcall(function() return SONGMAN:GetSongsInGroup(group) end)
	if ok and type(songs) == "table" then return songs end
	return {}
end

local function currentStepsType()
	local style = GAMESTATE:GetCurrentStyle()
	return style and style:GetStepsType() or nil
end

-- A song counts as playable when it has at least one chart for the current
-- style.  An engine that cannot answer the question excludes nothing.
local function isPlayable(song, stepsType)
	if not stepsType then return true end
	local ok, has = pcall(function() return song:HasStepsType(stepsType) end)
	if not ok then return true end
	return has == true
end

local function titleKey(song)
	local ok, title = pcall(function() return song:GetTranslitFullTitle() end)
	if not ok or type(title) ~= "string" then
		ok, title = pcall(function() return song:GetDisplayFullTitle() end)
	end
	return (ok and type(title) == "string") and title:upper() or ""
end

local function nameKey(name)
	return tostring(name or ""):upper()
end

-- Every pack that holds at least one song, in case-insensitive name order --
-- the same order the music wheel's group sort lists its sections in.
-- Each entry is {Name=<group name>, Songs=<number of songs>}.
function PackSelection.List()
	artworkCache = {}
	summaryCache = {}
	contentsCache = {}
	seriesCache = nil
	PackSelection.ForgetSections()
	if PackSelection.Mode() ~= "Pack" then return PackSelection.Sections().list end
	local list = {}
	local ok, names = pcall(function() return SONGMAN:GetSongGroupNames() end)
	if not ok or type(names) ~= "table" then return list end
	for _, name in ipairs(names) do
		local count = #songsInGroup(name)
		if count > 0 then list[#list+1] = { Name=name, Songs=count } end
	end
	table.sort(list, function(a, b)
		local ka, kb = nameKey(a.Name), nameKey(b.Name)
		if ka ~= kb then return ka < kb end
		return a.Name < b.Name
	end)
	return list
end

-- Where the list should open: the pack of the song last played or chosen, so
-- coming back from the song wheel lands on the pack that was just left.
function PackSelection.InitialIndex(list)
	if type(list) ~= "table" or #list == 0 then return 1 end
	local wanted = PackSelection.LastPack
	local song = GAMESTATE:GetCurrentSong()
	if not song then
		local ok, preferred = pcall(function() return GAMESTATE:GetPreferredSong() end)
		song = ok and preferred or nil
	end
	if PackSelection.Mode() ~= "Pack" then
		wanted = song and PackSelection.KeyForSong(song) or PackSelection.LastSection[PackSelection.Mode()]
	elseif song then
		local ok, group = pcall(function() return song:GetGroupName() end)
		if ok and type(group) == "string" and group ~= "" then wanted = group end
	end
	if wanted then
		for index, entry in ipairs(list) do
			if entry.Name == wanted then return index end
		end
	end
	return 1
end

-- The folder a pack lives in, derived from one of its songs so that packs in
-- AdditionalSongFolders resolve as well as packs under Songs/.
local function packDirectory(group)
	local song = songsInGroup(group)[1]
	if not song then return nil end
	local ok, dir = pcall(function() return song:GetSongDir() end)
	if not ok or type(dir) ~= "string" or dir == "" then return nil end
	dir = dir:gsub("[/\\]+$", "")
	local parent = dir:match("^(.*)[/\\][^/\\]+$")
	if not parent or parent == "" then return nil end
	return parent .. "/"
end

local function jacketRank(fileName)
	local base, extension = fileName:match("^(.*)%.([^.]+)$")
	if not base or not imageExtensions[extension:lower()] then return nil end
	base = base:lower()
	if jacketNameRank[base] then return jacketNameRank[base] end
	if base:match("jacket$") then return 5 end
	if base:match("[%s_%-]jk$") then return 6 end
	return nil
end

local function findJacketFile(dir)
	if not dir then return nil end
	local ok, files = pcall(function() return FILEMAN:GetDirListing(dir, false, true) end)
	if not ok or type(files) ~= "table" then return nil end
	local best, bestRank
	for _, path in ipairs(files) do
		local fileName = tostring(path):match("([^/\\]+)$") or tostring(path)
		local rank = jacketRank(fileName)
		if rank and (not bestRank or rank < bestRank) then best, bestRank = path, rank end
	end
	return best
end

-- Some ITGmania builds can report a pack jacket themselves; older ones answer
-- nothing here and the pack folder is searched instead.
local function engineJacket(group)
	local ok, path = pcall(function()
		if SONGMAN.GetSongGroupJacketPath then return SONGMAN:GetSongGroupJacketPath(group) end
		return nil
	end)
	return ok and usablePath(path) and path or nil
end

local function groupBanner(group)
	local ok, path = pcall(function() return SONGMAN:GetSongGroupBannerPath(group) end)
	return ok and usablePath(path) and path or nil
end

-- The artwork that stands for a pack: {Path=<file>, Kind="Jacket"|"Banner"},
-- or nil when the pack has neither.  A jacket is preferred; a pack banner is
-- the fallback.  Movies are never answered: decoding one per carousel tile is
-- more than the low-end path can afford.
function PackSelection.Artwork(group)
	if PackSelection.IsSection(group) then return nil end
	local cached = artworkCache[group]
	if cached ~= nil then return cached or nil end

	local art = false
	local jacket = engineJacket(group) or findJacketFile(packDirectory(group))
	if usablePath(jacket) then
		art = { Path=jacket, Kind="Jacket" }
	else
		local banner = groupBanner(group)
		if banner then
			art = { Path=banner, Kind="Banner" }
		elseif #songsInGroup(group) == 0 then
			-- Not a pack: a series (a collection of packs, the wheel's
			-- parent sections under the series sort) may have a banner.
			local ok, path = pcall(function() return SONGMAN:GetSeriesBannerPath(group) end)
			if ok and usablePath(path) then art = { Path=path, Kind="Banner" } end
		end
	end
	artworkCache[group] = art
	return art or nil
end

-- A short description of a pack for the current style:
-- {Songs=<all songs>, Playable=<songs with a chart for this style>,
--  MinMeter=<lowest meter or nil>, MaxMeter=<highest meter or nil>}.
function PackSelection.Summary(group)
	local stepsType = currentStepsType()
	local key = tostring(group) .. "|" .. tostring(stepsType)
	if summaryCache[key] then return summaryCache[key] end

	local songs
	if PackSelection.IsSection(group) then
		local entry = PackSelection.Sections().byKey[group]
		songs = entry and entry.members or {}
	else
		songs = songsInGroup(group)
	end
	local summary = { Songs=#songs, Playable=0 }
	for _, song in ipairs(songs) do
		if isPlayable(song, stepsType) then
			summary.Playable = summary.Playable + 1
			if stepsType then
				local ok, charts = pcall(function() return song:GetStepsByStepsType(stepsType) end)
				if ok and type(charts) == "table" then
					for _, chart in ipairs(charts) do
						local meter = tonumber(chart:GetMeter())
						if meter and meter > 0 then
							summary.MinMeter = math.min(summary.MinMeter or meter, meter)
							summary.MaxMeter = math.max(summary.MaxMeter or meter, meter)
						end
					end
				end
			end
		end
	end
	summaryCache[key] = summary
	return summary
end

-- The pack's songs in title order (the order the song wheel lists them in,
-- near enough: by transliterated full title, case-insensitive).
function PackSelection.Songs(group)
	local songs = {}
	for _, song in ipairs(songsInGroup(group)) do songs[#songs+1] = song end
	local keys = {}
	for _, song in ipairs(songs) do keys[song] = titleKey(song) end
	table.sort(songs, function(a, b)
		if keys[a] ~= keys[b] then return keys[a] < keys[b] end
		return tostring(a) < tostring(b)
	end)
	return songs
end

-- The hardest meter a song offers in the current style, or nil.
function PackSelection.HardestMeter(song)
	local stepsType = currentStepsType()
	if not song or not stepsType then return nil end
	local ok, charts = pcall(function() return song:GetStepsByStepsType(stepsType) end)
	if not ok or type(charts) ~= "table" then return nil end
	local hardest
	for _, chart in ipairs(charts) do
		local meter = tonumber(chart:GetMeter())
		if meter and meter > 0 then hardest = math.max(hardest or meter, meter) end
	end
	return hardest
end

-- Hands the chosen pack to the engine.  The MusicWheel opens on the preferred
-- song's section, so the pack is chosen by choosing one of its songs: the song
-- already current when it belongs to this pack (coming back to a pack lands on
-- the song that was left), otherwise the pack's first playable song by title.
-- Answers whether a song was found.
function PackSelection.Choose(group)
	PackSelection.wheelSection = nil
	if PackSelection.IsSection(group) then return PackSelection.ChooseSection(group) end
	local songs = songsInGroup(group)
	if #songs == 0 then return false end

	local target
	local current = GAMESTATE:GetCurrentSong()
	if current then
		local ok, currentGroup = pcall(function() return current:GetGroupName() end)
		if ok and currentGroup == group then target = current end
	end

	if not target then
		local stepsType = currentStepsType()
		local bestKey
		for _, song in ipairs(songs) do
			if isPlayable(song, stepsType) then
				local key = titleKey(song)
				if not bestKey or key < bestKey then target, bestKey = song, key end
			end
		end
		target = target or songs[1]
	end

	GAMESTATE:SetPreferredSong(target)
	GAMESTATE:SetCurrentSong(target)
	PackSelection.LastPack = group
	return true
end

-- The two music selection screens are drawn to read as one: the chosen pack's
-- jacket travels between the pack carousel and the song wheel's header while
-- the screen underneath changes.  The screen being left records which way the
-- players are going and the screen being entered takes it, once, to choose its
-- entrance.  Values: "ToSongWheel" (a pack was opened) and "FromSongWheel"
-- (Back from the song wheel).  Any other entry finds nil.
function PackSelection.SetHandoff(direction)
	PackSelection.handoff = direction
end

function PackSelection.TakeHandoff()
	local direction = PackSelection.handoff
	PackSelection.handoff = nil
	PackSelection.taken = direction
	return direction
end

-- The direction the last TakeHandoff answered (nil when it found none), for
-- the other layers of the screen being entered: the overlay takes the
-- hand-off when it loads, and the background, loaded after it, still needs
-- to know whether its scenery was already built by the screen being left.
function PackSelection.TakenHandoff()
	return PackSelection.taken
end

------------------------------------------------------------------------------
-- Following the song wheel's sort.
--
-- The sections are worked out the way the engine's MusicWheel names them
-- (SongUtil::GetSectionNameFromSongAndSort in ITGmania), so the section the
-- pack step offers is the section the wheel opens on:
--   Title, Artist  first letter of the transliterated main title / artist,
--                  upper case, one leading "." skipped; digits make "0-9" and
--                  anything else one shared "other" section
--   Genre          the song's genre; songs without one share a section
--   BPM            the highest display BPM, in [MusicWheel] SortBPMDivision
--                  steps (120-129 with a division of 10)
--   Length         the music length, in [MusicWheel] SortLengthDivision
--                  second steps
--   Meter          every meter the song has a chart of in the current style,
--                  so a song can sit in several sections
-- Only songs with a chart for the current style are listed.  The group sort
-- lists packs as before.  Every other sort (series, popularity, recent, top
-- grades, playlists) is not followed: the pack step shows packs and the song
-- wheel goes back to the group sort when a pack is opened.

local SECTION_PREFIX = "\1"
local sectionSorts = { Title=true, Artist=true, Genre=true, BPM=true, Length=true, Meter=true }
local sectionCache = nil
PackSelection.LastSection = PackSelection.LastSection or {}

local function shortSort(order)
	return (tostring(order or ""):gsub("^SortOrder_", ""))
end

local function currentSort()
	local ok, order = pcall(function() return GAMESTATE:GetSortOrder() end)
	return ok and order and shortSort(order) or ""
end

-- Whether the pack step follows this sort (a SortOrder value, with or without
-- its "SortOrder_" prefix), i.e. whether the song wheel may keep it when a
-- pack or section is opened.
function PackSelection.FollowsSort(order)
	local short = shortSort(order)
	return short == "Group" or sectionSorts[short] == true
end

-- What the pack step lists: "Pack", or the short name of the sort whose
-- sections it lists ("Title", "Artist", "Genre", "BPM", "Length", "Meter").
function PackSelection.Mode()
	if GAMESTATE:IsCourseMode() then return "Pack" end
	local short = currentSort()
	return sectionSorts[short] and short or "Pack"
end

function PackSelection.IsSection(key)
	return type(key) == "string" and key:sub(1, #SECTION_PREFIX) == SECTION_PREFIX
end

local function wheelMetric(name, fallback)
	local ok, value = pcall(function() return THEME:GetMetric("MusicWheel", name) end)
	value = ok and tonumber(value) or nil
	if not value or value < 1 then return fallback end
	return math.floor(value)
end

local function initialOf(text)
	local s = tostring(text or ""):upper()
	if s:sub(1, 1) == "." then s = s:sub(2) end
	local c = s:sub(1, 1)
	if c:match("^%d$") then return "0-9", 0 end
	if c:match("^[A-Z]$") then return c, c:byte() - 64 end
	return "", 27
end

local function call(song, method)
	local ok, value = pcall(function() return song[method](song) end)
	if ok then return value end
	return nil
end

local function chartMeters(song, stepsType)
	local meters, seen = {}, {}
	if not stepsType then return meters end
	local ok, charts = pcall(function() return song:GetStepsByStepsType(stepsType) end)
	if not ok or type(charts) ~= "table" then return meters end
	for _, chart in ipairs(charts) do
		local meter = tonumber(chart:GetMeter())
		if meter and not seen[meter] then
			seen[meter] = true
			meters[#meters+1] = meter
		end
	end
	table.sort(meters)
	return meters
end

-- The sections a song belongs to under a sort: a list of
-- {Key=<section key>, Value=<what the section stands for>, Order=<sort key>}.
local function sectionsOf(mode, song, stepsType)
	local found = {}
	local function add(value, order)
		found[#found+1] = { Key=SECTION_PREFIX .. mode .. ":" .. tostring(value), Value=value, Order=order }
	end
	if mode == "Title" or mode == "Artist" then
		local text = mode == "Title" and call(song, "GetTranslitMainTitle") or call(song, "GetTranslitArtist")
		local value, order = initialOf(text)
		add(value, order)
	elseif mode == "Genre" then
		local genre = tostring(call(song, "GetGenre") or "")
		if genre == "" then add("", "\255") else add(genre, genre:upper()) end
	elseif mode == "BPM" then
		local size = wheelMetric("SortBPMDivision", 20)
		local bpms = call(song, "GetDisplayBpms")
		local high = type(bpms) == "table" and (tonumber(bpms[2]) or tonumber(bpms[1])) or 0
		high = math.max(0, math.floor(high or 0))
		high = high + (size - (high % size) - 1)
		add(high - (size - 1), high)
	elseif mode == "Length" then
		local size = wheelMetric("SortLengthDivision", 60)
		local seconds = math.max(0, math.floor(tonumber(call(song, "MusicLengthSeconds")) or 0))
		seconds = seconds + (size - (seconds % size) - 1)
		add(seconds - (size - 1), seconds)
	elseif mode == "Meter" then
		for _, meter in ipairs(chartMeters(song, stepsType)) do add(meter, meter) end
	end
	return found
end

local function orderBefore(a, b)
	if type(a) ~= type(b) then return type(a) == "number" end
	return a < b
end

local function buildSections(mode, stepsType)
	local result = { mode=mode, stepsType=stepsType, list={}, byKey={} }
	local ok, songs = pcall(function() return SONGMAN:GetAllSongs() end)
	if not ok or type(songs) ~= "table" then return result end
	for _, song in ipairs(songs) do
		if isPlayable(song, stepsType) and not (VOLT26.Secret and VOLT26.Secret.IsHiddenSong(song)) then
			for _, section in ipairs(sectionsOf(mode, song, stepsType)) do
				local entry = result.byKey[section.Key]
				if not entry then
					entry = { Name=section.Key, Kind=mode, Value=section.Value, Order=section.Order,
						Songs=0, members={} }
					result.byKey[section.Key] = entry
					result.list[#result.list+1] = entry
				end
				entry.Songs = entry.Songs + 1
				entry.members[#entry.members+1] = song
			end
		end
	end
	table.sort(result.list, function(a, b)
		if a.Order ~= b.Order then return orderBefore(a.Order, b.Order) end
		return a.Name < b.Name
	end)
	return result
end

-- The current sort's sections: {mode=, list={entry...}, byKey={key=entry}}.
-- An entry is {Name=<key>, Kind=<mode>, Value=, Songs=<count>, members=<songs>}.
function PackSelection.Sections()
	local mode = PackSelection.Mode()
	local stepsType = currentStepsType()
	if not sectionCache or sectionCache.mode ~= mode or sectionCache.stepsType ~= stepsType then
		sectionCache = buildSections(mode, stepsType)
	end
	return sectionCache
end

function PackSelection.ForgetSections()
	sectionCache = nil
end

local function entryFor(key)
	if not PackSelection.IsSection(key) then return nil end
	return PackSelection.Sections().byKey[key]
end

-- The section (or pack) a song is listed under right now.  A song in several
-- sections (meter sort) answers the one last opened when it is one of them.
function PackSelection.KeyForSong(song)
	if not song then return nil end
	local mode = PackSelection.Mode()
	if mode == "Pack" then
		local ok, group = pcall(function() return song:GetGroupName() end)
		return ok and group or nil
	end
	local found = sectionsOf(mode, song, currentStepsType())
	local last = PackSelection.LastSection[mode]
	for _, section in ipairs(found) do
		if section.Key == last then return last end
	end
	return found[1] and found[1].Key or nil
end

local function mmss(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function text(key)
	return THEME:GetString("VOLT26MusicSelect", key)
end

-- The name a pack or section is shown by (under the splash on the pack step).
-- Takes a list entry or a key.
function PackSelection.DisplayName(entryOrKey)
	local entry = type(entryOrKey) == "table" and entryOrKey or entryFor(entryOrKey)
	if not entry then return tostring(type(entryOrKey) == "table" and entryOrKey.Name or entryOrKey or "") end
	if not entry.Kind or entry.Kind == "Pack" then return entry.Name end
	local v = entry.Value
	if entry.Kind == "Title" or entry.Kind == "Artist" then
		return string.format(text("Section" .. entry.Kind), v ~= "" and v or text("SectionOther"))
	elseif entry.Kind == "Genre" then
		return v ~= "" and v or text("SectionNoGenre")
	elseif entry.Kind == "BPM" then
		return string.format(text("SectionBPM"), v, v + wheelMetric("SortBPMDivision", 20) - 1)
	elseif entry.Kind == "Length" then
		return string.format(text("SectionLength"), mmss(v), mmss(v + wheelMetric("SortLengthDivision", 60) - 1))
	elseif entry.Kind == "Meter" then
		return string.format(text("SectionMeter"), v)
	end
	return tostring(v)
end

-- The few characters a section's tile shows in place of artwork, or nil for
-- a pack (whose tile shows its initials until the artwork loads).
function PackSelection.ShortName(key)
	local entry = entryFor(key)
	if not entry then return nil end
	local v = entry.Value
	if entry.Kind == "Title" or entry.Kind == "Artist" then
		return v ~= "" and v or text("SectionOtherShort")
	elseif entry.Kind == "Genre" then
		return v ~= "" and v or text("SectionNoGenreShort")
	elseif entry.Kind == "BPM" then
		return string.format("%d-%d", v, v + wheelMetric("SortBPMDivision", 20) - 1)
	elseif entry.Kind == "Length" then
		return mmss(v)
	end
	return tostring(v)
end

-- Opening a section: like Choose for a pack, a song of the section is made
-- current and the wheel opens on that song's section.  Under the meter sort a
-- song sits in several sections and the wheel opens the first one (its
-- lowest meter), so a song whose lowest meter is the chosen one is preferred;
-- the meter is also kept for OpenChosenSection in case the wheel still opens
-- elsewhere.
function PackSelection.ChooseSection(key)
	local entry = entryFor(key)
	if not entry or #entry.members == 0 then return false end
	local stepsType = currentStepsType()

	local target
	local current = GAMESTATE:GetCurrentSong()
	if current then
		for _, song in ipairs(entry.members) do
			if song == current then target = current break end
		end
	end

	if not target then
		local bestKey, bestFits
		for _, song in ipairs(entry.members) do
			local fits = true
			if entry.Kind == "Meter" then fits = chartMeters(song, stepsType)[1] == entry.Value end
			local k = titleKey(song)
			if not target or (fits and not bestFits) or (fits == bestFits and k < bestKey) then
				target, bestKey, bestFits = song, k, fits
			end
		end
	end

	GAMESTATE:SetPreferredSong(target)
	GAMESTATE:SetCurrentSong(target)
	PackSelection.LastSection[entry.Kind] = key
	if entry.Kind == "Meter" then PackSelection.wheelSection = tostring(entry.Value) end
	return true
end

-- Called by the song wheel once it is built: when the wheel opened on another
-- section than the one chosen (meter sort only), it is moved to the chosen
-- one.  Answers whether it had to.
function PackSelection.OpenChosenSection(wheel)
	local wanted = PackSelection.wheelSection
	PackSelection.wheelSection = nil
	if not wanted or not wheel then return false end
	local ok, open = pcall(function() return wheel:GetSelectedSection() end)
	if ok and open == wanted then return false end
	return (pcall(function() wheel:SetOpenSection(wanted) end))
end

------------------------------------------------------------------------------
-- What a section row of the song wheel holds (the Simply Love layout's pack
-- preview, BGAnimations/ScreenSelectMusic overlay/SongWheel/PackPreview.lua).

-- Series (collections of packs, ITGmania's Group.ini "Series") to their packs
-- in name order, worked out once from the first song of every pack.
local function seriesMap()
	if seriesCache then return seriesCache end
	seriesCache = {}
	local ok, names = pcall(function() return SONGMAN:GetSongGroupNames() end)
	if not ok or type(names) ~= "table" then return seriesCache end
	for _, name in ipairs(names) do
		local song = songsInGroup(name)[1]
		if song then
			local okSeries, series = pcall(function()
				local group = SONGMAN:GetGroup(song)
				return group and group:GetSeries() or nil
			end)
			if okSeries and type(series) == "string" and series ~= "" then
				seriesCache[series] = seriesCache[series] or {}
				local packs = seriesCache[series]
				packs[#packs+1] = name
			end
		end
	end
	for _, packs in pairs(seriesCache) do
		table.sort(packs, function(a, b)
			local ka, kb = nameKey(a), nameKey(b)
			if ka ~= kb then return ka < kb end
			return a < b
		end)
	end
	return seriesCache
end

-- The packs of a series, in name order (an empty list for an unknown one).
function PackSelection.SeriesPacks(series)
	return seriesMap()[series] or {}
end

-- Whether a section row of the wheel names a series (a collection of packs)
-- rather than a pack.
function PackSelection.IsSeries(name)
	if type(name) ~= "string" or name == "" or #songsInGroup(name) > 0 then return false end
	return #PackSelection.SeriesPacks(name) > 0
end

local function sortedByTitle(songs)
	local list, keys = {}, {}
	for _, song in ipairs(songs) do
		list[#list+1] = song
		keys[song] = titleKey(song)
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then return keys[a] < keys[b] end
		return tostring(a) < tostring(b)
	end)
	return list
end

-- The section of the current sort that the wheel names `name`, matched by
-- what it stands for (the engine and this module name some sections apart:
-- "OTHER" against "", "120-129" against 120...).
local function sortSectionNamed(name)
	local wanted = nameKey(name)
	for _, entry in ipairs(PackSelection.Sections().list) do
		local short = PackSelection.ShortName(entry.Name)
		if nameKey(entry.Value) == wanted or nameKey(short) == wanted
			or nameKey(PackSelection.DisplayName(entry)) == wanted then
			return entry
		end
	end
	return nil
end

-- What a section row of the song wheel holds, for a preview of it:
--   {Kind="Series", Name=, Packs={pack names}, Songs=<number of songs>}
--     for a parent section (isParent true): a series of packs;
--   {Kind="Pack", Name=, Songs={songs}}       for a pack;
--   {Kind="Section", Name=, Songs={songs}}    for a section of another sort
--     (an initial, a genre, a BPM range...), when it can be matched.
-- Songs are in title order and limited to the current style's playable ones
-- when the style is known.  Cached per sort and style until List() runs.
function PackSelection.WheelSectionContents(name, isParent)
	if type(name) ~= "string" or name == "" then return nil end
	local stepsType = currentStepsType()
	local key = table.concat({ tostring(isParent), currentSort(), tostring(stepsType), name }, "|")
	if contentsCache[key] then return contentsCache[key] end

	local contents
	if isParent then
		local packs = PackSelection.SeriesPacks(name)
		local total = 0
		for _, pack in ipairs(packs) do total = total + #songsInGroup(pack) end
		contents = { Kind="Series", Name=name, Packs=packs, Songs=total }
	else
		local songs, kind = songsInGroup(name), "Pack"
		if #songs == 0 and PackSelection.Mode() ~= "Pack" then
			local entry = sortSectionNamed(name)
			songs, kind = entry and entry.members or {}, "Section"
		end
		local playable = {}
		for _, song in ipairs(songs) do
			if isPlayable(song, stepsType) then playable[#playable+1] = song end
		end
		contents = { Kind=kind, Name=name, Songs=sortedByTitle(playable) }
	end
	contentsCache[key] = contents
	return contents
end
