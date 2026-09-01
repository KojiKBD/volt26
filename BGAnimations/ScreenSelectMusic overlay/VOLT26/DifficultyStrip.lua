local H = ...
local maxDifficulties = 10

local function availableSteps()
	local song = H.Item()
	local _, sourceChart = H.PreviewSource()
	if not song or not song.GetStepsByStepsType or not sourceChart or not sourceChart.GetStepsType then return {} end
	local steps = {}
	for chart in ivalues(song:GetStepsByStepsType(sourceChart:GetStepsType())) do steps[#steps+1] = chart end
	table.sort(steps, function(a,b)
		local am, bm = tonumber(a:GetMeter()) or 0, tonumber(b:GetMeter()) or 0
		if am == bm then return ToEnumShortString(a:GetDifficulty()) < ToEnumShortString(b:GetDifficulty()) end
		return am < bm
	end)
	return steps
end

local af = Def.ActorFrame{
	Name="DifficultyStrip",
	InitCommand=function(self) self:xy(250,456) end,
	RefreshCommand=function(self)
		local choices = availableSteps()
		local shown = math.min(#choices,maxDifficulties)
		self:visible(shown > 0 and H.Item() ~= nil)
		local spacing = shown > 8 and 27 or 32
		local p1Chart, p2Chart = H.Chart(PLAYER_1), H.Chart(PLAYER_2)
		for i=1,maxDifficulties do
			local chart = choices[i]
			local visible = i <= shown and chart ~= nil
			local meter = self:GetChild("Meter"..i)
			local p1, p2 = self:GetChild("P1_"..i), self:GetChild("P2_"..i)
			meter:visible(visible)
			p1:visible(visible and GAMESTATE:IsHumanPlayer(PLAYER_1) and chart == p1Chart)
			p2:visible(visible and GAMESTATE:IsHumanPlayer(PLAYER_2) and chart == p2Chart)
			if visible then
				local x = 177 + (i-(shown+1)/2)*spacing
				local active = chart == p1Chart or chart == p2Chart
				meter:xy(x,0):settext(chart:GetMeter()):diffuse(VOLT26.ChartData.GetDifficultyColor(chart:GetDifficulty())):diffusealpha(active and 1 or 0.62)
				p1:xy(x-8,9)
				p2:xy(x,9)
			end
		end
	end,
}

af[#af+1] = Def.Quad{
	Name="Surface",
	InitCommand=function(self) self:align(0.5,0.5):xy(177,1):zoomto(354,25):diffuse(H.Surface):diffusealpha(H.SurfaceAlpha) end,
}
for i=1,maxDifficulties do
	af[#af+1] = Def.BitmapText{
		Name="Meter"..i, Font=H.FontBold,
		InitCommand=function(self) self:horizalign(center):zoom(H.BoldZoom(0.052)):visible(false) end,
	}
	af[#af+1] = Def.Quad{
		Name="P1_"..i,
		InitCommand=function(self) self:align(0,0.5):zoomto(8,2):diffuse(H.P1):visible(false) end,
	}
	af[#af+1] = Def.Quad{
		Name="P2_"..i,
		InitCommand=function(self) self:align(0,0.5):zoomto(8,2):diffuse(H.P2):visible(false) end,
	}
end

H.AddSettledRefresh(af, 0.35, 0, 12)
return af
