------------------------------------------------------------
-- global functions related to colors in Simply Love

function GetHexColor( n, decorative )
	-- if we were passed nil or a non-number, return white
	if n == nil or type(n) ~= "number" then return Color.White end

	local colorTable = SL.Colors
	if decorative then
		colorTable = SL.DecorativeColors
	end
	if SL.VOLT26 and SL.VOLT26.Colors then
		colorTable = SL.VOLT26.Colors
	end

	-- use the number passed in to lookup a color in the corresponding color table
	-- ensure the index is kept in bounds via modulo operation
	local clr = ((n - 1) % #colorTable) + 1
	if colorTable[clr] then
		local c = color(colorTable[clr])
		return c
	end

	return Color.White
end

-- The theme accent is fixed.  ScreenSelectColor was removed, so there is no
-- runtime colour choice any more: everything shared uses the brand accent
-- (Phantom Red) and Player 2 is differentiated with Metaverse Violet.
local function AccentIndex( pn )
	local brand = SL.VOLT26
	if not brand then return 1 end
	if pn ~= nil and brand.PlayerAccentColorIndex then
		local index = brand.PlayerAccentColorIndex[pn]
		if index then return index end
	end
	return brand.AccentColorIndex or 1
end

-- convenience function to return the theme accent
function GetCurrentColor( decorative )
	return GetHexColor( AccentIndex(nil), decorative )
end

function PlayerColor( pn, decorative )
	if pn ~= PLAYER_1 and pn ~= PLAYER_2 then return Color.White end
	return GetHexColor( AccentIndex(pn), decorative )
end

function DifficultyColor( difficulty, decorative )
	-- Difficulty colours are independent of the accent; they come from the
	-- fixed per-difficulty palette owned by VOLT26.ChartData.
	if VOLT26 and VOLT26.ChartData and VOLT26.ChartData.GetDifficultyColor then
		return VOLT26.ChartData.GetDifficultyColor(difficulty)
	end
	return color("#B4B7BA")
end

function LightenColor(c)
	return { c[1]*1.25, c[2]*1.25, c[3]*1.25, c[4] }
end
