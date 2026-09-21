-- VOLT26 CORE: Music selection state and song-browsing policy.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.MusicSelection = {}

-- Song Select wheel geometry, in the screen's virtual 1920x1080 design space.
-- The Song Select composition positions the wheel from these figures and
-- Graphics/VOLT26/SongSelection/MusicWheelItemNative.lua draws each row from
-- them, so the rail, the rows and the sticky pack heading cannot drift apart.
-- X is the column's left edge; GuideOffset places the rail the dots sit on and
-- is the wheel's own origin; ItemOffset places the left edge of a row's body.
-- The column stands in the middle of the screen, so each player reads their own
-- side of it instead of looking across the other's.
VOLT26.MusicSelection.Wheel = {
	X = 640,
	Width = 640,
	GuideOffset = 5,
	ItemOffset = 22,
	Pitch = 68,
	ItemHeight = 62,
}

-- Every row keeps the same pitch and the selection stays on the wheel's centre,
-- so scrolling moves the list past a fixed highlight rather than moving the
-- highlight.  MusicWheel's own SwitchSeconds does the damping.
function VOLT26.MusicSelection.PositionWheelItem(self, offsetFromCenter)
	self.VOLT26Offset = offsetFromCenter
	self:y(offsetFromCenter * VOLT26.MusicSelection.Wheel.Pitch)
end

function VOLT26.MusicSelection.GetMusicRate()
	return VOLT26.MusicSelection.NormalizeMusicRate(VOLT26.State.Global.ActiveModifiers.MusicRate)
end

function VOLT26.MusicSelection.NormalizeMusicRate(value)
	local rate = tonumber(value)
	return rate and rate > 0 and rate or 1
end

function VOLT26.MusicSelection.PrepareScreen()
	VOLT26.State.Global.GameplayReloadCheck = false
	VOLT26.Tournament.RestoreAllPlayers()
	VOLT26.Favorites.LoadAll()
	GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(VOLT26.MusicSelection.GetMusicRate())
end

function VOLT26.MusicSelection.RefreshPlayer(player, rebuildFavorites)
	if not PROFILEMAN:IsPersistentProfile(player) then
		VOLT26.Profile.LoadGuest(player)
	end
	if rebuildFavorites then
		VOLT26.Favorites.LoadAll()
	end
	ApplyMods(player)
end

VOLT26.SongBrowsing = {}

local songBrowsingActions = {
	AddFavorite = true,
	ChangePlayMode = true,
	ChangeStyle = true,
	MachinePlaylist = true,
	PersonalPlaylist = true,
	Preferred = true,
	QuickMods = true,
	SetSummary = true,
	SongSearch = true,
	SortBy = true,
	SwitchProfile = true,

	-- These inherited integrations remain installed but are not exposed until
	-- their owning inventory capabilities are explicitly accepted.
	Leaderboard = true,
	LoadNewSongs = false,
	OnlineLobbies = true,
	PracticeMode = false,
	TestInput = true,
	ViewDownloads = true,
}

function VOLT26.SongBrowsing.IsActionEnabled(action)
	return songBrowsingActions[action] == true
end

function VOLT26.SongBrowsing.GetBpmTier(bpm)
	return math.floor((bpm + 0.5) / 10) * 10
end

function VOLT26.SongBrowsing.ParseSearch(input)
	if type(input) ~= "string" or #input == 0 then return nil end

	local normalized = input:lower()
	local difficulty
	local bpmTier

	for match in normalized:gmatch("%[(%d+)]") do
		local value = tonumber(match)
		if value <= 35 then
			difficulty = value
		else
			bpmTier = VOLT26.SongBrowsing.GetBpmTier(value)
		end
	end

	normalized = normalized:gsub("%[%d+]", ""):gsub("^%s*(.-)%s*$", "%1")
	local slash = normalized:find("/", 1, true)
	local packName
	local songName
	if slash then
		packName = normalized:sub(1, slash - 1)
		songName = normalized:sub(slash + 1)
	else
		songName = normalized
	end
	if packName == "" then packName = nil end
	if songName == "" then songName = nil end

	if not (packName or songName or difficulty or bpmTier) then return nil end
	return {
		bpmTier = bpmTier,
		difficulty = difficulty,
		packName = packName,
		songName = songName,
	}
end

function VOLT26.SongBrowsing.Search(input)
	local query = VOLT26.SongBrowsing.ParseSearch(input)
	if not query then return nil end

	local style = GAMESTATE:GetCurrentStyle()
	if not style then return { searchText=input, candidates={} } end
	local stepsType = style:GetStepsType()
	local candidates = {}

	for song in ivalues(SONGMAN:GetAllSongs()) do
		local matches = song:HasStepsType(stepsType)
		if matches and query.songName then
			local displayTitle = song:GetDisplayFullTitle():lower()
			local translitTitle = song:GetTranslitFullTitle():lower()
			matches = displayTitle:find(query.songName, 1, true) ~= nil
				or translitTitle:find(query.songName, 1, true) ~= nil
		end
		if matches and query.packName then
			matches = song:GetGroupName():lower():find(query.packName, 1, true) ~= nil
		end
		if matches and query.difficulty then
			matches = false
			for steps in ivalues(song:GetStepsByStepsType(stepsType)) do
				if steps:GetDifficulty() ~= "Difficulty_Edit" and steps:GetMeter() == query.difficulty then
					matches = true
					break
				end
			end
		end
		if matches and query.bpmTier then
			local bpms = song:GetDisplayBpms()
			local lowBpm = tonumber(bpms[1]) or 0
			local highBpm = tonumber(bpms[2]) or lowBpm
			if highBpm < lowBpm then lowBpm, highBpm = highBpm, lowBpm end
			local lowTier = VOLT26.SongBrowsing.GetBpmTier(lowBpm)
			local highTier = VOLT26.SongBrowsing.GetBpmTier(highBpm)
			matches = lowTier <= query.bpmTier and query.bpmTier <= highTier
		end
		if matches then candidates[#candidates+1] = song end
	end

	return { searchText=input, candidates=candidates }
end

function VOLT26.SongBrowsing.SelectSearchResult(song, screen)
	if not song or not screen then return false end
	GAMESTATE:SetPreferredSong(song)
	local sortOrder = GAMESTATE:GetSortOrder()
	if sortOrder == "SortOrder_Preferred"
		or sortOrder == "SortOrder_Popularity"
		or sortOrder == "SortOrder_Recent" then
		screen:GetMusicWheel():ChangeSort("SortOrder_Group")
	end
	screen:SetNextScreenName("ScreenReloadSSM")
	screen:StartTransitioningScreen("SM_GoToNextScreen")
	return true
end

function VOLT26.SongBrowsing.ChangeSort(order)
	if type(order) ~= "string" or order == "" then return false end
	MESSAGEMAN:Broadcast("Sort", { order=order })
	MESSAGEMAN:Broadcast("ResetHeaderText")
	return true
end

function VOLT26.SongBrowsing.UsePlaylist(path, screen)
	if type(path) ~= "string" or path == "" or not screen then return false end
	SONGMAN:SetPreferredSongs(path, true)
	if not SONGMAN:GetPreferredSortSongs() then return false end
	screen:GetMusicWheel():ChangeSort("SortOrder_Preferred")
	return true
end
