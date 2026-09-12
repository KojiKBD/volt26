-- One player's half of ScreenSelectProfile: a strip of profile cards and the
-- panel that describes whichever card the cursor is on.
--
-- Two layouts, because the screen has two jobs.  With one player there is room
-- for a row of portrait cards across the screen and a full-height panel beside
-- them, which is the screen at its best.  With two players the screen splits
-- down the middle and each side gets a narrow column of rows and a compact
-- panel -- the same components, rebuilt at a size that fits a half.
--
-- Nothing here decides anything.  The cursor lives in Selection.lua, input
-- lives in Input.lua, and this file redraws whenever either of them says the
-- state changed.

local args = ...
local player = args.Player
local Selection = args.Selection
local avatars = args.Avatars
local Chrome = args.Chrome
local split = args.Layout == "split"

local accent = Chrome.Accent(player)
local pn = ToEnumShortString(player)

-- ----------------------------------------------------------------------------
-- Geometry

local L = split and {
	origin  = (player == PLAYER_1) and Chrome.Metrics.Margin or (_screen.cx + 7),
	region  = { w = 400, h = 194 },
	card    = { w = 170, h = 44, gap = 6, visible = 4, vertical = true },
	panel   = { dx = 180, w = 220, h = 194 },
	tile    = { w = 95, h = 38, x = 12, y = 56, gapx = 6, gapy = 6 },
	name    = { px = 18, x = 11, y = 22 },
	mods    = { x = 12, y = 142, wrap = 196, px = 10 },
	pad     = 12,
} or {
	origin  = Chrome.Metrics.Margin,
	region  = { w = _screen.w - Chrome.Metrics.Margin*2, h = 234 },
	card    = { w = 118, h = 150, gap = 10, visible = 4, vertical = false },
	panel   = { dx = 520, w = 294, h = 234 },
	tile    = { w = 127, h = 40, x = 16, y = 66, gapx = 8, gapy = 8 },
	name    = { px = 24, x = 15, y = 26 },
	mods    = { x = 16, y = 166, wrap = 262, px = 11 },
	pad     = 16,
}

local top = Chrome.Metrics.BodyY

local function CardPosition(slot)
	local step = (L.card.vertical and L.card.h or L.card.w) + L.card.gap
	if L.card.vertical then
		return L.origin, top + step * (slot-1)
	end
	return L.origin + step * (slot-1), top
end

-- ----------------------------------------------------------------------------
-- Rendering
--
-- Every redraw reads the whole visible state rather than tracking deltas: the
-- strip is four cards, and four cards are cheap to reassign.

local function SetCard(card, item, focused)
	if not card then return end

	if not item then
		card:visible(false)
		return
	end
	card:visible(true)

	Chrome.SetBoxFocus(card, focused, accent)

	local name = card:GetChild("Name")
	VOLT26.Type.SetDisplay(name, (item.displayname or ""):upper(),
		split and 13 or 14, L.card.w - (split and 52 or 20))
	name:stoptweening():linear(0.08):diffuse(focused and Chrome.Color.Text or Chrome.Color.Dim)

	local caption = card:GetChild("Caption")
	local text = item.guest
		and THEME:GetString("ScreenSelectProfile", "NoSaveData")
		or (item.totalsongs or "")
	VOLT26.Type.SetLabel(caption, text:upper(), 9, L.card.w - (split and 52 or 20))

	-- A profile's avatar if it has one; the fallback plate keeps the card's
	-- silhouette identical either way.
	local avatar = card:GetChild("Avatar")
	local path = item.index and avatars[item.index] or nil
	if path then
		avatar:visible(true):Load(path)
		local size = split and 30 or 102
		avatar:scaletoclipped(size, size)
	else
		avatar:visible(false)
	end
	card:GetChild("AvatarPlate"):visible(path == nil)
end

local function Placeholder(value)
	if value == nil or value == "" then return VOLT26.ProfileSummary.Unknown end
	return value
end

local function SetPanel(body, item)
	local panel = body:GetChild("Panel")
	if not panel then return end

	local name = panel:GetChild("ProfileName")
	VOLT26.Type.SetDisplay(name, (item and item.displayname or ""):upper(), L.name.px, L.panel.w - L.pad*2)

	-- Songs played is a count the engine already holds.  Everything else comes
	-- from the profile's score index, which is read the first time a cursor
	-- lands on that profile and cached from then on.  A guest has neither.
	local songs, grade, combo, seen = nil, nil, nil, nil

	if item and not item.guest then
		songs = item.songs
		local summary = VOLT26.ProfileSummary.Read(item.dir)
		if summary and summary.Available then
			grade = VOLT26.ProfileSummary.GradeText(summary.BestGrade)
			combo = VOLT26.ProfileSummary.ComboText(summary.MaxCombo)
			seen  = VOLT26.ProfileSummary.LastPlayedText(summary.LastPlayed)
		end
	end

	local tiles = {
		{ Placeholder(songs), THEME:GetString("ScreenSelectProfile", "CaptionSongsPlayed") },
		{ Placeholder(grade), THEME:GetString("ScreenSelectProfile", "CaptionBestGrade") },
		{ Placeholder(combo), THEME:GetString("ScreenSelectProfile", "CaptionTopCombo") },
		{ Placeholder(seen),  THEME:GetString("ScreenSelectProfile", "CaptionLastSeen") },
	}
	for i, tile in ipairs(tiles) do
		Chrome.SetTile(panel:GetChild("Tile"..i), tile[1], tile[2], L.tile.w - 18)
	end

	-- The modifiers a profile will bring into gameplay, as the profile itself
	-- recorded them.
	local mods = panel:GetChild("Mods")
	local text = (item and item.mods and item.mods ~= "") and item.mods
		or THEME:GetString("ScreenSelectProfile", "NoModifiers")
	VOLT26.Type.SetDisplay(mods, text, L.mods.px)
	mods:_wrapwidthpixels(L.mods.wrap / mods:GetZoom())

	panel:GetChild("Ready"):visible( Selection.IsReady(player) )
end

local function Render(frame)
	local body = frame:GetChild("Body")
	local strip = body:GetChild("Strip")

	local start = Selection.Window(player, L.card.visible)
	local position = Selection.Cursor(player)
	local ready = Selection.IsReady(player)

	for slot = 1, L.card.visible do
		local i = start + slot - 1
		SetCard(strip:GetChild("Card"..slot), Selection.Item(i), i == position and not ready)
	end

	-- A committed side steps back visually so the other side's cursor reads as
	-- the live one.
	strip:stoptweening():linear(0.1):diffusealpha(ready and 0.35 or 1)
	strip:GetChild("MoreBefore"):visible( Selection.HasMore(player, L.card.visible, -1) )
	strip:GetChild("MoreAfter"):visible( Selection.HasMore(player, L.card.visible, 1) )

	SetPanel(body, Selection.Get(player))
end

-- ----------------------------------------------------------------------------
-- Actors

local strip = Def.ActorFrame{ Name="Strip" }

for slot = 1, L.card.visible do
	local x, y = CardPosition(slot)
	local card = Chrome.Box{ name="Card"..slot, x=x, y=y, w=L.card.w, h=L.card.h }

	local avatarSize = split and 30 or 102
	local avatarX = split and 7 or 8
	local avatarY = split and 7 or 8

	card[#card+1] = Def.Quad{
		Name="AvatarPlate",
		InitCommand=function(self)
			self:align(0,0):xy(avatarX, avatarY):zoomto(avatarSize, avatarSize)
				:diffuse(Chrome.Color.LineFaint)
		end,
	}
	card[#card+1] = Def.Sprite{
		Name="Avatar",
		InitCommand=function(self) self:align(0,0):xy(avatarX, avatarY):visible(false) end,
	}
	card[#card+1] = Chrome.Display{
		name="Name", text="", px=split and 13 or 14,
		x = split and 44 or 10,
		y = split and 10 or 116,
	}
	card[#card+1] = Chrome.Label{
		name="Caption", text="", px=9,
		x = split and 45 or 11,
		y = split and 26 or 134,
		color = Chrome.Color.Faint,
	}

	strip[#strip+1] = card
end

-- Marks that the list continues past the edge of the window.
local function More(name, x, y)
	return Def.Quad{
		Name=name,
		InitCommand=function(self)
			self:align(0.5,0.5):xy(x, y):zoomto(5,5):rotationz(45)
				:diffuse(Chrome.Color.Faint):visible(false)
		end,
	}
end

if L.card.vertical then
	strip[#strip+1] = More("MoreBefore", L.origin + L.card.w/2, top - 7)
	strip[#strip+1] = More("MoreAfter",  L.origin + L.card.w/2,
		top + (L.card.h + L.card.gap) * L.card.visible - L.card.gap + 7)
else
	strip[#strip+1] = More("MoreBefore", L.origin - 9, top + L.card.h/2)
	strip[#strip+1] = More("MoreAfter",
		L.origin + (L.card.w + L.card.gap) * L.card.visible - L.card.gap + 9, top + L.card.h/2)
end

-- ----------------------------------------------------------------------------

local panel = Chrome.Box{
	name="Panel", x=L.origin + L.panel.dx, y=top, w=L.panel.w, h=L.panel.h,
}

panel[#panel+1] = Chrome.Label{
	text=THEME:GetString("ScreenSelectProfile", "CaptionSelected"), px=9,
	x=L.pad, y=split and 9 or 13, color=Chrome.Color.Dim,
}
panel[#panel+1] = Chrome.Display{
	name="ProfileName", text="", px=L.name.px, x=L.name.x, y=L.name.y,
}
panel[#panel+1] = Chrome.Label{
	name="Ready", text=THEME:GetString("ScreenSelectProfile", "Ready"), px=9,
	x=L.panel.w - L.pad, y=split and 9 or 13, halign=1, color=accent,
}

for i = 1, 4 do
	local column = (i-1) % 2
	local row = math.floor((i-1) / 2)
	panel[#panel+1] = Chrome.Tile{
		name="Tile"..i,
		x = L.tile.x + (L.tile.w + L.tile.gapx) * column,
		y = L.tile.y + (L.tile.h + L.tile.gapy) * row,
		w = L.tile.w, h = L.tile.h,
	}
end

panel[#panel+1] = Chrome.Label{
	text=THEME:GetString("ScreenSelectProfile", "CaptionActiveModifiers"), px=9,
	x=L.mods.x, y=L.mods.y, color=Chrome.Color.Dim,
}
panel[#panel+1] = Chrome.Display{
	name="Mods", text="", px=L.mods.px,
	x=L.mods.x, y=L.mods.y + 14, wrap=L.mods.wrap, vertspacing=1,
	color=Chrome.Color.Dim,
}

-- ----------------------------------------------------------------------------
-- The frame itself: a strip, a panel, and the two states that replace them --
-- a side that has not joined, and a side playing off a memory card.

local body = Def.ActorFrame{ Name="Body", strip, panel }

local join = Chrome.Box{
	name="JoinFrame", x=L.origin, y=top, w=L.region.w, h=L.region.h,
}
join[#join+1] = Chrome.Display{
	name="JoinText", text="", px=16,
	x = L.region.w/2, y = L.region.h/2 - 8,
	halign=0.5, color=Chrome.Color.Dim,
}

local card = Def.ActorFrame{
	Name="CardFrame",
	Chrome.Box{ x=L.origin, y=top, w=L.panel.w, h=L.panel.h },
	Chrome.Label{
		text=THEME:GetString("ScreenSelectProfile", "Card"), px=9,
		x=L.origin + L.pad, y=top + (split and 9 or 13), color=accent,
	},
	Chrome.Display{
		name="CardName", text="", px=L.name.px,
		x=L.origin + L.name.x, y=top + L.name.y,
	},
}

return Def.ActorFrame{
	Name = pn .. "Frame",

	InitCommand=function(self)
		self:GetChild("CardFrame"):visible(false)
	end,
	OnCommand=function(self)
		self:playcommand("Redraw")
		self:diffusealpha(0):linear(0.15):diffusealpha(1)
	end,
	OffCommand=function(self) self:linear(0.15):diffusealpha(0) end,

	RedrawCommand=function(self)
		if self:GetChild("Body"):GetVisible() then Render(self) end
	end,

	-- A player's own moves redraw their side; the other side is left alone.
	VOLT26ProfileCursorMessageCommand=function(self, params)
		if params and params.PlayerNumber ~= player then return end
		self:playcommand("Redraw")
	end,
	VOLT26ProfileReadyMessageCommand=function(self, params)
		if params and params.PlayerNumber ~= player then return end
		self:playcommand("Redraw")
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

		self:GetChild("Body"):visible(state == "browse")
		self:GetChild("JoinFrame"):visible(state == "join")
		self:GetChild("CardFrame"):visible(state == "card")

		if state == "join" then
			local text = (IsArcade() and not GAMESTATE:EnoughCreditsToJoin())
				and THEME:GetString("ScreenSelectProfile", "EnterCreditsToJoin")
				or THEME:GetString("ScreenSelectProfile", "PressStartToJoin")
			VOLT26.Type.SetDisplay(self:GetChild("JoinFrame"):GetChild("JoinText"), text, 16)
		elseif state == "card" then
			VOLT26.Type.SetDisplay(self:GetChild("CardFrame"):GetChild("CardName"),
				MEMCARDMAN:GetName(player):upper(), L.name.px, L.panel.w - L.pad*2)
		else
			Render(self)
		end
	end,

	body,
	join,
	card,
}
