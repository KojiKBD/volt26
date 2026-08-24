local args = ...
local player = args.player
local graphWidth = args.GraphWidth
local graphHeight = args.GraphHeight
local modifiers = VOLT26.Options.GetPlayerModifiers(player)
local timingOffsets = VOLT26.Analysis.GetTimingOffsets(player)
local timeline = VOLT26.Analysis.GetTimeline(player)
local worstWindow = GetTimingWindow(math.max(2, VOLT26.Analysis.GetWorstJudgment(timingOffsets)))

local colors = {}
for window=NumJudgmentsAvailable(),1,-1 do
	if modifiers.TimingWindows[window] then
		colors[window] = DeepCopy(SL.JudgmentColors[SL.Global.GameMode][window])
	else
		colors[window] = DeepCopy(colors[window + 1] or SL.JudgmentColors[SL.Global.GameMode][window + 1])
	end
end

local pointBatches = VOLT26.Analysis.BuildScatterBatches(
	timingOffsets,
	timeline,
	graphWidth,
	graphHeight,
	worstWindow
)

local af = Def.ActorFrame{}

if GAMESTATE:IsCourseMode() and timeline.lastSecond > 0 then
	for index, segment in ipairs(timeline.segments) do
		if index % 2 == 1 then
			local startX = -graphWidth / 2 + segment.startSecond / timeline.lastSecond * graphWidth
			local segmentWidth = (segment.endSecond - segment.startSecond) / timeline.lastSecond * graphWidth
			af[#af + 1] = Def.Quad{
				InitCommand=function(self)
					self:x(startX):zoomto(segmentWidth, graphHeight)
						:diffuse(LightenColor(LightenColor(color("#101519"))))
						:diffusealpha(0.5):vertalign(top):horizalign(left)
				end,
			}
		end
	end
end

for _, points in ipairs(pointBatches) do
	local vertices = {}
	for _, point in ipairs(points) do
		if point.isMiss then
			vertices[#vertices + 1] = {{point.x, 0, 0}, color("#ff000077")}
			vertices[#vertices + 1] = {{point.x + 1, 0, 0}, color("#ff000077")}
			vertices[#vertices + 1] = {{point.x + 1, graphHeight, 0}, color("#ff000077")}
			vertices[#vertices + 1] = {{point.x, graphHeight, 0}, color("#ff000077")}
		else
			local tint = colors[DetermineTimingWindow(point.offset)]
			local absoluteOffset = math.abs(point.offset)
			if modifiers.ShowFaPlusWindow and modifiers.ShowFaPlusPane
				and absoluteOffset > GetTimingWindow(1, "FA+")
				and absoluteOffset <= GetTimingWindow(2, "FA+") then
				tint = SL.JudgmentColors["FA+"][2]
			end
			local vertexColor = {tint[1], tint[2], tint[3], 0.666}
			vertices[#vertices + 1] = {{point.x, point.y, 0}, vertexColor}
			vertices[#vertices + 1] = {{point.x + 1.5, point.y, 0}, vertexColor}
			vertices[#vertices + 1] = {{point.x + 1.5, point.y + 1.5, 0}, vertexColor}
			vertices[#vertices + 1] = {{point.x, point.y + 1.5, 0}, vertexColor}
		end
	end

	af[#af + 1] = Def.ActorMultiVertex{
		InitCommand=function(self) self:x(-graphWidth / 2) end,
		OnCommand=function(self)
			self:SetDrawState{Mode="DrawMode_Quads"}:SetVertices(vertices)
		end,
	}
end

return af
