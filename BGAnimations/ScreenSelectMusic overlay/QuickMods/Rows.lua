-- What the Quick Mods menu can offer, and what changing each row actually does.
--
-- Every row is one definition: the word on the left, the reading on the right,
-- and what a press of left or right performs.  A row writes the player's own
-- modifier table and pushes the result straight into the engine, because the
-- point of this menu is that the preview beside it is already showing the new
-- setting -- there is nothing to confirm later.
--
-- Which rows appear, and in what order, is the operator's choice: see
-- ./Other/QuickMods.lua.  Anything named there that is not defined here is
-- ignored rather than drawn as a broken row.

local Rows = {}

local speedBounds = {
	X = {Upper = 20,   Step = 0.05},
	C = {Upper = 2000, Step = 5},
	M = {Upper = 2000, Step = 5},
}

local speedTypes = {"X", "C", "M"}

local function mods(player)
	return VOLT26.Options.GetPlayerModifiers(player)
end

local function playerOptions(player)
	return GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
end

local function indexOf(list, value)
	for i, entry in ipairs(list) do
		if entry == value then return i end
	end
	return nil
end

local function step(list, value, delta)
	local index = indexOf(list, value) or 1
	return list[(index - 1 + delta) % #list + 1]
end

-- The word on the left of a row.  The theme's own short label wins, because an
-- option title written for a full screen -- "Type of Speed Mod" -- is longer
-- than this menu has room for; the options screen's title is the fallback so a
-- row added later still reads in every language that has one.
local function title(key)
	if THEME:HasString("ScreenSelectMusic", "QuickMods" .. key) then
		return THEME:GetString("ScreenSelectMusic", "QuickMods" .. key)
	end
	if THEME:HasString("OptionTitles", key) then
		return THEME:GetString("OptionTitles", key)
	end
	return key
end

-- Both sides of a shared-sides style read and write one set of modifiers, so a
-- change made by either player lands on both.
local function sharedSides()
	local style = GAMESTATE:GetCurrentStyle()
	return style and style:GetStyleType() == "StyleType_TwoPlayersSharedSides"
end

local function peers(player)
	if not sharedSides() then return {player} end
	return GAMESTATE:GetHumanPlayers()
end

-- ----------------------------------------------------------------- speed

local function applySpeed(player)
	local m = mods(player)
	local kind = m.SpeedModType or "X"
	playerOptions(player)[kind .. "Mod"](playerOptions(player), m.SpeedMod or 1)
end

local function speedText(player)
	local m = mods(player)
	local kind = m.SpeedModType or "X"
	if kind == "X" then return string.format("%.2fx", m.SpeedMod or 1) end
	return kind .. tostring(m.SpeedMod or 1)
end

-- The reading under the speed: what the chart in hand will actually scroll at,
-- which is the number that decides whether a speed is readable.
local function scrollText(player)
	local chart = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)
		or GAMESTATE:GetCurrentSteps(player)
	if not chart then return "" end
	local ok, bpms = pcall(function()
		return GetDisplayBPMs(player, chart, VOLT26.MusicSelection.GetMusicRate())
	end)
	if not (ok and type(bpms) == "table" and bpms[1] and bpms[2] and bpms[2] > 0) then return "" end

	local m = mods(player)
	local kind = m.SpeedModType or "X"
	local speed = m.SpeedMod or 1
	local low, high = bpms[1], bpms[2]
	if kind == "X" then
		low, high = low * speed, high * speed
	elseif kind == "M" then
		low, high = low * (speed / high), speed
	else
		low, high = speed, speed
	end
	if math.floor(low + 0.5) == math.floor(high + 0.5) then
		return string.format("%.0f %s", high, THEME:GetString("ScreenSelectMusic", "QuickModsScroll"))
	end
	return string.format("%.0f-%.0f %s", low, high,
		THEME:GetString("ScreenSelectMusic", "QuickModsScroll"))
end

Rows.SpeedModType = {
	Label = function() return title("SpeedModType") end,
	Value = function(player) return mods(player).SpeedModType or "X" end,
	Change = function(player, delta)
		local m = mods(player)
		local from = m.SpeedModType or "X"
		local to = step(speedTypes, from, delta)
		if to == from then return end

		-- Carrying the speed across: an x-mod and a bpm-mod are the same scroll
		-- expressed in different units, so the number is converted rather than
		-- reset, and then rounded onto the new unit's own increment.
		local ok, bpms = pcall(function() return GetDisplayBPMs(player) end)
		local ceiling = ok and type(bpms) == "table" and tonumber(bpms[2]) or nil
		local speed = m.SpeedMod or 1
		local bounds = speedBounds[to]
		if ceiling and ceiling > 0 then
			if from == "X" then
				speed = speed * ceiling
			elseif to == "X" then
				speed = speed / ceiling
			end
		elseif from == "X" or to == "X" then
			speed = bounds.Step
		end
		speed = bounds.Step * math.floor(speed / bounds.Step + 0.5)
		speed = math.max(bounds.Step, math.min(bounds.Upper, speed))

		for peer in ivalues(peers(player)) do
			mods(peer).SpeedModType = to
			mods(peer).SpeedMod = speed
			applySpeed(peer)
		end
	end,
}

Rows.SpeedMod = {
	Label = function() return title("SpeedMod") end,
	Value = speedText,
	Sub = scrollText,
	Change = function(player, delta)
		local m = mods(player)
		local bounds = speedBounds[m.SpeedModType or "X"]
		-- Wrapping through the whole range rather than stopping at its ends:
		-- reaching for the slowest speed from the fastest is one press.
		local speed = ((m.SpeedMod or bounds.Step) + bounds.Step * delta - bounds.Step)
			% bounds.Upper + bounds.Step
		speed = bounds.Step * math.floor(speed / bounds.Step + 0.5)
		for peer in ivalues(peers(player)) do
			mods(peer).SpeedMod = speed
			applySpeed(peer)
		end
	end,
}

-- ------------------------------------------------------------------ mini

-- The options screen moves Mini one percent at a time, which is the right grain
-- when the whole screen is given over to it.  Here five is: this menu is opened
-- to make a change and close again.
local miniStep = 5
local miniRange = {Low = -100, High = 150}

Rows.Mini = {
	Label = function() return title("Mini") end,
	Value = function(player) return mods(player).Mini or "0%" end,
	Change = function(player, delta)
		-- gsub answers with the text and a replacement count; without the extra
		-- parentheses that count would reach tonumber as a numeric base.
		local current = tonumber((tostring(mods(player).Mini or "0%"):gsub("%%", ""))) or 0
		local value = current + miniStep * delta
		if value > miniRange.High then value = miniRange.Low end
		if value < miniRange.Low then value = miniRange.High end
		mods(player).Mini = ("%g%%"):format(value)
		playerOptions(player):Mini(value / 100)
	end,
}

-- --------------------------------------------------------------- reverse

-- The receptors at the bottom and the arrows rising to them.  Both sides of a
-- shared-sides style play one note field, so the change lands on both.
Rows.Reverse = {
	Label = function() return title("Reverse") end,
	Value = function(player)
		return THEME:GetString("ScreenSelectMusic",
			VOLT26.Options.IsReverse(player) and "QuickModsOn" or "QuickModsOff")
	end,
	Change = function(player)
		local reversed = not VOLT26.Options.IsReverse(player)
		for peer in ivalues(peers(player)) do
			VOLT26.Options.SetReverse(peer, reversed)
		end
	end,
}

-- ----------------------------------------------------------- perspective

-- The engine keeps a perspective as a skew and a tilt rather than as a name, so
-- reading one back goes through the CORE boundary that owns that translation.
local function perspectiveNames()
	local names = {}
	for _, entry in ipairs(VOLT26.Options.GetPerspectives()) do
		names[#names+1] = entry.Name
	end
	return names
end

Rows.Perspective = {
	Label = function() return title("Perspective") end,
	Value = function(player)
		local name = VOLT26.Options.GetPerspective(player)
		if THEME:HasString("OptionNames", name) then
			return THEME:GetString("OptionNames", name)
		end
		return name
	end,
	Change = function(player, delta)
		local names = perspectiveNames()
		VOLT26.Options.SetPerspective(player,
			step(names, VOLT26.Options.GetPerspective(player), delta))
	end,
}

-- -------------------------------------------------------------- note skin

local function noteSkinNames()
	local ok, names = pcall(function() return NOTESKIN:GetNoteSkinNames(false) end)
	if not (ok and type(names) == "table" and #names > 0) then return nil end
	return names
end

local function currentNoteSkin(player)
	local chosen = mods(player).NoteSkin
	if type(chosen) == "string" and chosen ~= "" then return chosen end
	local ok, engine = pcall(function() return playerOptions(player):NoteSkin() end)
	return ok and engine or nil
end

local function variantsFor(skin)
	if not skin then return {} end
	local ok, has = pcall(function() return NOTESKIN:HasVariants(skin) end)
	if not (ok and has) then return {skin} end
	local okNames, names = pcall(function() return NOTESKIN:GetVariantNamesForNoteSkin(skin) end)
	if not (okNames and type(names) == "table") then return {skin} end
	local list = {skin}
	for name in ivalues(names) do
		if name ~= skin then list[#list+1] = name end
	end
	return list
end

-- A variant is stored under its full name -- "couples__blue" -- and read as the
-- part after the separator, which is the only part that tells the player apart
-- from the skin they already chose.
local function variantText(variant, skin)
	if type(variant) ~= "string" or variant == "" then return "--" end
	return variant:match("__(.*)") or variant
end

local function applyNoteSkin(player)
	local m = mods(player)
	local chosen = m.NoteSkinVariant or m.NoteSkin
	if type(chosen) == "string" and chosen ~= "" then
		playerOptions(player):NoteSkin(chosen)
	end
end

Rows.NoteSkin = {
	Label = function() return title("NoteSkin") end,
	Available = function() return noteSkinNames() ~= nil end,
	Value = function(player) return currentNoteSkin(player) or "--" end,
	Change = function(player, delta)
		local names = noteSkinNames()
		if not names then return end
		local to = step(names, currentNoteSkin(player), delta)
		local m = mods(player)
		m.NoteSkin = to
		-- The variant belongs to the skin that was chosen, so it goes back to
		-- that skin's own first entry rather than carrying a stale name over.
		m.NoteSkinVariant = variantsFor(to)[1]
		applyNoteSkin(player)
	end,
}

Rows.NoteSkinVariant = {
	Label = function() return title("NoteSkinVariant") end,
	Available = function(player)
		return #variantsFor(currentNoteSkin(player)) > 1
	end,
	Value = function(player)
		local skin = currentNoteSkin(player)
		return variantText(mods(player).NoteSkinVariant or skin, skin)
	end,
	Change = function(player, delta)
		local skin = currentNoteSkin(player)
		local list = variantsFor(skin)
		if #list < 2 then return end
		mods(player).NoteSkinVariant = step(list, mods(player).NoteSkinVariant or skin, delta)
		applyNoteSkin(player)
	end,
}

-- ------------------------------------------------------------- feedback

-- These three are the theme's own: gameplay reads them out of the modifier
-- table, so there is nothing to push into the engine.
local function assetRow(key, field, choices, display)
	return {
		Label = function() return title(key) end,
		Available = function() return #choices() > 0 end,
		Value = function(player) return display(mods(player)[field]) end,
		Change = function(player, delta)
			local list = choices()
			if #list == 0 then return end
			mods(player)[field] = step(list, mods(player)[field], delta)
		end,
	}
end

Rows.JudgmentGraphic = assetRow("JudgmentGraphic", "JudgmentGraphic",
	function() return GetJudgmentGraphics() end,
	function(value) return value and StripSpriteHints(value) or "--" end)

Rows.HoldJudgment = assetRow("HoldJudgment", "HoldJudgment",
	function() return GetHoldJudgments() end,
	function(value) return value and StripSpriteHints(value) or "--" end)

Rows.ComboFont = assetRow("ComboFont", "ComboFont",
	function() return GetComboFonts() end,
	function(value) return value or "--" end)

-- ---------------------------------------------------------------- screen

local backgroundFilters = {"Off", "Dark", "Darker", "Darkest"}

Rows.BackgroundFilter = {
	Label = function() return title("BackgroundFilter") end,
	Value = function(player) return mods(player).BackgroundFilter or "Off" end,
	Change = function(player, delta)
		mods(player).BackgroundFilter =
			step(backgroundFilters, mods(player).BackgroundFilter or "Off", delta)
	end,
}

-- The rate belongs to the song rather than to a player, so both sides see the
-- same number change.  Left out of the default list for that reason.
Rows.MusicRate = {
	Label = function() return title("MusicRate") end,
	Shared = true,
	Value = function() return ("%.2fx"):format(VOLT26.Options.GetGlobalModifiers().MusicRate or 1) end,
	Change = function(player, delta)
		local global = VOLT26.Options.GetGlobalModifiers()
		local rate = (tonumber(global.MusicRate) or 1) + 0.05 * delta
		rate = math.max(0.05, math.min(3, math.floor(rate * 100 + 0.5) / 100))
		global.MusicRate = rate
		GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred"):MusicRate(rate)
		MESSAGEMAN:Broadcast("MusicRateChanged")
	end,
}

-- The order a missing configuration file falls back to.  Hold judgment is in;
-- the rate and the background filter are not, because neither changes what the
-- preview beside the menu can show.
Rows.Default = {
	"SpeedModType", "SpeedMod", "Mini", "Reverse", "Perspective",
	"NoteSkin", "NoteSkinVariant",
	"JudgmentGraphic", "ComboFont", "HoldJudgment",
}

-- Resolve(names) -> the definitions those names pick out, in that order.
function Rows.Resolve(names)
	local resolved = {}
	for name in ivalues(names or Rows.Default) do
		local definition = type(name) == "string" and Rows[name] or nil
		if type(definition) == "table" and definition.Value then
			resolved[#resolved+1] = {Key = name, Definition = definition}
		end
	end
	if #resolved == 0 then
		for name in ivalues(Rows.Default) do
			resolved[#resolved+1] = {Key = name, Definition = Rows[name]}
		end
	end
	return resolved
end

return Rows
