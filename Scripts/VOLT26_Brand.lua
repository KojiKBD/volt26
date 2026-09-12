VOLT26.Brand = {
	Colors = {
	
    "#FF0000",  -- Elite  | Phantom Red (The fiery, rebellious core)
    "#1A1A1A",  -- Mid    | Phantom Black (Sleek, stylish, but lacks the "red" impact)
    "#D8D8D8",  -- Weak   | Metaverse White/Grey (Standard shadows/cognitions)
	"#00A8E8",  -- Velvet Blue
	"#FFD400",  -- Investigation Gold
	"#9B1BFF",  -- Metaverse Violet

	},
	TextColor = "#ffffff",

	-- The theme accent is fixed: ScreenSelectColor and the per-profile colour
	-- choice were removed.  Player 1 (and every shared/global element) uses
	-- Phantom Red; Player 2 is differentiated with Metaverse Violet.
	-- Both values are indices into Colors above.
	AccentColorIndex = 1,
	-- Keyed by PlayerNumber enum value (PLAYER_1 == "PlayerNumber_P1").
	PlayerAccentColorIndex = {
		PlayerNumber_P1 = 1,
		PlayerNumber_P2 = 6,
	},

    GetFactionName = function(idx)
		-- Assuming that idx is 1-indexed and
		-- follows the order of the colours above
		if idx == 1 then
			return "MASTER"
		elseif idx == 2 then
			return "ELITE"
		elseif idx == 3 then
			return "OPEN"
		else
			return ""
		end
	end,
	GetLogo = function()
		return "logo_main (doubleres).png"
	end,
	RandomTagline = function()
		-- Prefer live player messages pulled from the Google Sheet (see
		-- Scripts/VOLT26_PlayerMessages.lua). The lines below are only an
		-- emergency fallback for when no sheet data has ever been loaded
		-- (e.g. first launch with no network yet).
		local sheetLine = VOLT26.PlayerMessages and VOLT26.PlayerMessages.RandomLine()
		if sheetLine then return sheetLine end

		local lines = {
			"TAKE YOUR HEART",
			"MAKE YOUR MOVE",
			"THE NIGHT IS OURS",
			"WELCOME TO VOLT26"
		}

		return lines[math.random(#lines)]
	end,
	Activate = function(self)
		-- The accent is a constant, so activation only has to make sure the
		-- shared runtime state agrees with it.
		VOLT26.State.Global.ActiveColorIndex = self.AccentColorIndex
	end,

	-- Retained as a no-op adapter: the accent is no longer chosen or randomized.
	MaybeRandomizeColor = function(self)
		VOLT26.State.Global.ActiveColorIndex = self.AccentColorIndex
	end,
}

-- Temporary field compatibility for screens not yet migrated.
VOLT26.VOLT26 = VOLT26.Brand
