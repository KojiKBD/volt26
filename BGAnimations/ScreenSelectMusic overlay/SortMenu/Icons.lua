-- Which icon each dock tile carries.
--
-- The tiles are keyed by the option's own name -- the same key the input
-- handler branches on -- so a new option gets an icon by naming it here and
-- nothing has to be kept in step anywhere else.  An option with no entry falls
-- back to the neutral mark rather than drawing nothing, which would leave a
-- tile that looks broken instead of merely generic.
--
-- The files are white line art on transparency, drawn at 192px square, so a
-- tile tints them with diffuse and scales them down rather than shipping one
-- bitmap per state.

local Icons = {}

local folder = "VOLT26/SortMenu/"

local byKey = {
	GoBack            = "back",
	SwitchProfile     = "profile",
	Leaderboard       = "trophy",
	SongSearch        = "search",
	AddFavorite       = "favorite",
	Preferred         = "heart",
	Nonstop           = "marathon",
	Regular           = "marathon",
	CategorySorts     = "sorts",
	CategoryProfile   = "player",
	CategoryAdvanced  = "advanced",
	CategoryStyles    = "styles",
	CategoryPlaylists = "playlists",
}

Icons.Fallback = "dot"

function Icons.Name(key)
	return byKey[key] or Icons.Fallback
end

function Icons.Path(name)
	return THEME:GetPathG("", folder .. (name or Icons.Fallback))
end

-- Every icon the dock can ask for, so a tile can be built with one of them and
-- swap texture later without the engine loading a file mid-frame.
function Icons.All()
	local seen, list = {}, {Icons.Fallback}
	seen[Icons.Fallback] = true
	for _, name in pairs(byKey) do
		if not seen[name] then
			seen[name] = true
			list[#list+1] = name
		end
	end
	return list
end

return Icons
