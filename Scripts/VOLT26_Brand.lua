VOLT26.Brand = {
	Colors = {
	
    "#FF0000",  -- Elite  | Phantom Red (The fiery, rebellious core)
    "#1A1A1A",  -- Mid    | Phantom Black (Sleek, stylish, but lacks the "red" impact)
    "#D8D8D8",  -- Weak   | Metaverse White/Grey (Standard shadows/cognitions)

	},
	TextColor = "#ffffff",
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
	-- internal flag
	firstRun = false,

	GetLogo = function()
		return "logo_main (doubleres).png"
	end,
	RandomTagline = function()
		local lines = {
			"TAKE YOUR HEART",
			"MAKE YOUR MOVE",
			"THE NIGHT IS OURS",
			"WELCOME TO VOLT26"
		}

		return lines[math.random(#lines)]
	end,
	Activate = function(self)
		self.firstRun = true

		local screen = SCREENMAN:GetTopScreen()
		if screen ~= nil and screen:GetName() == "ScreenTitleMenu" then
			self:MaybeRandomizeColor()
		end
	end,
	MaybeRandomizeColor = function(self)
		if self.firstRun then
			VOLT26.State.Global.ActiveColorIndex = 2
			ThemePrefs.Set("VOLT26Color", 2)
			MESSAGEMAN:Broadcast("ColorSelected")
			self.firstRun = false
		elseif not ThemePrefs.Get("AllowScreenSelectColor") then
			VOLT26.State.Global.ActiveColorIndex = MersenneTwister.Random(#self.Colors)
			ThemePrefs.Set("VOLT26Color", VOLT26.State.Global.ActiveColorIndex)
			MESSAGEMAN:Broadcast("ColorSelected")
		end
	end,
}

-- Temporary field compatibility for screens not yet migrated.
VOLT26.VOLT26 = VOLT26.Brand
