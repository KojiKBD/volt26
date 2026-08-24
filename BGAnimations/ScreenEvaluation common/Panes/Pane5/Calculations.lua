local player, analysis, worstWindow, paneWidth, paneHeight, colors = unpack(...)
local mods = VOLT26.Options.GetPlayerModifiers(player)
local smoothed = VOLT26.Analysis.SmoothDistribution(analysis.distribution, worstWindow)
local vertices = {}
local millisecondLimit = math.floor(worstWindow * 1000 + 0.5)
local totalWidth = millisecondLimit * 2 + 1
local barWidth = paneWidth / totalWidth

for millisecond=-millisecondLimit,millisecondLimit do
	local offset = millisecond / 1000
	if math.abs(offset) <= analysis.worstOffsetSeconds then
		local value = smoothed.values[offset] or 0
		local y = smoothed.highestCount > 0
			and -scale(value, 0, smoothed.highestCount, 0, paneHeight * 0.75) or 0
		local tint = colors[DetermineTimingWindow(offset)]
		if mods.ShowFaPlusPane and mods.ShowFaPlusWindow then
			local absoluteOffset = math.abs(offset)
			if absoluteOffset > GetTimingWindow(1, "FA+")
				and absoluteOffset <= GetTimingWindow(2, "FA+") then
				tint = SL.JudgmentColors["FA+"][2]
			end
		end
		local x = (millisecond + millisecondLimit + 1) * barWidth
		vertices[#vertices + 1] = {{x, 0, 0}, tint}
		vertices[#vertices + 1] = {{x, y, 0}, tint}
	end
end

local af = Def.ActorFrame{}

af[#af + 1] = Def.ActorMultiVertex{
	Name="ModeJudgmentOffset_AMV",
	OnCommand=function(self)
		self:SetDrawState{Mode="DrawMode_QuadStrip"}:SetVertices(vertices)
	end,
}

local values = Def.ActorFrame{InitCommand=function(self) self:y(-paneHeight + 32) end}
local padding = 40
local displayed = {
	{analysis.meanAbsoluteMs, padding},
	{analysis.meanOffsetMs, padding + (paneWidth - 2 * padding) / 3},
	{analysis.sigmaMs, padding + (paneWidth - 2 * padding) / 3 * 2},
	{analysis.maxErrorMs, paneWidth - padding},
}

for _, value in ipairs(displayed) do
	values[#values + 1] = Def.BitmapText{
		Font="Common Normal",
		Text=("%.1fms"):format(value[1]),
		InitCommand=function(self) self:x(value[2]):zoom(0.8) end,
	}
end

af[#af + 1] = values
return af
