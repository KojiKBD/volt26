-- The cursor state behind ScreenSelectProfile's card strip.
--
-- The screen used to browse profiles with a sick_wheel, which owns its own
-- focus position and scroll offset.  A strip of cards needs neither: it needs
-- to know which item each player is on, which slice of the list is on screen,
-- and whether a player has committed.  That is all this file holds, so the
-- frames can stay pure presentation and Input.lua can stay pure input.
--
-- Item 1 is always "[ GUEST ]", which carries the engine index 0; real local
-- profiles follow in PROFILEMAN's order, carrying their own 1-based engine
-- index.  Nothing here talks to the engine -- the screen translates an item's
-- index into SetProfileIndex() when it finishes.

local args = ...
local profile_data = args.ProfileData

local Selection = {}

local items = {
	{ index = 0, displayname = THEME:GetString("ScreenSelectProfile", "GuestProfile"), guest = true },
}
for profile in ivalues(profile_data) do
	items[#items+1] = profile
end

local cursor = { [PLAYER_1] = 1, [PLAYER_2] = 1 }
local ready  = { [PLAYER_1] = false, [PLAYER_2] = false }

-- ----------------------------------------------------------------------------

function Selection.Count() return #items end

function Selection.Item(i) return items[i] end

function Selection.Cursor(player) return cursor[player] or 1 end

function Selection.Get(player) return items[Selection.Cursor(player)] end

-- Returns true when the cursor actually moved, so the caller can tell a refused
-- move (the end of the list) from an accepted one and sound it differently.
function Selection.Move(player, delta)
	local target = Selection.Cursor(player) + delta
	if target < 1 or target > #items then return false end
	cursor[player] = target
	return true
end

function Selection.SetCursor(player, i)
	if type(i) ~= "number" then return end
	cursor[player] = clamp(i, 1, #items)
end

-- Put a player on the item carrying a given engine profile index, if it is
-- present.  Used to open the screen on a player's current or default profile.
function Selection.FocusEngineIndex(player, index)
	for i, item in ipairs(items) do
		if item.index == index then cursor[player] = i; return true end
	end
	return false
end

function Selection.FocusProfileDir(player, dir)
	if type(dir) ~= "string" or dir == "" then return false end
	for i, item in ipairs(items) do
		if item.dir == dir then cursor[player] = i; return true end
	end
	return false
end

function Selection.IsReady(player) return ready[player] == true end

function Selection.SetReady(player, value) ready[player] = (value == true) end

-- The slice of the list that is on screen: the window only moves when the
-- cursor would leave it, so the cards stay put while a player moves between
-- the ones already in front of them.
local window = { [PLAYER_1] = 1, [PLAYER_2] = 1 }

function Selection.Window(player, visible)
	local position = Selection.Cursor(player)
	local start = window[player] or 1

	if position < start then start = position end
	if position > start + visible - 1 then start = position - visible + 1 end

	start = clamp(start, 1, math.max(#items - visible + 1, 1))
	window[player] = start
	return start
end

-- True when there are items outside the window on that side, so the frame can
-- show that the strip continues.
function Selection.HasMore(player, visible, direction)
	local start = window[player] or 1
	if direction < 0 then return start > 1 end
	return start + visible - 1 < #items
end

return Selection
