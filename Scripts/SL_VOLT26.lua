SL.VOLT26 = {
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
	RandomBullshit = function()
		local lines = {
			"Koji dorme con un peluche di Kuromi",
			"Dando mi ha detto che il LUA è come la figa e poi mi ha dato del frocio",
			"Palle",
			"Ho visto un negro con le scarpe di gomma"
		}

		return lines[math.random(#lines)]
	end,
	ActivateVisualStyle = function(self)
		ThemePrefs.Set("VisualStyle", "VOLT26")
		ThemePrefs.Set("RainbowMode", false)
		ThemePrefs.Set("LastActiveEvent", "VOLT26")
		ThemePrefs.Save()

		MESSAGEMAN:Broadcast("VisualStyleSelected")

		self.firstRun = true

		local screen = SCREENMAN:GetTopScreen()
		if screen ~= nil and screen:GetName() == "ScreenTitleMenu" then
			self:MaybeRandomizeColor()
		end
	end,
	MaybeRandomizeColor = function(self)
		if self.firstRun then
			SL.Global.ActiveColorIndex = 2	-- green/unaffiliated/main logo
			ThemePrefs.Set("SimplyLoveColor", 2)
			MESSAGEMAN:Broadcast("ColorSelected")
			self.firstRun = false
		elseif not ThemePrefs.Get("AllowScreenSelectColor") then
			SL.Global.ActiveColorIndex = MersenneTwister.Random(#self.Colors)
			ThemePrefs.Set("SimplyLoveColor", SL.Global.ActiveColorIndex)
			MESSAGEMAN:Broadcast("ColorSelected")
		end
	end,
}
