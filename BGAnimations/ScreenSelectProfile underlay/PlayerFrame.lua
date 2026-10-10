-- One player's "WANTED" card on ScreenSelectProfile.
--
-- The card frame, the stock avatar, the PRESS START lettering and the arrow
-- wings come from the Illustrator layout (Graphics/VOLT26/ProfileSelect, a
-- 1920x1080 artboard); every position below is in artboard pixels.  The card is
-- built upright in its own coordinates and turned by its tilt: a red field with
-- concentric black rings drawn live as radio waves spreading from the bottom
-- right corner, the focused profile's avatar over it -- the profile's own
-- picture when it has one (VOLT26.Profile.GetAvatarPath), the stock avatar
-- otherwise -- and the white frame on top.  Beneath the card is the profile's
-- name in cutout lettering (VOLT26.Cutout).
--
-- The wings are the browse arrows: each shows only while there is a profile in
-- its direction.  Nothing here decides anything: the cursor lives in
-- Selection.lua, input in Input.lua, and this file redraws when they change.

local args = ...
local player = args.Player
local Selection = args.Selection
local avatars = args.Avatars
local pn = ToEnumShortString(player)

local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080

local function asset(name)
	return THEME:GetPathG("", "VOLT26/ProfileSelect/" .. name .. ".png")
end

-- Artboard geometry.  The P1 card is the left one in the design; P2's
-- PRESS START and name positions are the P1 ones carried through each card's
-- own transform.
local layout = {
	P1 = {
		center = {x = 441.75, y = 619.27}, rot = -8.46,
		press  = {x = 449.34, y = 629.24},
		name   = {x = 440.99, y = 821.34, rot = 0.67},
		-- right wing, left wing (triangle vertices)
		wings  = {
			{684.72, 790.24, 678.77, 826.57, 728.31, 808.4},
			{271.66, 867.84, 264.85, 831.66, 224.48, 865.64},
		},
	},
	P2 = {
		center = {x = 1490.91, y = 481.03}, rot = 3.64,
		press  = {x = 1498.5, y = 491.0},
		name   = {x = 1452.57, y = 681.94, rot = 3.64},
		wings  = {
			{1692.53, 667.38, 1686.58, 703.71, 1736.12, 685.54},
			{1278.44, 714.92, 1271.63, 678.74, 1231.27, 712.72},
		},
	},
}
local L = layout[pn]
local pressSize = {w = 409, h = 114}

-- The card in its own upright coordinates (card pixels from its top-left).
-- The frame and stock-avatar images carry an 8-pixel margin around the card.
local cardW, cardH = 304.04, 413.15
local imageMargin = 8
local customAvatar = {x = 15.81, y = 99.59, w = 271.95, h = 266.4}

-- Rings: radii and width from the design, spreading out from the corner.
local waves = {
	first = 43.6, step = 64.105, width = 30, count = 9, segments = 20,
	period = 1.6,   -- seconds for the rings to travel one step
	field = color("#E8002D"), ink = {0, 0, 0, 1},
}

-- Card-local point (card pixels from the top-left) to the card frame's
-- coordinates, which are centred on the card.
local function cx(u) return (u - cardW / 2) * sx end
local function cy(v) return (v - cardH / 2) * sy end

-- ----------------------------------------------------------------------------
-- The name: two cutout slots used alternately, so the name on screen stays
-- until its successor has finished rendering (about half a second).

local names = { slots = {}, active = 1, shown = nil, wanted = nil, pending = nil, direction = 0 }
local nameX, nameY = L.name.x * sx, L.name.y * sy
local slide = 40 * sx
local nameOpts = { base = 66 * sy, tiltDeg = -2 }
local nameMaxW, nameMaxH, nameMaxChars = 430 * sx, 120 * sy, 20

-- ----------------------------------------------------------------------------
-- The browse arrows sit either side of the name.  A long name would run over
-- them, so each arrow steps out by as much as the name needs, and back when a
-- shorter one replaces it.  The name's drawn width is worked out the way the
-- cutout slot frames it: Cutout.Layout is seeded by the text, so the same
-- string always lays out the same, and the slot shrinks it to fit maxW x maxH.
-- A name drawn as plain text instead is measured with the slot's fallback font.

local wingGap = 18 * sx
local wingInner = {
	-- innermost x of each triangle: the right wing's leftmost point, the left
	-- wing's rightmost one
	right = math.min(L.wings[1][1], L.wings[1][3], L.wings[1][5]) * sx,
	left = math.max(L.wings[2][1], L.wings[2][3], L.wings[2][5]) * sx,
}

local function NameWidth(frame, text)
	if not text or text == "" then return 0 end
	local chars = select(2, text:gsub("[^\128-\191]", ""))
	local layout = chars <= nameMaxChars and VOLT26.Cutout.Layout(text, nameOpts) or nil
	if layout then
		local b = layout.bounds
		local w, h = b[3] - b[1], b[4] - b[2]
		return w * math.min(1, nameMaxW / w, nameMaxH / h)
	end
	local measure = frame:GetChild("NameMeasure")
	measure:settext(text)
	return math.min(nameMaxW, measure:GetZoomedWidth())
end

local function PlaceWings(frame, text)
	local half = NameWidth(frame, text) / 2 + wingGap
	local right = math.max(0, nameX + half - wingInner.right)
	local left = math.max(0, wingInner.left - (nameX - half))
	frame:GetChild("WingRight"):stoptweening():decelerate(0.15):x(right)
	frame:GetChild("WingLeft"):stoptweening():decelerate(0.15):x(-left)
end

-- When a new name is ready it slams in from the side the cursor moved
-- towards, and the old one flicks out the other way.  The old slot is reset
-- once its fade ends, because a slot only renders while fully opaque and
-- still.
local function SwapNames(incoming, outgoing)
	local dir = names.direction
	incoming:finishtweening():playcommand("CutoutHold", {held = false})
	incoming:xy(nameX + dir * slide, nameY):zoom(1.3):rotationz(L.name.rot - dir * 6)
		:decelerate(0.18):xy(nameX, nameY):zoom(1):rotationz(L.name.rot)
	outgoing:finishtweening():linear(0.12)
		:xy(nameX - dir * slide, nameY):zoom(0.8):diffusealpha(0)
		:queuecommand("Retire")
end

local function nameSlot(index)
	return VOLT26.Cutout.CreateSlot{
		x = L.name.x * sx, y = L.name.y * sy,
		maxW = nameMaxW, maxH = nameMaxH, halign = 0.5, valign = 0.5,
		maxChars = nameMaxChars, held = true,
		opts = nameOpts,
		onInit = function(slot)
			names.slots[index] = slot
			slot:rotationz(L.name.rot)
		end,
		onReady = function(slot)
			-- Only the slot being prepared, and only for the name still wanted.
			if slot ~= names.slots[3 - names.active] or names.pending ~= names.wanted then return end
			local outgoing = names.slots[names.active]
			names.active = 3 - names.active
			names.shown = names.wanted
			SwapNames(slot, outgoing)
			PlaceWings(slot:GetParent(), names.shown)
		end,
	}..{
		RetireCommand=function(self)
			self:playcommand("CutoutHold", {held = true})
			self:xy(nameX, nameY):zoom(1):rotationz(L.name.rot):diffusealpha(1)
		end,
	}
end

local function SetName(text)
	text = text or ""
	if text == names.wanted then return end
	names.wanted = text
	if text == names.shown then
		-- Back to the name already on screen: drop whatever was rendering.
		names.pending = nil
		return
	end
	names.pending = text
	names.slots[3 - names.active]:playcommand("CutoutSet", {text = text})
end

-- ----------------------------------------------------------------------------

local function wing(points)
	return Def.ActorMultiVertex{
		InitCommand=function(self)
			local black = {0, 0, 0, 1}
			self:SetDrawState{Mode="DrawMode_Triangles"}
			self:SetVertices{
				{{points[1] * sx, points[2] * sy, 0}, black},
				{{points[3] * sx, points[4] * sy, 0}, black},
				{{points[5] * sx, points[6] * sy, 0}, black},
			}
		end,
	}
end

-- The path last loaded into the avatar sprite, so a redraw on the same
-- profile does not reload the file.
local avatarPath = nil

-- shown: false (no portrait, as on an unjoined card), or the profile's own
-- avatar path, or nil for the stock avatar.
local function SetAvatar(frame, path, shown)
	local portrait = frame:GetChild("Card"):GetChild("Portrait")
	local custom, stock = portrait:GetChild("Avatar"), portrait:GetChild("Stock")
	if shown == false then
		custom:visible(false); stock:visible(false)
		return
	end
	stock:visible(path == nil)
	custom:visible(path ~= nil)
	if path then
		if avatarPath ~= path then
			avatarPath = path
			custom:Load(path)
		end
		custom:align(0, 0):xy(cx(customAvatar.x), cy(customAvatar.y))
		custom:scaletoclipped(customAvatar.w * sx, customAvatar.h * sy)
	end
end

local lastCursor = nil

local function Render(frame)
	local item = Selection.Get(player)
	local ready = Selection.IsReady(player)
	local cursor, count = Selection.Cursor(player), Selection.Count()

	-- Which way the name should travel: towards the side the cursor moved.
	names.direction = (lastCursor and cursor ~= lastCursor) and (cursor > lastCursor and 1 or -1) or 0
	lastCursor = cursor

	SetAvatar(frame, item and item.index and avatars[item.index] or nil)
	frame:GetChild("Card"):GetChild("Portrait"):finishtweening():zoom(1.04):decelerate(0.12):zoom(1)

	SetName(item and item.displayname or "")

	frame:GetChild("WingRight"):visible(not ready and cursor < count)
	frame:GetChild("WingLeft"):visible(not ready and cursor > 1)
	frame:GetChild("Press"):visible(false)
end

local currentState = "join"

-- ----------------------------------------------------------------------------
-- The card.  The red field and its rings are drawn into a texture every frame
-- (the texture's edge is the card's edge, so the rings are clipped for free)
-- and shown upright inside the card frame, which carries the tilt.

local displayScale = math.max(1, DISPLAY:GetDisplayHeight() / SCREEN_HEIGHT)
local kx, ky = sx * displayScale, sy * displayScale   -- texture pixels per card pixel
local texW, texH = math.ceil(cardW * kx), math.ceil(cardH * ky)

-- One quad per ring segment, four vertices each, allocated once and moved in
-- place every frame.  The rings only cover the quarter of the circle that
-- faces into the card from its bottom-right corner.
local ringVertices = {}
for i = 1, waves.count * waves.segments * 4 do
	ringVertices[i] = {{0, 0, 0}, waves.ink}
end

local function MoveRings(amv, phase)
	local ox, oy = cardW * kx, cardH * ky
	local n = 0
	for ring = 0, waves.count - 1 do
		local radius = waves.first + (ring - 1 + phase) * waves.step
		local inner = math.max(0, radius - waves.width / 2)
		local outer = math.max(0, radius + waves.width / 2)
		for seg = 0, waves.segments - 1 do
			local a0 = math.pi + (seg / waves.segments) * math.pi / 2
			local a1 = math.pi + ((seg + 1) / waves.segments) * math.pi / 2
			local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
			local quad = {
				{outer * c0, outer * s0}, {outer * c1, outer * s1},
				{inner * c1, inner * s1}, {inner * c0, inner * s0},
			}
			for _, point in ipairs(quad) do
				n = n + 1
				local position = ringVertices[n][1]
				position[1] = ox + point[1] * kx
				position[2] = oy + point[2] * ky
			end
		end
	end
	amv:SetVertices(ringVertices)
end

local wavePhase = 0

local function image(name)
	return Def.Sprite{
		Texture=asset(name),
		InitCommand=function(self)
			self:align(0, 0):xy(cx(-imageMargin), cy(-imageMargin))
				:zoomto((cardW + imageMargin * 2) * sx, (cardH + imageMargin * 2) * sy)
		end,
	}
end

local card = Def.ActorFrame{
	Name="Card",
	InitCommand=function(self)
		self:xy(L.center.x * sx, L.center.y * sy):rotationz(L.rot)
		-- Only ActorFrames take an update function, so the card moves its rings.
		local rings = self:GetChild("WaveTexture"):GetChild("Rings")
		self:SetUpdateFunction(function(_, delta)
			wavePhase = (wavePhase + delta / waves.period) % 1
			MoveRings(rings, wavePhase)
		end)
	end,
	Def.ActorFrameTexture{
		Name="WaveTexture",
		InitCommand=function(self)
			self:setsize(texW, texH)
			self:SetTextureName("VOLT26ProfileWaves" .. pn)
			self:EnableAlphaBuffer(false)
			self:Create()
		end,
		Def.Quad{
			InitCommand=function(self)
				self:align(0, 0):zoomto(texW, texH):diffuse(waves.field)
			end,
		},
		Def.ActorMultiVertex{
			Name="Rings",
			InitCommand=function(self)
				self:SetDrawState{Mode="DrawMode_Quads"}
				MoveRings(self, 0)
			end,
		},
	},
	Def.Sprite{
		InitCommand=function(self)
			self:SetTexture(self:GetParent():GetChild("WaveTexture"):GetTexture())
			self:align(0, 0):xy(cx(0), cy(0)):zoom(1 / displayScale)
		end,
	},
	Def.ActorFrame{
		Name="Portrait",
		image("avatar_stock")..{ Name="Stock", InitCommand=function(self)
			self:align(0, 0):xy(cx(-imageMargin), cy(-imageMargin))
				:zoomto((cardW + imageMargin * 2) * sx, (cardH + imageMargin * 2) * sy)
				:visible(false)
		end },
		Def.Sprite{ Name="Avatar", InitCommand=function(self) self:visible(false) end },
	},
	image("card_frame_" .. pn:lower()),
}

return Def.ActorFrame{
	Name = pn .. "Frame",

	OnCommand=function(self)
		self:addy(30):diffusealpha(0):decelerate(0.25):addy(-30):diffusealpha(1)
		self:playcommand("Redraw")
	end,
	OffCommand=function(self) self:linear(0.15):diffusealpha(0) end,

	RedrawCommand=function(self)
		if currentState == "browse" then Render(self) end
	end,

	VOLT26ProfileCursorMessageCommand=function(self, params)
		if params and params.PlayerNumber ~= player then return end
		self:playcommand("Redraw")
	end,
	VOLT26ProfileReadyMessageCommand=function(self, params)
		if params and params.PlayerNumber ~= player then return end
		self:playcommand("Redraw")
		if Selection.IsReady(player) then
			self:GetChild("Card"):finishtweening():zoom(1.03):decelerate(0.15):zoom(1)
		end
	end,

	InvalidChoiceMessageCommand=function(self, params)
		if params and params.PlayerNumber ~= player then return end
		self:finishtweening():bounceend(0.1):addx(4):bounceend(0.1):addx(-8):bounceend(0.1):addx(4)
	end,
	PreventEscapeMessageCommand=function(self)
		self:finishtweening():bounceend(0.1):addx(4):bounceend(0.1):addx(-8):bounceend(0.1):addx(4)
	end,

	-- Which of the three states this side is in.  Called by default.lua
	-- whenever the engine reports a join, an unjoin or a memory card.
	SetStateCommand=function(self, params)
		local state = params and params.State or "join"
		currentState = state
		names.direction = 0

		local press = self:GetChild("Press")
		self:GetChild("WingRight"):visible(false)
		self:GetChild("WingLeft"):visible(false)

		if state == "join" then
			SetAvatar(self, nil, false)
			if IsArcade() and not GAMESTATE:EnoughCreditsToJoin() then
				press:visible(false)
				SetName(THEME:GetString("ScreenSelectProfile", "EnterCreditsToJoin"))
			else
				press:visible(true)
				SetName("")
			end
		elseif state == "card" then
			press:visible(false)
			SetAvatar(self, nil)
			SetName(MEMCARDMAN:GetName(player))
		else
			Render(self)
		end
	end,

	card,
	Def.Sprite{
		Name="Press",
		Texture=asset("press_start"),
		InitCommand=function(self)
			self:xy(L.press.x * sx, L.press.y * sy):zoomto(pressSize.w * sx, pressSize.h * sy)
				:visible(false)
		end,
		OnCommand=function(self) self:pulse():effectmagnitude(1, 1.05, 1):effectperiod(1.2) end,
	},
	wing(L.wings[1])..{ Name="WingRight" },
	wing(L.wings[2])..{ Name="WingLeft" },
	nameSlot(1),
	nameSlot(2),
	-- Measures names drawn in the cutout slots' fallback font (see NameWidth).
	LoadFont("Common Normal")..{
		Name="NameMeasure",
		InitCommand=function(self) self:visible(false) end,
	},
}
