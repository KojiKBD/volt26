-- VOLT26 CORE: Chart data snapshots, stream analysis, and chart hashing.
-- Loaded after SL_Init.lua, which creates the VOLT26 namespace and state.

VOLT26.ChartData = {}

local OriginalDifficultyColors = {
	Difficulty_Beginner = color("#AEFA44"),
	Difficulty_Easy = color("#FFFF00"),
	Difficulty_Medium = color("#FFBE00"),
	Difficulty_Hard = color("#FF7D00"),
	Difficulty_Challenge = color("#FF5D47"),
	Difficulty_Edit = color("#B4B7BA"),
}

function VOLT26.ChartData.GetDifficultyColor(difficulty)
	return DeepCopy(OriginalDifficultyColors[difficulty] or OriginalDifficultyColors.Difficulty_Edit)
end

local function ChartPlayerEnum(player)
	if player == "P1" or player == PLAYER_1 then return PLAYER_1 end
	if player == "P2" or player == PLAYER_2 then return PLAYER_2 end
	return nil
end

local function ChartPlayerKey(player)
	if player == "P1" or player == PLAYER_1 then return "P1" end
	if player == "P2" or player == PLAYER_2 then return "P2" end
	return nil
end

function VOLT26.ChartData.Refresh(steps, player)
	local playerEnum = ChartPlayerEnum(player)
	local playerKey = ChartPlayerKey(player)
	if not steps or not playerEnum or not playerKey then return nil end

	local techCounts = steps:GetTechCounts(playerEnum)
	local result = {
		NotesPerMeasure = steps:GetNotesPerMeasure(playerEnum),
		NPSperMeasure = steps:GetNpsPerMeasure(playerEnum),
		PeakNPS = steps:GetPeakNps(playerEnum),
		Crossovers = techCounts:GetValue("TechCountsCategory_Crossovers"),
		Footswitches = techCounts:GetValue("TechCountsCategory_Footswitches"),
		Sideswitches = techCounts:GetValue("TechCountsCategory_Sideswitches"),
		Jacks = techCounts:GetValue("TechCountsCategory_Jacks"),
		Brackets = techCounts:GetValue("TechCountsCategory_Brackets"),
	}

	local streams = VOLT26.State[playerKey].Streams
	for key, value in pairs(result) do streams[key] = value end
	return DeepCopy(result)
end

function VOLT26.ChartData.Get(player)
	local playerKey = ChartPlayerKey(player)
	if not playerKey then return nil end
	local streams = VOLT26.State[playerKey].Streams
	return DeepCopy({
		NotesPerMeasure = streams.NotesPerMeasure,
		NPSperMeasure = streams.NPSperMeasure,
		PeakNPS = streams.PeakNPS,
		Crossovers = streams.Crossovers,
		Footswitches = streams.Footswitches,
		Sideswitches = streams.Sideswitches,
		Jacks = streams.Jacks,
		Brackets = streams.Brackets,
	})
end

function VOLT26.ChartData.GetColumnCues(steps, player)
	local playerKey = ChartPlayerKey(player)
	if not steps or not playerKey then return {} end

	local cues = steps:GetColumnCues(VOLT26.State.Global.ColumnCueMinTime)
	for _, cue in ipairs(cues) do
		for _, column in ipairs(cue.columns) do
			column.isMine = column.noteType == 4
			column.noteType = nil
		end
	end
	VOLT26.State[playerKey].Streams.ColumnCues = cues
	return DeepCopy(cues)
end

VOLT26.ChartAnalysis = {}

function VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, notesThreshold)
	local streamMeasures = {}
	for index, noteCount in ipairs(notesPerMeasure or {}) do
		if noteCount >= notesThreshold then streamMeasures[#streamMeasures + 1] = index end
	end

	local sequences = {}
	local counter = 1
	local streamEnd = nil
	if #streamMeasures > 0 then
		local breakEnd = streamMeasures[1] - 1
		if breakEnd >= 2 then
			sequences[#sequences + 1] = {streamStart=0, streamEnd=breakEnd, isBreak=true}
		end
	end

	for index, current in ipairs(streamMeasures) do
		local nextMeasure = streamMeasures[index + 1] or -1
		if current + 1 == nextMeasure then
			counter = counter + 1
			streamEnd = current + 1
		else
			streamEnd = streamEnd or current
			sequences[#sequences + 1] = {
				streamStart=streamEnd - counter,
				streamEnd=streamEnd,
				isBreak=false,
			}
			local breakEnd = nextMeasure ~= -1 and nextMeasure - 1 or #(notesPerMeasure or {})
			if breakEnd - current >= 2 then
				sequences[#sequences + 1] = {streamStart=current, streamEnd=breakEnd, isBreak=true}
			end
			counter = 1
			streamEnd = nil
		end
	end
	return sequences
end

function VOLT26.ChartAnalysis.GetBreakdownText(notesPerMeasure, minimizationLevel)
	if #(notesPerMeasure or {}) == 0 then return "Not available!" end
	local segments = VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, 16)
	local textSegments = {}
	local segmentSum, totalSum = 0, 0
	local isBroken = false

	local function addNotation(notation, segmentSize)
		if minimizationLevel == 0 then
			textSegments[#textSegments + 1] = " (" .. tostring(segmentSize) .. ") "
		elseif segmentSum ~= 0 then
			if minimizationLevel == 2 then
				textSegments[#textSegments + 1] = tostring(segmentSum) .. (isBroken and "*" or "")
			elseif minimizationLevel == 3 then
				totalSum = totalSum + segmentSum
			end
		end
		if minimizationLevel ~= 3 then textSegments[#textSegments + 1] = notation end
		segmentSum, isBroken = 0, false
	end

	for index, segment in ipairs(segments) do
		local segmentSize = segment.streamEnd - segment.streamStart
		if segment.isBreak then
			if index ~= 1 and index ~= #segments then
				if segmentSize <= 4 then
					addNotation("-", segmentSize)
				elseif segmentSize < 32 then
					addNotation("/", segmentSize)
				else
					addNotation(" | ", segmentSize)
				end
			end
		elseif minimizationLevel == 2 or minimizationLevel == 3 then
			if index > 1 and not segments[index - 1].isBreak then
				isBroken = true
				if minimizationLevel == 2 then segmentSum = segmentSum + 1 end
			end
			segmentSum = segmentSum + segmentSize
		else
			if index > 1 and not segments[index - 1].isBreak then
				textSegments[#textSegments + 1] = "-"
			end
			textSegments[#textSegments + 1] = tostring(segmentSize)
		end
	end

	if segmentSum ~= 0 then
		if minimizationLevel == 2 then
			textSegments[#textSegments + 1] = tostring(segmentSum) .. (isBroken and "*" or "")
		elseif minimizationLevel == 3 then
			totalSum = totalSum + segmentSum
		end
	end

	if minimizationLevel == 3 then return string.format("%d Total", totalSum) end
	if #textSegments == 0 then return "No Streams!" end
	return table.concat(textSegments, "")
end

function VOLT26.ChartAnalysis.GetMeasureTotals(notesPerMeasure)
	local streamTotal, breakTotal = 0, 0
	for _, segment in ipairs(VOLT26.ChartAnalysis.GetStreamSequences(notesPerMeasure, 16)) do
		local size = segment.streamEnd - segment.streamStart
		if segment.isBreak then breakTotal = breakTotal + size else streamTotal = streamTotal + size end
	end
	return streamTotal, breakTotal
end

VOLT26.ChartHash = {}

function VOLT26.ChartHash.Compute(steps, player)
	return VOLT26ComputeChartHash(steps, ChartPlayerKey(player))
end
