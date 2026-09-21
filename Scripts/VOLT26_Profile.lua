-- VOLT26 CORE: Profile switching and favorites.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.Profile = {
	LoadGuest = LoadGuest,
	LoadCustom = LoadProfileCustom,
	SaveCustom = SaveProfileCustom,
	GetAvatarPath = GetAvatarPath,
	GetPlayerAvatarPath = GetPlayerAvatarPath,
	GetPreferredStyle = function()
		return VOLT26.ThemePrefs.Get("PreferredStyle")
	end,
	IsFastSwitchInProgress = function()
		return VOLT26.State.Global.FastProfileSwitchInProgress == true
	end,
	BeginFastSwitch = function()
		if VOLT26.State.Global.FastProfileSwitchInProgress then return false end
		VOLT26.State.Global.FastProfileSwitchInProgress = true
		return true
	end,
	FinishFastSwitch = function()
		VOLT26.State.Global.FastProfileSwitchInProgress = false
	end,
}

VOLT26.Favorites = {}

local function FavoriteProfileDir(player)
	local index = PlayerNumber:Reverse()[player]
	if index == nil then return nil end
	return PROFILEMAN:GetProfileDir(ProfileSlot[index + 1])
end

local function FavoriteDefaultSection(player)
	local profileName = PROFILEMAN:GetPlayerName(player)
	if not profileName or profileName == "" then profileName = ToEnumShortString(player) end
	return profileName .. "'s Favorites"
end

local function ReadTextFile(path)
	if not path or not FILEMAN:DoesFileExist(path) then return nil end
	return lua.ReadFile(path)
end

local function WriteTextFile(path, contents)
	local file = RageFileUtil.CreateRageFile()
	if not file:Open(path, 2) then
		file:destroy()
		Warn("Could not open '" .. tostring(path) .. "' to write favorites.")
		return false
	end
	file:Write(contents)
	file:Close()
	file:destroy()
	return true
end

function VOLT26.Favorites.GetPath(player)
	local profileDir = FavoriteProfileDir(player)
	return profileDir and (profileDir .. "VOLT26-favorites.txt") or nil
end

function VOLT26.Favorites.GetLegacyPath(player)
	local profileDir = FavoriteProfileDir(player)
	return profileDir and (profileDir .. "favorites.txt") or nil
end

function VOLT26.Favorites.NormalizePath(path)
	if type(path) ~= "string" then return nil end
	local normalized = path:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
	normalized = normalized:gsub("^/+", ""):gsub("/+$", "")
	local parts = {}
	for part in normalized:gmatch("[^/]+") do parts[#parts+1] = part end
	if #parts < 2 then return nil end
	return parts[#parts-1] .. "/" .. parts[#parts]
end

function VOLT26.Favorites.Parse(contents, defaultSection)
	local sections = {}
	local current
	local seen = {}
	defaultSection = defaultSection or "Favorites"

	for rawLine in tostring(contents or ""):gmatch("[^\r\n]+") do
		local line = rawLine:gsub("^%s+", ""):gsub("%s+$", "")
		if line:sub(1, 3) == "---" then
			local name = line:sub(4):gsub("^%s+", ""):gsub("%s+$", "")
			if name == "" then name = defaultSection end
			current = { Name=name, Songs={} }
			sections[#sections+1] = current
		elseif line ~= "" then
			local path = VOLT26.Favorites.NormalizePath(line)
			local key = path and path:lower()
			if path and not seen[key] then
				if not current then
					current = { Name=defaultSection, Songs={} }
					sections[#sections+1] = current
				end
				current.Songs[#current.Songs+1] = path
				seen[key] = true
			end
		end
	end

	return sections
end

function VOLT26.Favorites.Serialize(sections)
	local output = {}
	for section in ivalues(sections or {}) do
		local songs = {}
		for path in ivalues(section.Songs or {}) do songs[#songs+1] = path end
		table.sort(songs, function(a, b)
			local songA = SONGMAN:FindSong(a)
			local songB = SONGMAN:FindSong(b)
			local titleA = songA and songA:GetDisplayMainTitle():lower() or a:lower()
			local titleB = songB and songB:GetDisplayMainTitle():lower() or b:lower()
			if titleA == titleB then return a:lower() < b:lower() end
			return titleA < titleB
		end)
		output[#output+1] = "---" .. tostring(section.Name or "Favorites")
		for path in ivalues(songs) do output[#output+1] = path end
	end
	return #output > 0 and (table.concat(output, "\n") .. "\n") or ""
end

local function ReadFavoriteSections(player)
	local path = VOLT26.Favorites.GetPath(player)
	local legacyPath = VOLT26.Favorites.GetLegacyPath(player)
	local contents = ReadTextFile(path)
	local importedLegacy = false
	if contents == nil then
		contents = ReadTextFile(legacyPath)
		importedLegacy = contents ~= nil
	end
	return VOLT26.Favorites.Parse(contents, FavoriteDefaultSection(player)), contents or "", importedLegacy
end

function VOLT26.Favorites.Load(player)
	local state = VOLT26.Core.GetPlayerState(player)
	state.Favorites = {}
	state.FavoritePaths = {}
	if not PROFILEMAN:IsPersistentProfile(player) then return false end

	local sections, original, importedLegacy = ReadFavoriteSections(player)
	local normalized = VOLT26.Favorites.Serialize(sections)
	if importedLegacy or normalized ~= original then
		WriteTextFile(VOLT26.Favorites.GetPath(player), normalized)
	end

	for section in ivalues(sections) do
		for path in ivalues(section.Songs) do
			local song = SONGMAN:FindSong(path)
			if song then
				state.Favorites[#state.Favorites+1] = song
				state.FavoritePaths[path:lower()] = true
			end
		end
	end
	return true
end

function VOLT26.Favorites.LoadAll()
	for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
		VOLT26.Favorites.Load(player)
	end
end

function VOLT26.Favorites.HasAny(player)
	local state = VOLT26.Core.GetPlayerState(player)
	return state and #state.Favorites > 0
end

function VOLT26.Favorites.HasSong(player, song)
	if not song then return false end
	local path = VOLT26.Favorites.NormalizePath(song:GetSongDir())
	local state = VOLT26.Core.GetPlayerState(player)
	return path ~= nil and state.FavoritePaths[path:lower()] == true
end

function VOLT26.Favorites.Toggle(player, song)
	if not song or not PROFILEMAN:IsPersistentProfile(player) then
		SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", "FavoriteRequiresProfile"))
		return false
	end

	local path = VOLT26.Favorites.NormalizePath(song:GetSongDir())
	if not path then return false end
	local sections = ReadFavoriteSections(player)
	local removed = false
	for section in ivalues(sections) do
		for index=#section.Songs, 1, -1 do
			if section.Songs[index]:lower() == path:lower() then
				table.remove(section.Songs, index)
				removed = true
			end
		end
	end

	if not removed then
		if #sections == 0 then sections[1] = { Name=FavoriteDefaultSection(player), Songs={} } end
		sections[#sections].Songs[#sections[#sections].Songs+1] = path
	end

	if not WriteTextFile(VOLT26.Favorites.GetPath(player), VOLT26.Favorites.Serialize(sections)) then
		SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", "FavoriteSaveFailed"):format(ToEnumShortString(player)))
		return false
	end
	VOLT26.Favorites.Load(player)

	local profileName = PROFILEMAN:GetPlayerName(player)
	if not profileName or profileName == "" then profileName = ToEnumShortString(player) end
	local messageKey = removed and "FavoriteRemoved" or "FavoriteAdded"
	SCREENMAN:SystemMessage(THEME:GetString("ScreenSelectMusic", messageKey):format(song:GetDisplayFullTitle(), profileName))
	SOUND:PlayOnce(THEME:GetPathS("", removed and "Common invalid.ogg" or "_unlock.ogg"))
	return true
end

function VOLT26.Favorites.ToggleCurrent(player)
	return VOLT26.Favorites.Toggle(player, GAMESTATE:GetCurrentSong())
end
