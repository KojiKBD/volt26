-- VOLT26.Secret: the hidden song, "Are you LOST?".
--
-- In Event Mode, on the song select, the pad's left and right arrows pressed
-- together five times in a row start a song nobody can find on the wheel (with
-- dedicated menu buttons no other code uses the pair; the four arrows were
-- dropped because many keyboards cannot report four keys at once), for every joined
-- player.  Gameplay starts at once, without the usual lead-in naming the pack
-- (ScreenGameplay in), and "Are you LOST?" covers the screen on black while
-- the music plays its first seconds, before the first arrow (ScreenGameplay
-- overlay/SecretStinger.lua).
--
-- The song ships inside the theme (Other/VOLT26 Secret/LosT: the simfile with
-- #SELECTABLE:NO, so the engine never lists it, and its music).  ITGmania only
-- loads songs from its song folders, so on startup the theme copies it into
-- Songs/VOLT26 Secret/LosT (again whenever the theme's copy changes) and, when
-- it had to copy, reloads the songs once (ScreenVOLT26SecretReload) before
-- going on.  The engine keeps unselectable songs off the wheel; the theme's own
-- lists (pack carousel, pack previews, song search, sort menu counts) leave
-- the group out through IsHiddenGroup / IsHiddenSong.
--
-- Behaviour only: the song select overlay feeds its input to Feed and calls
-- Start; ScreenGameplay's in and overlay present the stinger.

VOLT26.Secret = VOLT26.Secret or {}
local Secret = VOLT26.Secret

Secret.Group = "VOLT26 Secret"
Secret.Folder = "LosT"
-- The song and, beside it, its synced lyrics (shown by ScreenGameplay
-- underlay/Secret.lua).  A missing lyrics file is simply not shown.
Secret.Files = { "LosT.ssc", "LosT.ogg", "LosT.lrc" }
Secret.LyricsFile = "LosT.lrc"
-- Seconds added to every lyrics time (the .lrc follows the released track;
-- the chart's music is cut from it: owner's sync, every line 3.8 s earlier).
Secret.LyricsOffset = -3.8
Secret.Difficulty = "Difficulty_Challenge"
Secret.Presses = 5          -- left+right presses in a row
Secret.Window = 2.0         -- longest pause between two of them, in seconds
-- Traces every arrow the song select feeds to the log (for testing).
Secret.Debug = true

-- The arrows that must be down together.
local ARROWS = { "Left", "Right" }
local isArrow = { Left = true, Right = true }

local function sourceDir()
	return THEME:GetCurrentThemeDirectory() .. "Other/" .. Secret.Group .. "/" .. Secret.Folder .. "/"
end

local function targetDir()
	return "/Songs/" .. Secret.Group .. "/" .. Secret.Folder .. "/"
end

-- Installing ----------------------------------------------------------------

-- The whole file, or nil.
local function contents(path)
	local f = RageFileUtil.CreateRageFile()
	local data = nil
	if f:Open(path, 1) then data = f:Read() end
	f:Close()
	f:destroy()
	return data
end

-- Whether the installed copy matches the theme's.  FILEMAN:GetHashForFile
-- differs between identical files in two places, so small files (the
-- simfile, where an edit may keep the size) are compared whole and the
-- music by size.
local SMALL = 256 * 1024
local function sameFile(a, b)
	if not FILEMAN:DoesFileExist(b) then return false end
	local size = FILEMAN:GetFileSizeBytes(a)
	if size ~= FILEMAN:GetFileSizeBytes(b) then return false end
	if size > SMALL then return true end
	local data = contents(a)
	return data ~= nil and data == contents(b)
end

-- Copies the theme's song into the song folder where it is missing or
-- different.  Answers whether a file the engine loads (the simfile or the
-- music, not the lyrics the theme reads itself) was copied.
function Secret.Install()
	local copied = false
	for _, name in ipairs(Secret.Files) do
		local from, to = sourceDir() .. name, targetDir() .. name
		if FILEMAN:DoesFileExist(from) and not sameFile(from, to) then
			if FILEMAN:Copy(from, to) then
				if name ~= Secret.LyricsFile then copied = true end
			else
				Warn("VOLT26.Secret: could not copy " .. from .. " to " .. to)
			end
		end
	end
	return copied
end

function Secret.Song()
	local ok, song = pcall(function() return SONGMAN:FindSong(Secret.Group .. "/" .. Secret.Folder) end)
	return ok and song or nil
end

-- Where the warm-up goes (ScreenVOLT26Warmup overlay): install the song, and
-- reload the songs once when the copy on disk is not the loaded one.  A song
-- the engine has not loaded at all only needs the new folders read
-- (ScreenVOLT26SecretReload, OnlyLoadAdditions); a song that changed needs a
-- full reload (ScreenVOLT26SecretReloadAll).  Either is tried once per run, so
-- a copy that cannot be loaded never loops.
--
-- Right after a copy the file manager's cached listing may not show the new
-- files yet, so a copy made now counts as being on disk.
function Secret.AfterWarmup()
	local ok, copied = pcall(Secret.Install)
	if not ok then
		Warn("VOLT26.Secret: " .. tostring(copied))
		copied = false
	end
	local onDisk = copied or FILEMAN:DoesFileExist(targetDir() .. Secret.Files[1])
	local loaded = Secret.Song() ~= nil
	Trace(("VOLT26.Secret: copied=%s onDisk=%s loaded=%s"):format(tostring(copied), tostring(onDisk), tostring(loaded)))
	if Secret.reloaded or not onDisk then return "ScreenInit" end
	if not loaded then
		Secret.reloaded = true
		return "ScreenVOLT26SecretReload"
	end
	if copied then
		Secret.reloaded = true
		return "ScreenVOLT26SecretReloadAll"
	end
	return "ScreenInit"
end

-- Hiding ----------------------------------------------------------------------

function Secret.IsHiddenGroup(name)
	return name == Secret.Group
end

function Secret.IsHiddenSong(song)
	if not song then return false end
	local ok, group = pcall(function() return song:GetGroupName() end)
	return ok and group == Secret.Group
end

-- The code --------------------------------------------------------------------

local held, count, last = {}, {}, {}

function Secret.ResetInput()
	held, count, last = {}, {}, {}
end

function Secret.IsAvailable()
	return PREFSMAN:GetPreference("EventMode") == true and not GAMESTATE:IsCourseMode()
		and Secret.Song() ~= nil
end

-- Feeds one input event of the song select.  Each moment both arrows of a
-- player are down counts once; any other button starts the count over.
-- Answers true when the code is complete.
function Secret.Feed(event)
	if not event or not event.PlayerNumber then return false end
	-- ITGmania names the pad arrow in `button` ("Left", "Right"); GameButton
	-- can come empty.
	local button = event.button
	if not isArrow[button] and event.GameButton and event.GameButton ~= "" then button = event.GameButton end
	local pn = event.PlayerNumber
	held[pn] = held[pn] or {}
	if event.type == "InputEventType_Release" then
		if isArrow[button] then held[pn][button] = nil end
		return false
	end
	if event.type ~= "InputEventType_FirstPress" then return false end
	if not isArrow[button] then
		count[pn] = 0
		return false
	end
	held[pn][button] = true
	local down = {}
	for _, arrow in ipairs(ARROWS) do
		if held[pn][arrow] then down[#down+1] = arrow end
	end
	if Secret.Debug then
		Trace(("VOLT26.Secret: %s %s, held %s"):format(ToEnumShortString(pn), button, table.concat(down, "+")))
	end
	if #down < #ARROWS then return false end
	local now = GetTimeSinceStart()
	if last[pn] and now - last[pn] > Secret.Window then count[pn] = 0 end
	last[pn] = now
	count[pn] = (count[pn] or 0) + 1
	if Secret.Debug then
		Trace(("VOLT26.Secret: left+right, %d of %d"):format(count[pn], Secret.Presses))
	end
	if count[pn] < Secret.Presses then return false end
	Secret.ResetInput()
	local available = Secret.IsAvailable()
	Trace(("VOLT26.Secret: code entered, eventMode=%s song=%s"):format(
		tostring(PREFSMAN:GetPreference("EventMode")), tostring(Secret.Song() ~= nil)))
	return available
end

-- Starting --------------------------------------------------------------------

local function chartFor(song)
	local style = GAMESTATE:GetCurrentStyle()
	local stepsType = style and style:GetStepsType() or nil
	if not stepsType then return nil end
	local ok, steps = pcall(function() return song:GetOneSteps(stepsType, Secret.Difficulty) end)
	if ok and steps then return steps end
	local okAll, all = pcall(function() return song:GetStepsByStepsType(stepsType) end)
	return okAll and type(all) == "table" and all[1] or nil
end

-- Makes the hidden song and its chart current for every joined player.  The
-- song the players were on is kept, to be put back when they return to the
-- song select (RestoreSong).  Answers whether the song can start (it has no
-- chart for a style it was not made for, such as double).
function Secret.Start()
	local song = Secret.Song()
	if not song then return false end
	local steps = chartFor(song)
	if not steps then
		Trace("VOLT26.Secret: no chart of the hidden song for the current style")
		return false
	end
	local current = GAMESTATE:GetCurrentSong()
	if current and not Secret.IsHiddenSong(current) then Secret.returnSong = current end
	GAMESTATE:SetCurrentSong(song)
	for _, player in ipairs(GAMESTATE:GetHumanPlayers()) do
		GAMESTATE:SetCurrentSteps(player, steps)
	end
	MESSAGEMAN:Broadcast("SongSelected")
	return true
end

-- Called as the song select starts: the wheel cannot show the hidden song, so
-- the one the players left is made current again.
function Secret.RestoreSong()
	if not Secret.IsHiddenSong(GAMESTATE:GetCurrentSong()) then return end
	local song = Secret.returnSong
	GAMESTATE:SetCurrentSong(song)
	if song then GAMESTATE:SetPreferredSong(song) end
end

-- Lyrics ------------------------------------------------------------------------

local lyricsCache = nil

-- The hidden song's lyrics from its .lrc ("[mm:ss.xx]line" per line; an
-- empty line clears the screen): a list of {Time=<song seconds>, Text=} in
-- time order, or an empty list when there is no file.  Read once.
function Secret.Lyrics()
	if lyricsCache then return lyricsCache end
	lyricsCache = {}
	local song = Secret.Song()
	local dir = song and song:GetSongDir() or targetDir()
	local data = contents(dir .. Secret.LyricsFile)
	if not data then return lyricsCache end
	for line in (data .. "\n"):gmatch("([^\r\n]*)\r?\n") do
		local m, sec, text = line:match("^%[(%d+):(%d+%.?%d*)%](.*)$")
		if m then
			lyricsCache[#lyricsCache+1] = {
				Time = tonumber(m) * 60 + tonumber(sec) + Secret.LyricsOffset,
				Text = (text:gsub("^%s+", ""):gsub("%s+$", "")),
			}
		end
	end
	table.sort(lyricsCache, function(a, b) return a.Time < b.Time end)
	return lyricsCache
end

-- The index of the line on screen at song time `t` (0 before the first).
function Secret.LyricIndexAt(t)
	local lines, index = Secret.Lyrics(), 0
	for i, line in ipairs(lines) do
		if line.Time <= t then index = i else break end
	end
	return index
end
