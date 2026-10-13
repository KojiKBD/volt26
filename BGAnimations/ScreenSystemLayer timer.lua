-- The menu timer in cutout lettering (Scripts/VOLT26_Cutout.lua).
--
-- The engine MenuTimer still counts, beeps and decides whether it is shown
-- (each screen's TimerOnCommand); only its number is hidden ([MenuTimer]
-- Text1OnCommand in metrics.ini) and mirrored here, at the same place, in the
-- cutout lettering.  It lives in ScreenSystemLayer so one actor serves every
-- screen with a timer.
--
-- Two slots are used alternately, as for the pack step's pack name: the number
-- on screen stays until its successor has finished rendering, so a new second
-- never leaves a blank frame.  In the last seconds the number pulses red, as
-- the plain timer's Warning commands did.

local style = VOLT26.Cutout.Style("MenuTimer")
local WARNING_SECONDS = 5
local TOP_MARGIN = 3

local frame
local slots, active = {}, 1
local shown, wanted, pending = nil, nil, nil
local warning = false

local function slot(index)
	return VOLT26.Cutout.CreateSlot{
		maxW = style.maxW, maxH = style.maxH, maxChars = style.maxChars,
		halign = 1, valign = 0, held = true, opts = style.opts,
		onInit = function(s) slots[index] = s end,
		onReady = function(s)
			if s ~= slots[3 - active] or pending == nil or pending ~= wanted then return end
			local outgoing = slots[active]
			active = 3 - active
			shown, pending = wanted, nil
			outgoing:playcommand("CutoutHold", { held = true })
			s:playcommand("CutoutHold", { held = false })
		end,
	}
end

local function setNumber(text)
	if text == wanted then return end
	wanted = text
	if text == shown then
		pending = nil
		return
	end
	pending = text
	local s = slots[3 - active]
	if s then s:playcommand("CutoutSet", { text = text }) end
end

local function setWarning(on)
	if on == warning then return end
	warning = on
	if on then
		frame:diffuseshift():effectperiod(1)
			:effectcolor1(1, 1, 1, 1):effectcolor2(1, 0.2, 0.2, 1)
	else
		frame:stopeffect()
	end
end

-- The top screen's timer and its number, when it has them.
local function engineTimer()
	local screen = SCREENMAN:GetTopScreen()
	local timer = screen and screen:GetChild("Timer")
	if not timer then return nil end
	local ok, number = pcall(function() return timer:GetChild("Text1") end)
	if not ok or not number then return nil end
	return timer, number
end

local function update(self)
	local timer, number = engineTimer()
	local text = number and number:GetText() or ""
	if not timer or not timer:GetVisible() or text == "" then
		self:visible(false)
		return
	end
	-- Text1 is hidden by its OnCommand; keep it so if anything shows it.
	if number:GetVisible() then number:visible(false) end
	self:visible(true)
		:xy(timer:GetX() + number:GetX(), math.max(TOP_MARGIN, timer:GetY() + number:GetY() - style.maxH / 2))
		:diffusealpha(number:GetDiffuseAlpha())
	setNumber(text)
	local seconds = tonumber(text)
	setWarning(seconds ~= nil and seconds > 0 and seconds <= WARNING_SECONDS)
end

return Def.ActorFrame{
	Name = "CutoutMenuTimer",
	InitCommand = function(self)
		frame = self
		self:visible(false)
		self:SetUpdateFunction(update)
	end,
	slot(1),
	slot(2),
}
