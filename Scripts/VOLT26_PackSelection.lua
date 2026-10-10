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

VOLT26.PackSelection = VOLT26.PackSelection or {}
local PackSelection = VOLT26.PackSelection

-- Artwork and summaries are cached per pack for as long as the theme stays
-- loaded.  ScreenReloadSongs rebuilds the song list, so PackSelection.List()
-- clears both caches whenever the pack screen asks for a fresh list.
local artworkCache = {}
local summaryCache = {}

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

local function songsInGroup(group)
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
	if song then
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
	local cached = artworkCache[group]
	if cached ~= nil then return cached or nil end

	local art = false
	local jacket = engineJacket(group) or findJacketFile(packDirectory(group))
	if usablePath(jacket) then
		art = { Path=jacket, Kind="Jacket" }
	else
		local banner = groupBanner(group)
		if banner then art = { Path=banner, Kind="Banner" } end
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

	local songs = songsInGroup(group)
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

-- Hands the chosen pack to the engine.  The MusicWheel opens on the preferred
-- song's section, so the pack is chosen by choosing one of its songs: the song
-- already current when it belongs to this pack (coming back to a pack lands on
-- the song that was left), otherwise the pack's first playable song by title.
-- Answers whether a song was found.
function PackSelection.Choose(group)
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
	return direction
end
