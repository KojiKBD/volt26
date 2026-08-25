local player, layout = ...
local mods = VOLT26.Options.GetPlayerModifiers(player)

-- don't allow MeasureCounter to appear in Casual gamemode via profile settings
if VOLT26.Gameplay.IsCasual()
or not mods.MeasureCounter
or mods.MeasureCounter == "None" then
	return
end

-- -----------------------------------------------------------------------

local PlayerState = GAMESTATE:GetPlayerState(player)
local segments, prevMeasure, streamIndex
-- Collection of the BitmapText actors used for the measure counters.
local bmt = {}

-- How many streams to "look ahead"
local lookAhead = mods.HideLookahead and 0 or 3
-- If you want to see more than 2 counts in advance, change the 2 to a larger value.
-- Making the value very large will likely impact fps. -quietly


-- We'll want to reset each of these values for each new song in the case of CourseMode
local InitializeMeasureCounter = function()
	segments = VOLT26.GameplayStats.GetMeasureSegments(player)
	streamIndex = 1
	prevMeasure = -1

	for actor in ivalues(bmt) do
		actor:visible(true)
	end
end

local Update = function(self, delta)
	-- Check to make sure we even have any streams populated to display.
	if not segments or #segments == 0 then return end

	-- Things to look into:
	-- 1. Does PlayerState:GetSongPosition() take split timing into consideration?  Do we need to?
	-- 2. This assumes each measure is comprised of exactly 4 beats.  Is it safe to assume this?
	local currMeasure = (math.floor(PlayerState:GetSongPosition():GetSongBeatVisible()))/4

	-- If a new measure has occurred
	if currMeasure > prevMeasure then
		prevMeasure = currMeasure

		-- If we've reached the end of the stream, we want to get values for the next stream.
		if VOLT26.GameplayStats.IsEndOfSegment(currMeasure, segments, streamIndex) then
			streamIndex = streamIndex + 1
		end

		for i=1,lookAhead+1 do
			-- Only the first one is the main counter, the other ones are lookaheads.
			local isLookAhead = i ~= 1
			-- We're looping forwards, but the BMTs are indexed in the opposite direction.
			-- Adjust indices accordingly.
			local adjustedIndex = lookAhead+2-i
			local segmentIndex = streamIndex + i - 1
			local text = VOLT26.GameplayStats.GetMeasureText(currMeasure, segments, segmentIndex, isLookAhead)
			bmt[adjustedIndex]:settext(text)
			-- We can hit nil when we've run out of streams/breaks for the song. Just hide these BMTs.
			if segments[segmentIndex] == nil then
				bmt[adjustedIndex]:visible(false)

			-- rest count
			elseif segments[segmentIndex].isBreak then
				-- Make rest lookaheads be lighter than active rests.
				if not isLookAhead then
					bmt[adjustedIndex]:diffuse(0.5, 0.5, 0.5 ,1)
				else
					bmt[adjustedIndex]:diffuse(0.4, 0.4, 0.4 ,1)
				end

			-- stream count
			else
				-- Make stream lookaheads be lighter than active streams.
				if not isLookAhead then
					if string.find(text, "/") then
						bmt[adjustedIndex]:diffuse(1, 1, 1, 1)
					else
						-- If this is a mini-break, make it lighter.
						bmt[adjustedIndex]:diffuse(0.5, 0.5, 0.5 ,1)
					end
				else
					bmt[adjustedIndex]:diffuse(0.45, 0.45, 0.45 ,1)
				end
			end
		end
	end
end

-- I'm not crazy about special-casing "Wendy" to use
-- _wendy small for the Measure/Rest counter, but
-- I'm hesitant to visually alter a feature that
-- so many players have become so reliant on...
local font = mods.ComboFont
if font == "Wendy" or font == "Wendy (Cursed)" then
	font = "Wendy/_wendy small"
else
	font = "_Combo Fonts/" .. font .. "/"
end

-- -----------------------------------------------------------------------

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:xy(GetNotefieldX(player), layout.y)
		self:queuecommand("SetUpdate")
	end,
	SetUpdateCommand=function(self) self:SetUpdateFunction( Update ) end,

	CurrentSongChangedMessageCommand=function(self)
		InitializeMeasureCounter()
	end,
}

-- We iterate backwards since we want the lookaheads to be drawn first in the case the
-- main measure counter expands into them.
for i=lookAhead+1,1,-1 do
	af[#af+1] = LoadFont(font)..{
		InitCommand=function(self)
			-- Add to the collection of BMTs so our AF's update function can easily access them.
			bmt[#bmt+1] = self

			local width = GetNotefieldWidth()
			local NumColumns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
			local columnWidth = width/NumColumns

			-- Have descending zoom sizes for each new BMT we add.
			self:zoom(0.35 - 0.05 * (i-1)):shadowlength(1):horizalign(center)
			self:x(columnWidth * (0.7 * (i-1)))

			if mods.MeasureCounterLeft then
				self:addx(-columnWidth)
			end
		end
	}
end

return af
