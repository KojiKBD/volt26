-- Easter egg: a five-star result (Grade_Tier00, 100% EX) brings the cat from
-- the Double face -- whole, uncropped, cigar and all -- up into the
-- bottom-right corner of the stage evaluation once its sequence has finished;
-- it sways for a few seconds and ducks back down so the results stay readable.
--
-- A module (see Modules/README.md), so it draws in ScreenSystemLayer above the
-- evaluation's own layers without touching their files.

local catPath = THEME:GetPathG("", "VOLT26/five_star_cat.png")
local catW, catH = 1172, 1270        -- the image's own size
local height = SCREEN_HEIGHT * 0.62  -- how tall it stands on the results
local width = height * catW / catH
local stay = 4.5                     -- seconds on screen before it ducks

local function AnyFiveStar()
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local result = VOLT26.Results.GetCurrent(player)
		if result and result.grade == "Grade_Tier00" then return true end
	end
	return false
end

local function Cat()
	local armed = false
	return Def.ActorFrame{
		ModuleCommand=function(self)
			armed = AnyFiveStar()
			self:GetChild("Cat"):finishtweening():visible(false)
		end,
		VOLT26EvaluationSequenceFinishedMessageCommand=function(self)
			if not armed then return end
			armed = false
			local cat = self:GetChild("Cat")
			cat:finishtweening():visible(true)
				:xy(SCREEN_RIGHT + 10, SCREEN_BOTTOM + height):rotationz(-14)
				:sleep(0.5)
				:decelerate(0.35):xy(SCREEN_RIGHT - 16, SCREEN_BOTTOM - 8):rotationz(3)
				:bounceend(0.25):rotationz(0)
				:queuecommand("Sway")
		end,
		Def.Sprite{
			Name="Cat",
			Texture=catPath,
			InitCommand=function(self)
				-- Anchored at its bottom-right corner, which is also the pivot
				-- it sways about.
				self:align(1, 1):zoomto(width, height):visible(false)
			end,
			SwayCommand=function(self)
				self:wag():effectmagnitude(0, 0, 2.5):effectperiod(2.2)
					:sleep(stay):queuecommand("Duck")
			end,
			DuckCommand=function(self)
				self:stopeffect():accelerate(0.3):y(SCREEN_BOTTOM + height):rotationz(-10)
					:queuecommand("Hide")
			end,
			HideCommand=function(self) self:visible(false) end,
		},
	}
end

return {
	ScreenEvaluationStage = Cat(),
	ScreenEvaluationNonstop = Cat(),
}
