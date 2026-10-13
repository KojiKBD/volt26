-- VOLT26 chart radar.
--
-- Turns the engine's per-chart tech counts and NPS-per-measure data into five
-- normalized axes, so Song Select can draw a star-shaped notes radar instead of
-- a line of raw counters.
--
-- Behavior only: this module never creates actors and never reads GAMESTATE.
-- Callers pass in what they already have and get back plain tables.

VOLT26 = VOLT26 or {}

local ChartRadar = {}

-- Axis order is also the drawing order: axis 1 sits at the top point of the
-- star and the rest run clockwise.  The order follows the owner's artwork:
-- STREAM, XOVER, FOOTSWITCH, BRACKETS, SIDESWITCH.  JACK is not on the star;
-- the engine still reports it and Layout.lua still collects it, but no axis
-- reads it.
--
-- Every axis is a fraction, so nothing here depends on how long a chart is or
-- what rate it is played at.  The tech axes are "how much of this chart is
-- that pattern": the category's count divided by the chart's total notes.
-- STREAM is already a fraction of the chart's measures.
--
-- `Cap` is the fraction that fills an axis completely.  The caps are tuned by
-- eye against ITG-style charts and are deliberately generous, because a chart
-- that pins an axis should stay rare enough to mean something.  Every consumer
-- follows whatever is set here.
local axes = {
	{ Key="Stream",       Label="STREAM",     Short="ST", Category=nil,                              Cap=1.00, OfNotes=false },
	{ Key="Crossovers",   Label="XOVER",      Short="XO", Category="TechCountsCategory_Crossovers",   Cap=0.10, OfNotes=true  },
	{ Key="Footswitches", Label="FOOTSWITCH", Short="FS", Category="TechCountsCategory_Footswitches", Cap=0.10, OfNotes=true  },
	{ Key="Brackets",     Label="BRACKETS",   Short="BR", Category="TechCountsCategory_Brackets",     Cap=0.06, OfNotes=true  },
	{ Key="Sideswitches", Label="SIDESWITCH", Short="SW", Category="TechCountsCategory_Sideswitches", Cap=0.03, OfNotes=true  },
}

-- Display tuning.
--
-- The caps above decide what "full" means; these three knobs decide how the
-- reading between empty and full is drawn.  They exist because raw ratios
-- compress badly at the bottom: real charts spend most of their axes in the
-- first few percent, and drawn honestly the polygon collapses into a dot that
-- says less than the counter line it replaced.
--
--   Gain  multiplies the normalized reading before the curve.  Raise it to
--         push the whole polygon outwards.
--   Gamma bends the curve; lower lifts small readings harder.  1 is linear.
--   Base  the share of the radius every axis draws at even when it reads zero.
--         Without it a chart whose only strong axis is STREAM draws as a single
--         needle with no area at all; with it the shape always has a body and
--         the peaks rise out of that.  The cost is deliberate and worth naming:
--         an axis at zero is no longer distinguishable from a very low one.
--
-- Only the drawn `Scaled` value passes through these.  `Value` stays the honest
-- reading, which is what the calibration readout in PlayerChart.lua prints.
local displayGain = 1.35
local displayGamma = 0.50
local baseRadius = 0.22

-- A measure of 16ths at `bpm` runs at bpm/15 notes per second.  Allow a little
-- slack so rounding in the engine's NPS values does not drop a stream measure.
local streamTolerance = 0.97

-- GetAxes() -> the axis definitions above, in drawing order.
-- Read-only by convention; callers must not mutate the returned table.
function ChartRadar.GetAxes()
	return axes
end

-- GetAxisCount() -> how many axes the radar has (the star's point count).
function ChartRadar.GetAxisCount()
	return #axes
end

-- ComputeStream(npsPerMeasure, bpm) -> 0..1
--
-- The fraction of the charted span, first noted measure to last, that runs at
-- 16ths or faster.  Empty leading and trailing measures are excluded so a long
-- intro does not read as a break.
--
-- Charts with BPM changes are approximated with a single reference BPM: pass
-- the chart's fastest BPM and a slower section inside it correctly reads as a
-- break.  A chart that is fast only in its slowest section is the case this
-- approximation gets wrong, and it is rare enough to accept.
function ChartRadar.ComputeStream(npsPerMeasure, bpm)
	if type(npsPerMeasure) ~= "table" or #npsPerMeasure == 0 then return 0 end
	bpm = tonumber(bpm)
	if not bpm or bpm <= 0 then return 0 end

	local first, last
	for i=1, #npsPerMeasure do
		if (tonumber(npsPerMeasure[i]) or 0) > 0 then
			first = first or i
			last = i
		end
	end
	if not first then return 0 end

	local threshold = (bpm/15) * streamTolerance
	local stream = 0
	for i=first, last do
		if (tonumber(npsPerMeasure[i]) or 0) >= threshold then stream = stream + 1 end
	end
	return stream / (last - first + 1)
end

-- Build(source) -> { {Key, Label, Short, Raw, Value, Scaled}, ... }
--
-- source.TechCounts table of raw counts keyed by axis Key
-- source.Stream     0..1, from ComputeStream
-- source.TotalNotes the chart's note count, the denominator for the tech axes
--
-- Raw    - the fraction itself: tech count over total notes, or the stream
--          fraction, before normalizing against the axis cap
-- Value  - Raw/Cap clamped to 0..1, the honest reading
-- Scaled - Value after the display gamma; this is what the polygon draws
function ChartRadar.Build(source)
	source = source or {}
	local counts = source.TechCounts or {}
	local notes = tonumber(source.TotalNotes) or 0

	local built = {}
	for i, axis in ipairs(axes) do
		local raw
		if axis.OfNotes then
			raw = notes > 0 and ((tonumber(counts[axis.Key]) or 0) / notes) or 0
		else
			raw = tonumber(source[axis.Key]) or 0
		end

		local value = raw / axis.Cap
		if value < 0 then value = 0 elseif value > 1 then value = 1 end

		local scaled = baseRadius
		if value > 0 then
			scaled = (value * displayGain)^displayGamma
			if scaled > 1 then scaled = 1 end
			if scaled < baseRadius then scaled = baseRadius end
		end

		built[i] = {
			Key    = axis.Key,
			Label  = axis.Label,
			Short  = axis.Short,
			Raw    = raw,
			Value  = value,
			Scaled = scaled,
		}
	end
	return built
end

-- StarRadii(built, innerRatio) -> tips, valleys
--
-- The radar is drawn as a star: one point per axis, and between every two
-- points a valley that pulls back towards the centre.  Both come back as
-- fractions of the full radius, so the caller only multiplies by its own size.
--
-- tips[i]    - built[i].Scaled, the reading of axis i
-- valleys[i] - the valley between axis i and axis i+1 (the last one closes
--              back to axis 1): innerRatio times the mean of its two
--              neighbours.  A valley follows the points either side of it, so a
--              chart at full on every axis draws exactly the full star, and a
--              strong axis rises as a point instead of dragging its neighbours'
--              valleys out with it.
function ChartRadar.StarRadii(built, innerRatio)
	built = built or {}
	innerRatio = tonumber(innerRatio) or 0.4
	local count = #axes
	local tips, valleys = {}, {}
	for i=1, count do
		local entry = built[i]
		tips[i] = entry and tonumber(entry.Scaled) or baseRadius
	end
	for i=1, count do
		local nextTip = tips[i % count + 1]
		valleys[i] = innerRatio * (tips[i] + nextTip) / 2
	end
	return tips, valleys
end

VOLT26.ChartRadar = ChartRadar
