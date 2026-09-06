-- =====================================================================
-- VOLT26 Player Messages
-- -----------------------------------------------------------------------
-- Feeds player "name: message" lines into the title-screen tagline shown
-- by VOLT26.Brand.RandomTagline().
--
-- Source: a plain local text file, Other/PlayerMessages.txt, one message
-- per line, format:
--     Name: message text goes here
-- Blank lines and lines without a ":" are ignored. Edit that file with
-- any text editor -- changes take effect the next time you visit the
-- title screen (see the Load() call in
-- "ScreenTitleMenu underlay/default.lua").
--
-- History: this originally fetched the same data live from a Google
-- Sheet over HTTP. ITGmania blocks outbound Lua HTTP requests to any
-- host not listed in the "HttpAllowHosts" preference in Preferences.ini
-- (default: only *.groovestats.com and *.itgmania.com), so every request
-- to docs.google.com came back as HttpErrorCode_Blocked. That preference
-- is only editable by hand in Preferences.ini (by design -- a theme
-- can't grant itself network access), which was more friction than it
-- was worth, so we moved to this local-file approach instead. The
-- Google Sheet can stay in use as the "master copy"; just copy/export its
-- rows into Other/PlayerMessages.txt when you want to update the theme.
--
-- TODO (intentionally deferred): some player messages run longer than
-- the tagline box (maxwidth 405 @ zoom 0.82 on the EventPhrase font). A
-- marquee/scrolling effect for long messages is planned but NOT
-- implemented yet -- long text just relies on maxwidth's normal
-- auto-shrink behavior for now.
-- =====================================================================

VOLT26.PlayerMessages = {
	FileName = "PlayerMessages.txt", -- lives in this theme's Other/ folder

	List = {},       -- {{name=..., message=...}, ...} currently in use
	Loaded = false,  -- true once List has at least one real entry
}

local PM = VOLT26.PlayerMessages

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ParseLine(line)
	local colon = line:find(":", 1, true)
	if not colon then return nil end
	local name = Trim(line:sub(1, colon - 1))
	local message = Trim(line:sub(colon + 1))
	if name == "" or message == "" then return nil end
	return { name = name, message = message }
end

-- ---------------------------------------------------------------------
-- (Re)reads Other/PlayerMessages.txt from disk. Safe to call as often as
-- you like (e.g. every title-screen visit) -- it's a small local text
-- file, not a network request.
-- ---------------------------------------------------------------------
function PM.Load()
	local path = THEME:GetPathO("", PM.FileName)
	if not path or path == "" or not FILEMAN:DoesFileExist(path) then
		Trace("[VOLT26.PlayerMessages] no file at Other/" .. PM.FileName .. "; using built-in fallback taglines")
		return
	end

	local f = RageFileUtil:CreateRageFile()
	local raw = nil
	if f:Open(path, 1) then
		raw = f:Read()
		f:Close()
	end
	f:destroy()

	if not raw or raw == "" then return end

	local list = {}
	for line in (raw .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
		local entry = ParseLine(line)
		if entry then list[#list + 1] = entry end
	end

	if #list > 0 then
		PM.List = list
		PM.Loaded = true
		Trace(("[VOLT26.PlayerMessages] loaded %d message(s) from Other/%s"):format(#list, PM.FileName))
	end
end

-- Returns "NAME: message", or nil if we have no player messages (yet),
-- in which case the caller should fall back to the built-in taglines.
function PM.RandomLine()
	if #PM.List == 0 then return nil end
	local entry = PM.List[math.random(#PM.List)]
	return entry.name .. ": " .. entry.message
end

do
	local ok, err = pcall(PM.Load)
	if not ok then
		Trace("[VOLT26.PlayerMessages] Load() threw an error at boot: " .. tostring(err))
	end
end
