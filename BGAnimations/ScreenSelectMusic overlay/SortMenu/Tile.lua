-- One tile of the dock.
--
-- A tile is an icon and a word on the dock's black slab.  It is built once and
-- holds its place; what changes as the cursor travels is which option it
-- carries and how large it is drawn.  The box grows from its bottom edge so the
-- row of words underneath stays on one line whatever is magnified above it.
--
-- Persona dress: the owner's red icons sit straight on the slab.  The tile
-- under the cursor turns its icon to the outlined hover twin and slaps it on a
-- tilted white card over a red one, and its word turns black on a white tag.
-- The category whose strip is open keeps the red card and a red word.

local L, Icons = ...

local Tile = {}

local CARD = 0.9            -- the white card, of the tile's size
local CARD_TURN = -6
local BACKING = 0.96        -- the red card behind it
local BACKING_TURN = 8
local GREY = color("#5a5a64")
local OFF = {0.45, 0.45, 0.45, 0.55}

-- What each tile currently shows, so a repaint only touches a texture when the
-- option or the state under the tile has actually changed, and the card only
-- pops when the cursor has just arrived.
local showing = setmetatable({}, {__mode="k"})
local wasFocused = setmetatable({}, {__mode="k"})

local function iconZoom() return L.IconSize/L.IconSource end

function Tile.Build(index)
	local af = Def.ActorFrame{Name="Tile"..index}

	local box = Def.ActorFrame{
		Name="Box",
		InitCommand=function(self) self:y(L.TileBottom) end,
	}

	box[#box+1] = Def.Quad{
		Name="Backing",
		InitCommand=function(self)
			self:y(-L.TileSize/2):zoomto(L.TileSize*BACKING, L.TileSize*BACKING)
				:rotationz(BACKING_TURN):diffuse(L.Red):visible(false)
		end,
	}
	box[#box+1] = Def.Quad{
		Name="Card",
		InitCommand=function(self)
			self:y(-L.TileSize/2):zoomto(L.TileSize*CARD, L.TileSize*CARD)
				:rotationz(CARD_TURN):diffuse(L.White):visible(false)
		end,
	}
	box[#box+1] = Def.Sprite{
		Name="Icon",
		InitCommand=function(self)
			self:Load(Icons.Path(Icons.Fallback)):y(-L.TileSize/2):zoom(iconZoom())
		end,
	}

	af[#af+1] = box
	af[#af+1] = Def.Quad{
		Name="TagFill",
		InitCommand=function(self) self:y(L.LabelY):skewx(L.Slant):diffuse(L.White):visible(false) end,
	}
	af[#af+1] = L.TagText{Name="Label", Px=L.LabelPx, Y=L.LabelY, Tint=L.White, Align=center, Width=L.TileSize + L.TileGap}

	return af
end

-- state: {X=<design x>, Focused=bool, Distance=<steps from the cursor>,
--         Open=<its category is open>}
function Tile.Apply(af, descriptor, state)
	if not af then return end

	if not descriptor then
		af:visible(false)
		wasFocused[af] = false
		return
	end
	af:visible(true):x(state.X or 0)

	local box     = af:GetChild("Box")
	local backing = box:GetChild("Backing")
	local card    = box:GetChild("Card")
	local icon    = box:GetChild("Icon")
	local tag     = af:GetChild("TagFill")
	local label   = af:GetChild("Label")

	local enabled = descriptor.Enabled ~= false
	local focused = state.Focused == true
	local arrived = focused and not wasFocused[af]
	wasFocused[af] = focused

	local name = Icons.Name(descriptor.Key)
	local path = Icons.Path(name, focused and enabled)
	if showing[af] ~= path then
		icon:Load(path)
		showing[af] = path
	end

	L.SetTag(label, descriptor.Short or descriptor.Name or "", L.LabelPx, L.TileSize + L.TileGap)

	local zoom = L.TileZoom[(state.Distance or 9) + 1] or 1

	box:finishtweening()
	icon:finishtweening()
	label:finishtweening()
	card:finishtweening()
	backing:finishtweening()

	box:decelerate(0.09):zoom(zoom)
	icon:zoom(iconZoom()):rotationz(0)

	-- Line-art icons (BACK, the neutral mark) take the tile's tint; the
	-- owner's icons keep their own colours and are only greyed when off.
	local tinted = Icons.Tinted(name)
	local function iconTint(onCard)
		if not enabled then return OFF end
		if tinted and (onCard or descriptor.IsBack) then return L.Red end
		return L.White
	end

	if focused then
		backing:visible(true):rotationz(BACKING_TURN):zoom(1)
			:diffuse(enabled and L.Red or L.Fade(GREY, 0.6))
		card:visible(true):rotationz(CARD_TURN):zoom(1)
			:diffuse(enabled and L.White or GREY)
		icon:diffuse(iconTint(true))
		if arrived then
			-- The card is slapped down: it lands turned and a little large,
			-- the red one behind it a beat later, and the icon kicks.
			card:zoom(1.35):rotationz(CARD_TURN - 14):decelerate(0.12):zoom(1):rotationz(CARD_TURN)
			backing:zoom(0.6):rotationz(BACKING_TURN + 20):sleep(0.03)
				:decelerate(0.12):zoom(1):rotationz(BACKING_TURN)
			icon:rotationz(-12):zoom(iconZoom()*0.8)
				:decelerate(0.14):rotationz(0):zoom(iconZoom())
		end
		local width = math.min(label:GetZoomedWidth(), L.TileSize + L.TileGap) + 18
		tag:visible(true):zoomto(width, L.LabelPx + 12):diffuse(enabled and L.White or GREY)
		label:diffuse(L.Black)
	elseif state.Open then
		-- The category whose strip is showing keeps its red card while the
		-- cursor is up in that strip, so the two bars read as one place.
		backing:visible(true):rotationz(BACKING_TURN):zoom(1):diffuse(L.Red)
		card:visible(false)
		tag:visible(false)
		icon:diffuse(L.White)
		label:diffuse(L.Red)
	else
		backing:visible(false)
		card:visible(false)
		tag:visible(false)
		icon:diffuse(iconTint(false))
		label:decelerate(0.09):diffuse(enabled and L.White or L.Fade(L.Mute, 0.6))
	end
end

return Tile
