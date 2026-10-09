-- One player's "WANTED" card on ScreenSelectProfile.
--
-- The card, its concentric stripes, the PRESS START lettering and the arrow
-- wings come from the Illustrator layout (Graphics/VOLT26/ProfileSelect, a
-- 1920x1080 artboard); every position below is in artboard pixels.  On the card
-- sits the focused profile's avatar -- the profile's own picture when it has one
-- (VOLT26.Profile.GetAvatarPath), the stock avatar otherwise -- and beneath it
-- the profile's name in cutout lettering (VOLT26.Cutout).
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
local stockAvatar = asset("avatar_stock")

-- Artboard geometry.  The P1 card is the left one in the design; P2's avatar,
-- PRESS START and name positions are the P1 ones carried through each card's
-- own transform.
local layout = {
	P1 = {
		card   = {x = 257, y = 389, w = 369, h = 461},
		avatar = {x = 291.28, y = 533.49, w = 271.95, h = 266.4, rot = -8.46},
		press  = {x = 449.34, y = 629.24},
		name   = {x = 440.99, y = 821.34, rot = 0.67},
		-- right wing, left wing (triangle vertices)
		wings  = {
			{684.72, 790.24, 678.77, 826.57, 728.31, 808.4},
			{271.66, 867.84, 264.85, 831.66, 224.48, 865.64},
		},
	},
	P2 = {
		card   = {x = 1323, y = 262, w = 336, h = 438},
		avatar = {x = 1361.77, y = 365.62, w = 271.95, h = 266.4, rot = 3.64},
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

-- ----------------------------------------------------------------------------
-- The name: two cutout slots used alternately, so the name on screen stays
-- until its successor has finished rendering (about half a second).

local names = { slots = {}, active = 1, shown = nil, wanted = nil, pending = nil }

local function nameSlot(index)
	return VOLT26.Cutout.CreateSlot{
		x = L.name.x * sx, y = L.name.y * sy,
		maxW = 430 * sx, maxH = 120 * sy, halign = 0.5, valign = 0.5,
		maxChars = 20, held = true,
		opts = { base = 66 * sy, tiltDeg = -2 },
		onInit = function(slot)
			names.slots[index] = slot
			slot:rotationz(L.name.rot)
		end,
		onReady = function(slot)
			-- Only the slot being prepared, and only for the name still wanted.
			if slot ~= names.slots[3 - names.active] or names.pending ~= names.wanted then return end
			slot:playcommand("CutoutHold", {held = false})
			names.slots[names.active]:playcommand("CutoutHold", {held = true})
			names.active = 3 - names.active
			names.shown = names.wanted
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

local function SetAvatar(avatar, path)
	path = path or stockAvatar
	if avatar.path ~= path then
		avatar.path = path
		avatar:Load(path)
	end
	avatar:align(0, 0):xy(L.avatar.x * sx, L.avatar.y * sy):rotationz(L.avatar.rot)
	avatar:scaletoclipped(L.avatar.w * sx, L.avatar.h * sy)
end

local function Render(frame)
	local item = Selection.Get(player)
	local ready = Selection.IsReady(player)
	local cursor, count = Selection.Cursor(player), Selection.Count()

	local avatar = frame:GetChild("Avatar")
	avatar:visible(true)
	SetAvatar(avatar, item and item.index and avatars[item.index] or nil)
	avatar:finishtweening():zoom(1.04):decelerate(0.12):zoom(1)

	SetName(item and item.displayname or "")

	frame:GetChild("WingRight"):visible(not ready and cursor < count)
	frame:GetChild("WingLeft"):visible(not ready and cursor > 1)
	frame:GetChild("Press"):visible(false)
end

local currentState = "join"

local card = Def.ActorFrame{
	Name="Card",
	Def.Sprite{
		Texture=asset("card_" .. pn:lower()),
		InitCommand=function(self)
			self:align(0, 0):xy(L.card.x * sx, L.card.y * sy):zoomto(L.card.w * sx, L.card.h * sy)
		end,
	},
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

		local avatar = self:GetChild("Avatar")
		local press = self:GetChild("Press")
		self:GetChild("WingRight"):visible(false)
		self:GetChild("WingLeft"):visible(false)

		if state == "join" then
			avatar:visible(false)
			if IsArcade() and not GAMESTATE:EnoughCreditsToJoin() then
				press:visible(false)
				SetName(THEME:GetString("ScreenSelectProfile", "EnterCreditsToJoin"))
			else
				press:visible(true)
				SetName("")
			end
		elseif state == "card" then
			press:visible(false)
			avatar:visible(true)
			SetAvatar(avatar, nil)
			SetName(MEMCARDMAN:GetName(player))
		else
			Render(self)
		end
	end,

	card,
	Def.Sprite{
		Name="Avatar",
		InitCommand=function(self) self:visible(false) end,
	},
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
}
