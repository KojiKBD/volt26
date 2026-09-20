-- The demonstration stepchart the Quick Mods preview scrolls.
--
-- A real chart preview answers "what am I about to play"; this one answers a
-- different question -- "what will my settings look like" -- so it has to be
-- the same every time.  A player who learns to read it once can compare a speed
-- mod, a note skin or a perspective against the same bars they saw last time,
-- which a song-dependent preview can never give them.
--
-- Density follows the difficulty the player has selected, so the picture still
-- resembles what they are about to play: the lower slots stay on quarters, and
-- eighths, sixteenths and twenty-fourths arrive as the meter climbs.

VOLT26.DemoChart = {}

-- One beat is divided into 24 rows, so quarters (24), eighths (12), twelfths
-- (8), sixteenths (6) and twenty-fourths (4) all land on whole numbers.
local ROWS_PER_BEAT = 24
local ROWS_PER_MEASURE = ROWS_PER_BEAT * 4
local MEASURES = 4

-- The demo runs at a plain 150, which is what turns its beats into seconds for
-- a player on a C-mod.  Nothing reads it as a claim about the selected song.
VOLT26.DemoChart.Bpm = 150

-- Columns are taken in this order rather than at random: consecutive notes land
-- on different panels, so a run reads as a run instead of as a stack.
local columnOrder = {1, 4, 2, 3, 4, 1, 3, 2, 1, 3, 4, 2, 3, 2, 1, 4}

-- Each difficulty is a plan of four measures, in rows from the measure's start.
-- Written out rather than generated so the shape is a fixed thing a player can
-- recognise, and so a change to one slot cannot disturb another.
local plans = {
	Beginner = {
		{0, 48},
		{0, 48},
		{0, 48},
		{0, 24, 48},
	},
	Easy = {
		{0, 24, 48, 72},
		{0, 24, 48, 72},
		{0, 48, 60, 72},
		{0, 24, 48, 72},
	},
	Medium = {
		{0, 24, 48, 72},
		{0, 12, 24, 36, 48, 60, 72, 84},
		{0, 24, 36, 48, 72},
		{0, 12, 24, 36, 48, 60, 72, 84},
	},
	Hard = {
		{0, 12, 24, 36, 48, 60, 72, 84},
		{0, 12, 18, 24, 30, 36, 48, 60, 72, 84},
		{0, 12, 24, 36, 48, 60, 72, 84},
		{0, 6, 12, 18, 24, 30, 36, 42, 48, 60, 72, 84},
	},
	Challenge = {
		{0, 6, 12, 18, 24, 30, 36, 42, 48, 60, 72, 84},
		{0, 6, 12, 18, 24, 28, 32, 36, 40, 44, 48, 54, 60, 66, 72, 78, 84, 90},
		{0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 84},
		{0, 4, 8, 12, 16, 20, 24, 30, 36, 42, 48, 54, 60, 66, 72, 78, 84, 90},
	},
}

-- What each difficulty adds on top of its plan: the second note of a jump, a
-- hold, a mine.  Measures and rows are counted the same way as above.
local extras = {
	Medium = {
		holds = {{measure = 2, row = 72, column = 2, length = 24}},
	},
	Hard = {
		jumps = {{measure = 0, row = 0, column = 4}, {measure = 2, row = 0, column = 1}},
		holds = {{measure = 2, row = 48, column = 3, length = 36}},
	},
	Challenge = {
		jumps = {{measure = 0, row = 0, column = 3}, {measure = 2, row = 0, column = 2}},
		holds = {{measure = 1, row = 48, column = 4, length = 24}},
		mines = {{measure = 3, row = 36, column = 1}},
	},
}

local function quantization(row)
	for _, pair in ipairs({{24, 4}, {12, 8}, {8, 12}, {6, 16}, {4, 24}}) do
		if row % pair[1] == 0 then return pair[2] end
	end
	return 32
end

local function shortDifficulty(difficulty)
	local name = difficulty and ToEnumShortString(difficulty) or "Medium"
	if plans[name] then return name end
	-- Edit charts and anything else the engine can hand over are read as the
	-- hardest slot, which is the one that shows every rhythm.
	return "Challenge"
end

local cache = {}

-- Build(difficulty) -> notes, holds, beats
--
-- The two lists carry the same fields VOLT26.Simfile.Notes produces, so a
-- drawing routine cannot tell a demo chart from a real one.
function VOLT26.DemoChart.Build(difficulty)
	local name = shortDifficulty(difficulty)
	if cache[name] then return cache[name].notes, cache[name].holds, cache[name].beats end

	local secondsPerRow = 60 / VOLT26.DemoChart.Bpm / ROWS_PER_BEAT
	local notes, holds = {}, {}

	local function put(row, column, kind)
		notes[#notes+1] = {
			Column = column,
			Beat = row / ROWS_PER_BEAT,
			Time = row * secondsPerRow,
			Quantization = quantization(row % ROWS_PER_MEASURE),
			Kind = kind or "tap",
		}
	end

	local taken = 0
	for measure = 0, MEASURES - 1 do
		for _, row in ipairs(plans[name][measure + 1]) do
			taken = taken + 1
			put(measure * ROWS_PER_MEASURE + row, columnOrder[(taken - 1) % #columnOrder + 1])
		end
	end

	local extra = extras[name]
	if extra then
		for _, jump in ipairs(extra.jumps or {}) do
			put(jump.measure * ROWS_PER_MEASURE + jump.row, jump.column)
		end
		for _, mine in ipairs(extra.mines or {}) do
			put(mine.measure * ROWS_PER_MEASURE + mine.row, mine.column, "mine")
		end
		for _, hold in ipairs(extra.holds or {}) do
			local row = hold.measure * ROWS_PER_MEASURE + hold.row
			holds[#holds+1] = {
				Column = hold.column,
				Beat = row / ROWS_PER_BEAT,
				Time = row * secondsPerRow,
				EndBeat = (row + hold.length) / ROWS_PER_BEAT,
				EndTime = (row + hold.length) * secondsPerRow,
				Quantization = quantization(row % ROWS_PER_MEASURE),
				Kind = "hold",
			}
		end
	end

	table.sort(notes, function(a, b) return a.Beat < b.Beat end)
	cache[name] = {notes = notes, holds = holds, beats = MEASURES * 4}
	return notes, holds, MEASURES * 4
end

-- The most notes any difficulty can put on screen at once, which is what a
-- drawing routine has to size its pools for.
function VOLT26.DemoChart.MaxNotes()
	local most = 0
	for name in pairs(plans) do
		local notes = VOLT26.DemoChart.Build("Difficulty_" .. name)
		most = math.max(most, #notes)
	end
	return most
end
