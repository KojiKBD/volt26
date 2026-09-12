-- One tile of the dock.
--
-- A tile is a square, an icon and a word.  It is built once and holds its
-- place; what changes as the cursor travels is which option it carries and how
-- large it is drawn.  The box grows from its bottom edge so the row of words
-- underneath stays on one line whatever is magnified above it.

local L, Icons = ...

local Tile = {}

-- Which icon each tile is currently showing, so a repaint only touches the
-- texture when the option under the tile has actually changed.
local showing = setmetatable({}, {__mode="k"})

function Tile.Build(index)
	local af = Def.ActorFrame{Name="Tile"..index}

	local box = Def.ActorFrame{
		Name="Box",
		InitCommand=function(self) self:y(L.TileBottom) end,
	}

	box[#box+1] = Def.Quad{
		Name="Fill",
		InitCommand=function(self)
			self:y(-L.TileSize/2):zoomto(L.TileSize, L.TileSize)
				:diffuse(L.Panel2):diffusealpha(0.55)
		end,
	}

	local frame = L.Frame("Edge", L.Line)
	frame.InitCommand = function(self)
		self:y(-L.TileSize/2)
		L.SizeFrame(self, L.TileSize, L.TileSize, 1)
	end
	box[#box+1] = frame

	box[#box+1] = Def.Sprite{
		Name="Icon",
		InitCommand=function(self)
			self:Load(Icons.Path(Icons.Fallback))
				:y(-L.TileSize/2):zoom(L.IconSize/L.IconSource):diffuse(L.Mute)
		end,
	}

	af[#af+1] = box
	af[#af+1] = L.LabelText{Name="Label", Px=L.LabelPx, Y=L.LabelY, Tint=L.Dim, Align=center, Width=L.TileSize + L.TileGap}

	return af
end

-- state: {X=<design x>, Focused=bool, Distance=<steps from the cursor>,
--         Dimmed=<the cursor is in the strip above>, Open=<its category is open>}
function Tile.Apply(af, descriptor, state)
	if not af then return end

	if not descriptor then
		af:visible(false)
		return
	end
	af:visible(true):x(state.X or 0)

	local box   = af:GetChild("Box")
	local fill  = box:GetChild("Fill")
	local edge  = box:GetChild("Edge")
	local icon  = box:GetChild("Icon")
	local label = af:GetChild("Label")

	local wanted = Icons.Name(descriptor.Key)
	if showing[af] ~= wanted then
		icon:Load(Icons.Path(wanted))
		icon:zoom(L.IconSize/L.IconSource)
		showing[af] = wanted
	end

	L.SetLabel(label, descriptor.Short or descriptor.Name or "", L.LabelPx, L.TileSize + L.TileGap)

	local enabled = descriptor.Enabled ~= false
	local zoom = L.TileZoom[(state.Distance or 9) + 1] or 1

	box:finishtweening()
	icon:finishtweening()
	label:finishtweening()

	box:decelerate(0.09):zoom(zoom)

	if state.Focused and enabled then
		fill:diffuse(L.Deep):diffusealpha(1)
		L.SizeFrame(edge, L.TileSize, L.TileSize, 2, L.Accent)
		icon:decelerate(0.09):diffuse(L.Accent)
		label:decelerate(0.09):diffuse(L.Accent)
	elseif state.Focused then
		-- Focused but unavailable: the cursor still has to be visible, so the
		-- tile lights up in grey rather than in the accent.
		fill:diffuse(L.Panel2):diffusealpha(1)
		L.SizeFrame(edge, L.TileSize, L.TileSize, 2, L.Dim)
		icon:decelerate(0.09):diffuse(L.Dim)
		label:decelerate(0.09):diffuse(L.Dim)
	elseif state.Open then
		-- The category whose strip is showing keeps a lit edge while the cursor
		-- is up in that strip, so the two bars read as one place.
		fill:diffuse(L.Deep):diffusealpha(0.7)
		L.SizeFrame(edge, L.TileSize, L.TileSize, 1, L.Border)
		icon:decelerate(0.09):diffuse(L.Mute)
		label:decelerate(0.09):diffuse(L.Mute)
	else
		fill:diffuse(L.Panel2):diffusealpha(enabled and 0.55 or 0.25)
		L.SizeFrame(edge, L.TileSize, L.TileSize, 1, L.Line)
		icon:decelerate(0.09):diffuse(enabled and L.Mute or L.Fade(L.Dim, 0.6))
		label:decelerate(0.09):diffuse(enabled and L.Dim or L.Fade(L.Dim, 0.6))
	end

	-- Leaving the menu is the one destructive-looking choice here, so it keeps a
	-- trace of the accent even when the cursor is elsewhere.
	if descriptor.IsBack and not state.Focused then
		icon:diffuse(L.Fade(L.Accent, 0.7))
	end
end

return Tile
