-- One row of the SortMenu list.
--
-- The rows are built once and stay where they are; paging moves which option
-- each row shows rather than moving the rows themselves.  That is the whole
-- difference from the wheel this replaces: the cursor travels and the list
-- holds still, so a player can learn where an option sits.

local L = ...

local Row = {}

-- Every row is drawn from its own top-left corner at the left edge of the list
-- column, so the figures below are offsets into the row rather than screen
-- positions.
local nameWidth = L.MetaX - L.NameX - 260

function Row.Build(index)
	local af = Def.ActorFrame{
		Name = "Row"..index,
		InitCommand=function(self)
			self:xy(L.ListX, L.ContentTop + (index-1)*L.RowPitch)
		end,
	}

	af[#af+1] = Def.Quad{
		Name="Fill",
		InitCommand=function(self)
			self:align(0,0):zoomto(L.ListW, L.RowH):diffuse(L.Panel):diffusealpha(0)
		end,
	}
	af[#af+1] = Def.Quad{
		Name="Tick",
		InitCommand=function(self)
			self:align(0,0.5):xy(0, L.RowH/2):zoomto(4, 30):diffuse(L.Line)
		end,
	}
	af[#af+1] = Def.Quad{
		Name="Separator",
		InitCommand=function(self)
			self:align(0,1):xy(0, L.RowH + L.RowGap/2):zoomto(L.ListW, 1)
				:diffuse(L.Line):diffusealpha(0.55)
		end,
	}

	af[#af+1] = L.LabelText{Name="Label", Px=13, X=L.LabelX-L.ListX, Y=L.RowH/2, Tint=L.Dim, Width=230}
	af[#af+1] = L.DisplayText{Name="Name",  Px=34, X=L.NameX-L.ListX,  Y=L.RowH/2, Tint=L.Mute, Width=nameWidth}
	af[#af+1] = L.LabelText{Name="Meta", Px=13, X=L.MetaX-L.ListX,  Y=L.RowH/2, Tint=L.Dim, Align=right, Width=320}

	return af
end

-- Paint a row from a descriptor.  `descriptor` nil means this row has nothing
-- to show on the current page, which happens on the last page of a long list.
function Row.Apply(af, descriptor, focused)
	if not af then return end

	local fill      = af:GetChild("Fill")
	local tick      = af:GetChild("Tick")
	local separator = af:GetChild("Separator")
	local label     = af:GetChild("Label")
	local name      = af:GetChild("Name")
	local meta      = af:GetChild("Meta")

	if not descriptor then
		af:visible(false)
		return
	end
	af:visible(true)

	L.SetLabel(label, descriptor.Label or "", 13, 230)
	L.SetDisplay(name, L.Upper(descriptor.Name or ""), 34, nameWidth)
	L.SetLabel(meta, descriptor.Meta or "", 13, 320)

	local enabled = descriptor.Enabled ~= false

	fill:finishtweening()
	tick:finishtweening()
	label:finishtweening()
	name:finishtweening()
	meta:finishtweening()

	if focused and enabled then
		-- The focused row washes from the deep red at its left edge back to the
		-- screen's own ground, so the accent reads as a source of light on the
		-- left rather than as a coloured band across the whole row.  The wash is
		-- opaque at both ends: per-corner alpha would be flattened by the
		-- diffusealpha every other branch here sets.
		fill:diffusealpha(1)
		L.WashX(fill, L.Deep, L.Bg)
		tick:decelerate(0.08):zoomto(6, L.RowH):diffuse(L.Accent)
		separator:visible(false)
		label:decelerate(0.08):diffuse(L.Accent)
		name:decelerate(0.08):diffuse(L.Ink)
		meta:decelerate(0.08):diffuse(L.Accent)
	elseif focused then
		-- Focused but unavailable: the cursor still has to be visible, so the
		-- row lights up in grey rather than in the accent.
		fill:diffusealpha(1)
		L.WashX(fill, L.Panel2, L.Bg)
		tick:decelerate(0.08):zoomto(6, L.RowH):diffuse(L.Dim)
		separator:visible(false)
		label:decelerate(0.08):diffuse(L.Dim)
		name:decelerate(0.08):diffuse(L.Mute)
		meta:decelerate(0.08):diffuse(L.Dim)
	else
		fill:diffuse(L.Panel):diffuseleftedge(L.Panel):diffuserightedge(L.Panel)
		fill:decelerate(0.08):diffusealpha(enabled and 0.30 or 0.12)
		tick:decelerate(0.08):zoomto(4, 30):diffuse(L.Line)
		separator:visible(true)
		label:decelerate(0.08):diffuse(enabled and L.Dim or L.Fade(L.Dim, 0.5))
		name:decelerate(0.08):diffuse(enabled and L.Mute or L.Dim)
		meta:decelerate(0.08):diffuse(enabled and L.Dim or L.Fade(L.Dim, 0.7))
	end

	-- Leaving the menu is the one destructive-looking choice here, so it keeps
	-- the accent even when the cursor is elsewhere.
	if descriptor.IsBack and not focused then
		name:diffuse(L.Fade(L.Accent, 0.75))
	end
end

return Row
