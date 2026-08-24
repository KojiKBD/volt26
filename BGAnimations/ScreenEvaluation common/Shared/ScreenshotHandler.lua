if VOLT26.Gameplay.IsCasual() then return end

local requestingPlayer
local sprite = Def.Sprite{InitCommand=function(self) self:draworder(200) end}

sprite.CodeMessageCommand=function(self, params)
	if params.Name ~= "Screenshot" then return end
	local success = VOLT26.EvaluationInput.CaptureScreenshot(params.PlayerNumber)
	if not success then
		SM(ScreenString("ScreenshotFailed"))
		return
	end

	requestingPlayer = params.PlayerNumber
	SM(ScreenString("ScreenshotSaved"))
	MESSAGEMAN:Broadcast("ScreenshotCurrentScreen")
end

sprite.AnimateScreenshotCommand=function(self)
	local texture = VOLT26.EvaluationInput.GetScreenshotTexture()
	if not texture then return end

	self:finishtweening():Center():zoomto(_screen.w, _screen.h):SetTexture(texture)
	self:zoom(0.2):glowshift():effectperiod(0.5)
		:effectcolor1(1, 1, 1, 0):effectcolor2(1, 1, 1, 0.2):sleep(0.4)

	if requestingPlayer and PROFILEMAN:IsPersistentProfile(requestingPlayer) then
		local targetX = requestingPlayer == PLAYER_1 and 20 or _screen.w - 20
		self:smooth(0.75):xy(targetX, _screen.h + 10):zoom(0)
	else
		self:sleep(0.25):smooth(0.75):y(_screen.h + 10):zoom(0)
	end
	requestingPlayer = nil
end

return sprite
