local args = ...
local H = args.H
local player = args.Player
local stripX = args.X
local stripW = args.Width
local pn = ToEnumShortString(player)

-- The chart preview: a vertical slice of the stepchart, scrolling, drawn as
-- rhythm-coloured diamonds rather than a notefield.  It exists to show what the
-- chart looks like, not to be played, so it carries no receptors, no hold
-- bodies and no noteskin.

local headerH = 24
local measurePitch = 52
local designLaneWidth = 38
local diamondRatio = 18/designLaneWidth
local notePool = 96
local measurePool = 14
-- Notes closer together than this in one column are fully hidden behind the one
-- above them at this pitch, so drawing them only costs pool slots.
local minColumnGap = 5
local fadeDepth = 28
-- How much of the chart the strip cycles through before returning to the start
-- of its window.
local loopMeasures = 32
local scrollMeasuresPerSecond = 1

local quantColors = {
	[4]  = color("#e04a3a"),
	[8]  = color("#3a7de0"),
	[16] = color("#8b45d6"),
}
local otherQuantColor = color("#e0a13a")
local mineColor = color("#8a8a94")
local transparent = color("0,0,0,0")

local columnCount = 4
do
	local style = GAMESTATE:GetCurrentStyle()
	local ok, count = pcall(function() return style:ColumnsPerPlayer() end)
	if ok and tonumber(count) and count > 0 then columnCount = count end
end
local laneWidth = math.min(designLaneWidth, (stripW - 16)/columnCount)
local diamondSize = laneWidth*diamondRatio
-- A square rotated a quarter turn is as wide as its diagonal, so the side that
-- draws an 18 unit diamond is 18 over root two.
local diamondSide = diamondSize/math.sqrt(2)
local laneOrigin = stripX + stripW/2 - (columnCount-1)*laneWidth/2

local function noteColor(note)
	if note.Kind == "mine" then return mineColor end
	return quantColors[note.Quantization] or otherQuantColor
end

-- The window worth showing is the busiest one: a preview of the first sixteen
-- measures of a chart that opens on silence says nothing about it.  The engine
-- already publishes notes per measure, so this costs nothing and answers before
-- the simfile is read, which is what lets the parse be bounded to the window.
local function busiestStart(nps, windowMeasures)
	local count = nps and #nps or 0
	if count <= windowMeasures then return 0 end
	local best, bestStart, running = -1, 0, 0
	for index = 1, count do
		running = running + (nps[index] or 0)
		if index > windowMeasures then running = running - (nps[index-windowMeasures] or 0) end
		if index >= windowMeasures and running > best then
			best, bestStart = running, index - windowMeasures
		end
	end
	return bestStart
end

-- Notes are ordered by position, so the first one that can be on screen is
-- found rather than scanned to: a long chart would otherwise walk its whole
-- note list every frame.
local function firstVisible(notes, position)
	local low, high = 1, #notes+1
	while low < high do
		local middle = math.floor((low+high)/2)
		if notes[middle].Position < position then low = middle+1 else high = middle end
	end
	return low
end

local function draw(self)
	local notes = self.notes
	local top, bottom = self.stripTop, self.stripBottom
	if not top then return end
	local first = top + diamondSize/2
	local last = bottom - diamondSize/2
	local origin = (self.startMeasure or 0) + (self.scroll or 0)

	local used = 0
	local lastInColumn = {}
	if notes and #notes > 0 then
		for index = firstVisible(notes, origin), #notes do
			local note = notes[index]
			local y = first + (note.Position - origin)*measurePitch
			if y > last then break end
			if note.Column <= columnCount then
				local previous = lastInColumn[note.Column]
				if not previous or y - previous >= minColumnGap then
					lastInColumn[note.Column] = y
					used = used + 1
					if used > notePool then break end
					self:GetChild("Note"..used)
						:visible(true)
						:xy(laneOrigin + (note.Column-1)*laneWidth, y)
						:diffuse(noteColor(note))
				end
			end
		end
	end
	for index = math.min(used, notePool)+1, notePool do
		self:GetChild("Note"..index):visible(false)
	end

	local lines = 0
	for measure = math.ceil(origin), math.ceil(origin) + measurePool do
		local y = first + (measure - origin)*measurePitch
		if y > last or lines >= measurePool then break end
		lines = lines + 1
		self:GetChild("Measure"..lines):visible(true):y(y)
	end
	for index = lines+1, measurePool do
		self:GetChild("Measure"..index):visible(false)
	end
end

local af = Def.ActorFrame{
	Name=pn.."ChartStrip",
	RefreshCommand=function(self)
		local joined = GAMESTATE:IsHumanPlayer(player)
		self:visible(joined)
		if not joined then return end

		local rowTop, rowHeight = H.RowGeometry(player)
		local stripTop = rowTop + headerH
		local stripBottom = rowTop + rowHeight
		self.stripTop = stripTop
		self.stripBottom = stripBottom

		self:GetChild("Border"):xy(stripX-1, rowTop-1):zoomto(stripW+2, rowHeight+2)
		self:GetChild("Background"):xy(stripX, rowTop):zoomto(stripW, rowHeight)
		self:GetChild("HeaderRule"):xy(stripX, stripTop):zoomto(stripW, 1)
		H.SetLabel(self:GetChild("Caption"), H.String("Preview"), 9, stripW-16)
		self:GetChild("Caption"):xy(stripX + stripW/2, rowTop + headerH/2)
		self:GetChild("TopFade"):xy(stripX, stripTop):zoomto(stripW, fadeDepth)
		self:GetChild("BottomFade"):xy(stripX, stripBottom):zoomto(stripW, fadeDepth)

		local chart = H.Chart(player)
		if chart ~= self.chart then
			self.chart = chart
			self.notes = nil
			local windowMeasures = math.max(1, math.ceil((stripBottom-stripTop)/measurePitch))
			local start = 0
			if chart and not GAMESTATE:IsCourseMode() then
				start = busiestStart(H.ChartData(player).nps, windowMeasures)
				local ok, notes = pcall(function()
					return VOLT26.Simfile.Measures(chart, player, start, start + loopMeasures + windowMeasures)
				end)
				if ok then self.notes = notes end
			end
			self.startMeasure = start
			-- Cycling past what was parsed would leave the strip empty, so the
			-- loop never runs past the window the notes came from.
			local available = #(self.notes or {}) > 0
				and (self.notes[#self.notes].Position - start - windowMeasures + 1) or 0
			self.loopSpan = math.max(1, math.min(loopMeasures, available))
			self.scroll = 0
		end
		draw(self)
	end,
	OnCommand=function(self)
		self:SetUpdateFunction(function(frame, delta)
			if not frame.notes or #frame.notes == 0 then return end
			frame.scroll = (frame.scroll + (delta or 0)*scrollMeasuresPerSecond) % frame.loopSpan
			draw(frame)
		end)
	end,
}

af[#af+1] = H.Rule{Name="Border"}
af[#af+1] = H.Rule{Name="Background", Tint=H.Panel}
af[#af+1] = H.Rule{Name="HeaderRule"}
af[#af+1] = H.LabelText{Name="Caption", Px=9, Tint=H.Dim, Align=center}

for index = 1, measurePool do
	af[#af+1] = Def.Quad{
		Name="Measure"..index,
		InitCommand=function(self)
			self:align(0,0.5):x(stripX):zoomto(stripW, 1):diffuse(H.Line):visible(false)
		end,
	}
end
for index = 1, notePool do
	af[#af+1] = Def.Quad{
		Name="Note"..index,
		InitCommand=function(self)
			self:align(0.5,0.5):zoomto(diamondSide, diamondSide):rotationz(45):visible(false)
		end,
	}
end

-- The strip has no clip of its own, so notes are only ever placed inside it and
-- these two fades carry the edges into the card colour.
af[#af+1] = Def.Quad{
	Name="TopFade",
	InitCommand=function(self)
		self:align(0,0):diffuse(H.Panel):diffusebottomedge(transparent)
	end,
}
af[#af+1] = Def.Quad{
	Name="BottomFade",
	InitCommand=function(self)
		self:align(0,1):diffuse(H.Panel):diffusetopedge(transparent)
	end,
}

return af
