-- Which icon each dock tile carries.
--
-- The tiles are keyed by the option's own name -- the same key the input
-- handler branches on -- so a new option gets an icon by naming it here and
-- nothing has to be kept in step anywhere else.  An option with no entry falls
-- back to the neutral mark rather than drawing nothing, which would leave a
-- tile that looks broken instead of merely generic.
--
-- The icons are the owner's (icons.ai): red cut-paper marks on transparency,
-- 192 px square, each with a "_hover" twin outlined in black that the tile
-- under the cursor shows.  They are drawn in their own colours.  BACK and the
-- neutral mark have no new artwork: they stay white line art, tinted by the
-- tile, and have no hover twin.

local Icons = {}

local folder = "VOLT26/SortMenu/"

local byKey = {
	GoBack            = "back",
	SwitchProfile     = "profile",
	QuickMods         = "mods",
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

-- The icons that are line art to be tinted rather than coloured artwork.
local tinted = { back = true, dot = true }

function Icons.Tinted(name)
	return tinted[name or Icons.Fallback] == true
end

-- The hover twin when there is one, the plain icon otherwise.
function Icons.Path(name, hover)
	name = name or Icons.Fallback
	if hover and not tinted[name] then name = name .. "_hover" end
	return THEME:GetPathG("", folder .. name)
end

-- Every icon file the dock can ask for (hover twins included), so a tile can
-- be built with one of them and swap texture later without the engine loading
-- a file mid-frame.  Entries are paths.
function Icons.All()
	local seen, list = {}, {}
	local function add(name)
		for _, hover in ipairs({false, true}) do
			local path = Icons.Path(name, hover)
			if not seen[path] then
				seen[path] = true
				list[#list+1] = path
			end
		end
	end
	add(Icons.Fallback)
	for _, name in pairs(byKey) do add(name) end
	return list
end

return Icons
