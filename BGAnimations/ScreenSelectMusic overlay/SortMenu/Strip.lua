-- The category strip: the bar of text pills that floats above the dock while a
-- category is open.
--
-- A category's entries are words, not pictures -- there is no icon that says
-- "sort by BPM, ascending" -- so the strip keeps the dock's square frame and
-- its magnification but sets each entry as a name and the figure that belongs
-- to it.  The bar hugs its content; when the content is wider than the screen
-- allows, the bar stops growing and the content slides inside it so the
-- focused pill stays in the middle.

local L = ...

local Strip = {}

local function pillWidth(name, meta, active)
	local width = L.PillPadX*2 + name
	if meta > 0 then width = width + L.PillTextGap + meta end
	if active then width = width + 18 end
	return width
end

function Strip.Build()
	local af = Def.ActorFrame{
		Name="Strip",
		InitCommand=function(self) self:visible(false) end,
	}

	af[#af+1] = Def.Quad{
		Name="BarFill",
		InitCommand=function(self)
			self:y(L.StripMid):zoomto(100, L.StripH):diffuse(L.Panel):diffusealpha(0.96)
		end,
	}

	local barEdge = L.Frame("BarEdge", L.Line)
	barEdge.InitCommand = function(self)
		self:y(L.StripMid)
		L.SizeFrame(self, 100, L.StripH, 1)
	end
	af[#af+1] = barEdge

	local pills = Def.ActorFrame{Name="Pills"}
	for index = 1, L.MaxPills do
		local pill = Def.ActorFrame{
			Name = "Pill"..index,
			InitCommand=function(self) self:y(L.StripMid) end,
		}
		pill[#pill+1] = Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:zoomto(100, L.PillH):diffuse(L.Panel2):diffusealpha(0.55)
			end,
		}
		local edge = L.Frame("Edge", L.Line)
		edge.InitCommand = function(self) L.SizeFrame(self, 100, L.PillH, 1) end
		pill[#pill+1] = edge
		pill[#pill+1] = Def.Quad{
			Name="Mark",
			InitCommand=function(self) self:zoomto(8, 8):diffuse(L.Accent):visible(false) end,
		}
		pill[#pill+1] = L.DisplayText{Name="Name", Px=L.PillNamePx, Tint=L.Mute, Align=left}
		pill[#pill+1] = L.LabelText{Name="Meta", Px=L.PillMetaPx, Tint=L.Dim, Align=left}
		pills[#pills+1] = pill
	end
	af[#af+1] = pills

	return af
end

-- descriptors: the open category's entries, in order.  `index` is the cursor's
-- place in them, `focused` says whether the cursor is in this strip at all.
function Strip.Apply(af, descriptors, index, focused)
	if not af then return end

	descriptors = descriptors or {}
	local count = #descriptors
	if count == 0 then
		af:visible(false)
		return
	end
	af:visible(true)

	-- A category longer than the pool is shown through a window that keeps the
	-- cursor near its middle.
	local first = 1
	if count > L.MaxPills then
		first = math.max(1, math.min(index - math.floor(L.MaxPills/2), count - L.MaxPills + 1))
	end

	local shown = math.min(L.MaxPills, count)
	local widths, offsets = {}, {}
	local total = 0

	for slot = 1, L.MaxPills do
		local pill = af:GetChild("Pills"):GetChild("Pill"..slot)
		local descriptor = slot <= shown and descriptors[first + slot - 1] or nil
		if not descriptor then
			pill:visible(false)
		else
			local name = pill:GetChild("Name")
			local meta = pill:GetChild("Meta")

			L.SetDisplay(name, L.Upper(descriptor.Name or ""), L.PillNamePx, 520)
			L.SetLabel(meta, descriptor.Meta or "", L.PillMetaPx, 320)

			local metaWidth = (descriptor.Meta and descriptor.Meta ~= "") and meta:GetZoomedWidth() or 0
			meta:visible(metaWidth > 0)

			local width = pillWidth(name:GetZoomedWidth(), metaWidth, descriptor.Active)
			widths[slot] = width
			offsets[slot] = total + width/2
			total = total + width + L.PillGap
		end
	end
	if total > 0 then total = total - L.PillGap end

	local barWidth = math.min(L.MaxBarW, total + L.BarPadX*2)
	local inner = barWidth - L.BarPadX*2

	-- Where the content starts, in the bar's own coordinates: centred while it
	-- fits, and otherwise slid so the focused pill sits in the middle without
	-- either end of the list pulling away from its edge.
	local start
	local cursorSlot = index - first + 1
	if total <= inner then
		start = -total/2
	else
		start = -(offsets[cursorSlot] or total/2)
		start = math.max(-total + inner/2, math.min(start, -inner/2))
	end

	local pills = af:GetChild("Pills")
	pills:finishtweening():decelerate(0.12):x(start)

	local fill = af:GetChild("BarFill")
	fill:finishtweening():decelerate(0.12):zoomto(barWidth, L.StripH)
	L.SizeFrame(af:GetChild("BarEdge"), barWidth, L.StripH, 1, L.Line)

	for slot = 1, L.MaxPills do
		local pill = pills:GetChild("Pill"..slot)
		local descriptor = widths[slot] and descriptors[first + slot - 1] or nil
		if descriptor then
			local width = widths[slot]
			local centre = offsets[slot]
			-- When the content is wider than the bar, a pill that would hang over
			-- an edge is left out rather than drawn cut in half.
			local left = start + centre - width/2
			local right = start + centre + width/2
			local outside = total > inner and (left < -inner/2 - 1 or right > inner/2 + 1)

			pill:visible(not outside):x(centre)

			local pillFill = pill:GetChild("Fill")
			local edge     = pill:GetChild("Edge")
			local mark     = pill:GetChild("Mark")
			local name     = pill:GetChild("Name")
			local meta     = pill:GetChild("Meta")

			local textLeft = -width/2 + L.PillPadX
			if descriptor.Active then
				mark:visible(true):x(textLeft + 4)
				textLeft = textLeft + 18
			else
				mark:visible(false)
			end
			name:x(textLeft)
			meta:x(textLeft + name:GetZoomedWidth() + L.PillTextGap)

			local enabled = descriptor.Enabled ~= false
			local isCursor = focused and (first + slot - 1) == index

			pill:finishtweening()
			pillFill:zoomto(width, L.PillH)
			pill:decelerate(0.09):zoom(isCursor and L.PillZoom or 1)

			if isCursor and enabled then
				pillFill:diffuse(L.Deep):diffusealpha(1)
				L.SizeFrame(edge, width, L.PillH, 2, L.Accent)
				name:diffuse(L.Ink)
				meta:diffuse(L.Accent)
			elseif isCursor then
				pillFill:diffuse(L.Panel2):diffusealpha(1)
				L.SizeFrame(edge, width, L.PillH, 2, L.Dim)
				name:diffuse(L.Mute)
				meta:diffuse(L.Dim)
			else
				pillFill:diffuse(L.Panel2):diffusealpha(enabled and 0.55 or 0.25)
				L.SizeFrame(edge, width, L.PillH, 1, descriptor.Active and L.Border or L.Line)
				name:diffuse(enabled and L.Mute or L.Fade(L.Dim, 0.6))
				meta:diffuse(enabled and L.Dim or L.Fade(L.Dim, 0.6))
			end
		else
			pill:visible(false)
		end
	end
end

return Strip
