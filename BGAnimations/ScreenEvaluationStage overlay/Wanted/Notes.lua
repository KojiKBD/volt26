-- The NOTES page of one side: Simply Love's per-column judgments in the
-- artwork's NOTES container.  The player's noteskin arrows (as Simply Love's
-- per-column pane shows them, _modules/NoteSkinPreview.lua) head the columns;
-- the rows are the seven judgments in their colours, and every column's
-- counts sit under its arrow in the row's colour.
--
-- p = { Art, T, player, mirror, row colours ROW = {key = {bright, dim}}, OFF }
local p = ...
local Art, T, mirror, ROW, OFF = p.Art, p.T, p.mirror, p.ROW, p.OFF
local notes = Art.notes
local data = VOLT26.EvaluationPage.GetColumns(p.player)
local rows = notes.rows

-- Column centres: the artwork's four arrows, spread evenly between the first
-- and the last for another column count, mirrored for player 2 (still left
-- to right).
local first, last = notes.arrows[1], notes.arrows[#notes.arrows]
local centres = {}
local count = #data.columns
for index = 1, count do
	local pt
	if count == #notes.arrows then
		pt = notes.arrows[index]
	else
		local f = count > 1 and (index - 1) / (count - 1) or 0.5
		pt = { first[1] + (last[1] - first[1]) * f, first[2] + (last[2] - first[2]) * f }
	end
	centres[index] = { pt[1], pt[2] }
end
if mirror then
	for _, pt in ipairs(centres) do pt[1] = 1920 - pt[1] end
	table.sort(centres, function(a, b) return a[1] < b[1] end)
end
-- Narrower spacing for many columns: the arrows shrink with it.
local spacing = count > 1 and math.abs(centres[count][1] - centres[1][1]) / (count - 1) or notes.arrowSize
local arrowSize = math.min(notes.arrowSize, spacing * 0.95)

local af = Def.ActorFrame{ Name="Notes" }

for index, column in ipairs(data.columns) do
	local centre = centres[index]
	af[#af+1] = LoadActor(THEME:GetPathB("", "_modules/NoteSkinPreview.lua"),
		{ noteskin_name = data.noteskin, column = column.name })..{
		OnCommand=function(self)
			-- Noteskin arrows are drawn about 64 px wide.
			self:xy(centre[1], centre[2]):zoom(arrowSize / 64):visible(true)
		end,
	}
end

-- A row's baseline at x, following the row's slight turn.
local function rowY(index, x)
	local r = math.rad(mirror and -rows.rot or rows.rot)
	local x0 = mirror and 1920 - rows.x or rows.x
	return rows.y + (index - 1) * rows.lineGap + (x - x0) * math.tan(r)
end

local countSize = rows.size * (count > 4 and 4 / count + 0.2 or 1)
for index, key in ipairs(VOLT26.EvaluationPage.RowKeys) do
	local bright = data.enabled[key] and ROW[key][1] or OFF
	local anchor = { x = rows.x, y = rows.y + (index - 1) * rows.lineGap, rot = rows.rot, sx = rows.sx, sy = rows.sy }
	af[#af+1] = T.Run(anchor, {
		{ font = "Label", size = rows.size, color = bright, text = VOLT26.EvaluationPage.RowLabels[key] },
	}, mirror)
	for c, column in ipairs(data.columns) do
		local x = centres[c][1]
		local value = tostring(column.counts[key])
		local tint = bright
		-- Without the FA+ window the 10/15 ms Fantastic is not recorded per
		-- column: every Fantastic is in the white row.
		if key == "W0" and not data.splitFantastic then value, tint = "-", ROW.W0[2] end
		af[#af+1] = LoadFont(T.Font.Label)..{
			InitCommand=function(self)
				self:halign(0.5):valign(1):xy(x, rowY(index, x)):zoom(countSize / T.EM.Label)
					:zoomx(countSize / T.EM.Label * rows.sx):rotationz(mirror and -rows.rot or rows.rot)
					:diffuse(tint):settext(value)
				-- Keep a count inside its column.
				local fit = spacing * 0.92 / math.max(1, self:GetZoomedWidth())
				if fit < 1 then self:zoomx(self:GetZoomX() * fit) end
			end,
		}
	end
end

return af
