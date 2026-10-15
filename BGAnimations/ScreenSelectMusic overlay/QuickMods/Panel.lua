local args = ...
local L = args.L
local player = args.Player
local state = args.State
local rows = args.Rows
local pn = ToEnumShortString(player)

-- The player's colour as the rest of the Persona dress uses it: the theme's red
-- for P1 and the song select's blue for P2.
local accent = player == PLAYER_1 and L.Red or color("#00b1ff")

-- One player's Quick Mods panel: their note field at the size gameplay draws
-- it, and a narrow list of settings in the corner of their own half.
--
-- The list wears the sort menu's Persona dress, so the panel reads as one more
-- layer of that menu: a black slab edged in white over a slab in the player's
-- colour, slanted like the dock; the title slapped on top as a white tag; the
-- setting in hand on a white bar with black words over a shadow in the
-- player's colour, the way the strip marks its cursor.
--
-- The list is a layer over the field rather than a shelf under it, so the field
-- keeps the whole height gameplay gives it.  A list that sits over the arrows
-- has to get out of the way, and it does that by going almost transparent a few
-- seconds after the last press and coming straight back on the next one: still
-- there to be read, no longer something to look past.

-- Gameplay's own figures, undone from engine units back into design units so
-- the preview is the same size as the real thing whatever resolution the engine
-- is running at.  The receptors sit where ScreenGameplay puts them.
local gameplayLane = 64 / L.Scale
local function metricOr(group, name, fallback)
	local ok, value = pcall(function() return THEME:GetMetricF(group, name) end)
	return (ok and tonumber(value)) or fallback
end
local receptorY = metricOr("Player", "ReceptorArrowsYStandard", -125) / L.Scale
local reverseY = metricOr("Player", "ReceptorArrowsYReverse", 145) / L.Scale
local holdJudgmentY = metricOr("Player", "HoldJudgmentYStandard", -90) / L.Scale
local holdJudgmentReverseY = metricOr("Player", "HoldJudgmentYReverse", 90) / L.Scale

-- The judgment and the combo trade places in reverse, as GetGameplayLayout
-- puts them.
local judgmentY, comboY = 0, 92

-- Where the perspective's vanishing point sits, in screen units, which is
-- where ScreenGameplay puts it: the middle of the two receptor rows.
local vanishY = _screen.cy
	+ (metricOr("Player", "ReceptorArrowsYStandard", -125)
	 + metricOr("Player", "ReceptorArrowsYReverse", 145)) / 2

-- The two halves of the screen, as ScreenGameplay places them.
local centreX = (player == PLAYER_1) and -480 or 480
local columnCount = #args.SourcesModule.Columns()
local fieldW = gameplayLane * columnCount
local fieldBottom = L.HalfH

-- The list.  One entry per setting plus the one that closes the panel, which is
-- the last thing Start reaches, set a little apart from the settings.
local entries = #rows + 1
local boxW = 460
local rowH = 38
local headH = 64
local padX = 26
local padY = 8
local exitGap = 12
local boxH = headH + padY*2 + entries*rowH + exitGap

-- The slab leans like the dock, so its bottom corner reaches further out than
-- its top one; the margins keep both, and the shadow, on the screen.
local overhang = math.abs(L.Slant) * boxH/2
local boxY = L.HalfH - 40 - boxH
local boxX = (player == PLAYER_1) and (-L.HalfW + 40 + overhang)
	or (L.HalfW - 40 - overhang - L.SlabShadow[1] - boxW)
local boxCX, boxCY = boxX + boxW/2, boxY + boxH/2

-- How far a line at height y moves sideways to follow the slant (see
-- L.SlantTo: a slanted quad's edge moves L.Slant per unit of y).
local function lean(y) return L.Slant * (y - boxCY) end

local labelPx, valuePx, subPx = 17, 22, 10
local labelW = 200
local valueW = 160
local subGap = 10
local arrowGap = 16
local valueRight = boxW - padX - 24
local arrowRight = boxW - padX - 6

-- How long the list waits before it fades, and how far.
local idleSeconds = 3
local idleAlpha = 0.16

local function rowMid(index)
	return boxY + headH + padY + (index-1)*rowH + rowH/2 + (index == entries and exitGap or 0)
end

-- The left edge of a row's content, slanted with the slab.
local function rowLeft(index)
	return boxX + lean(rowMid(index))
end

local function definitionOf(index)
	local row = rows[index]
	return row and row.Definition or nil
end

local function exitChoiceText()
	local key = state[pn].ExitChoice == "Top" and "QuickModsExitTop" or "QuickModsExitClose"
	return THEME:GetString("ScreenSelectMusic", key)
end

-- The chart the player has actually chosen, which is what the demonstration
-- chart's density follows.
local function difficultyText()
	local chart = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)
		or GAMESTATE:GetCurrentSteps(player)
	if not chart then return THEME:GetString("ScreenSelectMusic", "QuickModsDemo") end
	return ("%s %s"):format(ToEnumShortString(chart:GetDifficulty()), chart:GetMeter())
end

local function judgmentPath()
	local file = VOLT26.Options.GetPlayerModifiers(player).JudgmentGraphic
	if type(file) ~= "string" or file == "" or file == "None" then return nil end
	return THEME:GetPathG("", "_judgments/" .. file)
end

local function holdJudgmentPath()
	local file = VOLT26.Options.GetPlayerModifiers(player).HoldJudgment
	if type(file) ~= "string" or file == "" or file == "None" then return nil end
	return THEME:GetPathG("", "_HoldJudgments/" .. file)
end

-- The combo sample is a proxy rather than a BitmapText of its own: a
-- BitmapText's face is fixed when it is built, so the sample points at
-- whichever of the pre-built fonts the player has chosen.
local function comboSource()
	local name = VOLT26.Options.GetPlayerModifiers(player).ComboFont
	if type(name) ~= "string" or name == "" or name == "None" then return nil end
	local frame = args.Sources.Frame
	return frame and frame:GetChild(args.SourcesModule.ComboKey(name)) or nil
end

-- Loading by path rather than at build time: these two are ordinary images, so
-- the sample can follow the player's choice without the tree being rebuilt.
local function loadIfChanged(actor, path)
	if not path then
		actor:visible(false)
		return
	end
	if actor.quickModsPath ~= path then
		local ok = pcall(function()
			actor:Load(path)
			actor:animate(false):setstate(0)
		end)
		actor.quickModsPath = ok and path or nil
	end
	actor:visible(actor.quickModsPath ~= nil)
end

local af = Def.ActorFrame{
	Name = pn.."QuickModsPanel",
	RefreshCommand = function(self)
		self:visible(GAMESTATE:IsHumanPlayer(player))
		if not GAMESTATE:IsHumanPlayer(player) then return end

		-- A player on their own has the whole screen, so their field slides to
		-- the middle of it.  The list stays in its corner, which is where it is
		-- out of the way in both cases.
		local solo = #GAMESTATE:GetHumanPlayers() <= 1
		local reversed = VOLT26.Options.IsReverse(player)
		self:GetChild("Field"):x(solo and -centreX or 0)
		self:playcommand("Perspective", {Solo = solo, Reverse = reversed})

		local list = self:GetChild("Box"):GetChild("Slide")
		self:playcommand("Title")
		L.SetTag(list:GetChild("Difficulty"), difficultyText(), 15, 150)

		local index = state[pn].Index
		for i = 1, entries do
			local definition = definitionOf(i)
			local focused = (i == index)
			local available = definition == nil
				or definition.Available == nil or definition.Available(player) ~= false
			local x0 = rowLeft(i)

			-- On the white bar the words are black; elsewhere white, grey when
			-- the style cannot offer the setting, and the way out in the
			-- player's colour so it reads apart from the settings.
			local ink
			if focused then
				ink = L.Black
			elseif not available then
				ink = L.Fade(L.Mute, 0.6)
			else
				ink = L.White
			end

			local label = list:GetChild("RowLabel"..i)
			L.SetTag(label, definition and definition.Label()
				or THEME:GetString("ScreenSelectMusic", "QuickModsExit"), labelPx, labelW)
			label:diffuse((definition == nil and not focused) and accent or ink)

			local sub = list:GetChild("RowSub"..i)
			local subText = definition and definition.Sub and definition.Sub(player) or ""
			sub:visible(subText ~= "")
			if subText ~= "" then
				L.SetLabel(sub, subText, subPx, 110)
				sub:x(x0 + padX + label:GetZoomedWidth() + subGap)
					:diffuse(focused and accent or L.Mute)
			end

			local value = list:GetChild("RowValue"..i)
			local text = definition and (available and definition.Value(player) or L.Dash)
				or exitChoiceText()
			L.SetTag(value, text, valuePx, valueW)
			value:diffuse(ink)

			-- The arrows are drawn only on the row in hand: on a list this
			-- narrow, ten pairs of them would be the loudest thing in it.
			list:GetChild("RowLeft"..i):visible(focused and available)
				:x(x0 + valueRight - value:GetZoomedWidth() - arrowGap)
			list:GetChild("RowRight"..i):visible(focused and available)
		end

		-- The bar travels to the row in hand and lands a little large, as the
		-- dock's card is slapped down; on opening it is simply there.
		local cursor = list:GetChild("Cursor")
		local x, y = rowLeft(index) + boxW/2 + 8, rowMid(index)
		if cursor.quickModsIndex ~= index then
			cursor:stoptweening()
			if cursor.quickModsIndex == nil then
				cursor:xy(x, y):zoom(1)
			else
				cursor:zoom(1.08):decelerate(0.09):xy(x, y):zoom(1)
			end
			cursor.quickModsIndex = index
		end

		local field = self:GetChild("Field")
		field:GetChild("HoldJudgment"):y(reversed and holdJudgmentReverseY or holdJudgmentY)
		field:GetChild("Judgment"):y(reversed and comboY or judgmentY)
		field:GetChild("Combo"):y(reversed and judgmentY or comboY)

		loadIfChanged(field:GetChild("Judgment"), judgmentPath())
		loadIfChanged(field:GetChild("HoldJudgment"), holdJudgmentPath())

		local combo = field:GetChild("Combo")
		local source = comboSource()
		combo:visible(source ~= nil)
		if source and combo.quickModsSource ~= source then
			combo:SetTarget(source)
			combo.quickModsSource = source
		end
	end,
	-- The perspective is not a likeness this time: the engine tilts the whole
	-- note field about the player's own centre inside a menu perspective, and
	-- an ActorFrame can be given the same field of view, the same vanishing
	-- point and the same rotation.  The figures are ScreenGameplay's own,
	-- including reverse turning the tilt and its offset the other way.
	PerspectiveCommand = function(self, p)
		local frame = self:GetChild("Field"):GetChild("Perspective")
		local tilted = frame:GetChild("Tilt")
		local _, tilt, skew = VOLT26.Options.GetPerspective(player)

		if tilt == 0 and skew == 0 then
			frame:fov(-1)
			tilted:rotationx(0):zoom(1):y(0)
			return
		end

		local fieldX = p.Solo and 0 or centreX
		frame:fov(45):vanishpoint(
			scale(skew, 0.1, 1.0, _screen.cx + fieldX*L.Scale, _screen.cx), vanishY)

		-- Mini is already in the lane width, so only the tilt's own share of
		-- the zoom is taken here.
		local sign = p.Reverse and -1 or 1
		local zoom = tilt > 0 and scale(tilt, 0, 1, 1, 0.9) or scale(tilt, 0, -1, 1, 0.9)
		local offset = tilt > 0 and scale(tilt, 0, 1, 0, -45) or scale(tilt, 0, -1, 0, -20)
		tilted:rotationx(scale(tilt, -1, 1, 30, -30) * sign):zoom(zoom)
			:y(offset * sign / L.Scale)
	end,
	VOLT26QuickModsChangedMessageCommand = function(self) self:playcommand("Refresh") end,
	-- Laid out when the menu opens, not on Song Select's first frame.  The bar
	-- forgets its row so it appears on the first one instead of travelling.
	ShowQuickModsCommand = function(self)
		local cursor = self:GetChild("Box"):GetChild("Slide"):GetChild("Cursor")
		if cursor then cursor.quickModsIndex = nil end
		self:playcommand("Refresh")
	end,
}

-- ------------------------------------------------------------- the field

local field = Def.ActorFrame{Name = "Field"}

-- The band the arrows stand on: enough ground to read them against, and no
-- more, so the song select still shows on either side of it.  Black with white
-- edges, the player's colour just outside them.
local bandH = fieldBottom + L.HalfH
field[#field+1] = Def.Quad{
	InitCommand = function(self)
		self:align(0.5,0):xy(centreX, -L.HalfH)
			:zoomto(fieldW + 24, bandH)
			:diffuse(L.Black):diffusealpha(0.6)
	end,
}
for _, side in ipairs({-1, 1}) do
	local inner = centreX + side*(fieldW/2 + 12)
	field[#field+1] = L.Rule{
		X = inner, Y = -L.HalfH, Width = 3, Height = bandH, AlignX = 0.5,
		Tint = L.White, Alpha = 0.9,
	}
	field[#field+1] = L.Rule{
		X = inner + side*6, Y = -L.HalfH, Width = 4, Height = bandH, AlignX = 0.5,
		Tint = accent, Alpha = 0.9,
	}
end

-- The note field lives two frames deep: the outer one carries the perspective,
-- the inner one is what the tilt rotates, and it stands on the player's own
-- centre because that is the point the engine rotates about.
local tilted = Def.ActorFrame{
	Name = "Tilt",
	InitCommand = function(self) self:x(centreX) end,
}
tilted[#tilted+1] = LoadActor(
	THEME:GetPathB("ScreenSelectMusic", "overlay/QuickMods/NoteField.lua"),
	{
		L = L, Player = player, Sources = args.Sources, SourcesModule = args.SourcesModule,
		ReceptorY = receptorY, ReverseY = reverseY,
		BottomY = fieldBottom, TopY = -L.HalfH,
	}
)
field[#field+1] = Def.ActorFrame{
	Name = "Perspective",
	InitCommand = function(self) self:fov(-1) end,
	tilted,
}

-- The three samples sit over the field, where gameplay puts them.
field[#field+1] = Def.Sprite{
	Name = "HoldJudgment",
	InitCommand = function(self)
		self:xy(centreX, holdJudgmentY):visible(false):zoom(0.8/L.Scale)
	end,
}
field[#field+1] = Def.Sprite{
	Name = "Judgment",
	InitCommand = function(self)
		self:xy(centreX, judgmentY):visible(false):zoom(1/L.Scale)
	end,
}
field[#field+1] = Def.ActorProxy{
	Name = "Combo",
	InitCommand = function(self)
		self:xy(centreX, comboY):visible(false):zoom(0.75/L.Scale)
	end,
}
af[#af+1] = field

-- --------------------------------------------------------------- the list

-- A small arrow either side of the value in hand.  The label face has no
-- arrow glyphs, and the dress asks for shapes, as the sort menu's footer does.
local function arrow(name, pointing, x, y)
	local w, h = 7, 9
	local tip = pointing * w
	local tint = {1, 1, 1, 1}
	return Def.ActorMultiVertex{
		Name = name,
		InitCommand = function(self)
			self:SetDrawState({Mode = "DrawMode_Triangles"})
				:SetVertices({
					{{-tip, -h, 0}, tint}, {{-tip, h, 0}, tint}, {{tip, 0, 0}, tint},
				})
				:xy(x or 0, y):diffuse(accent):visible(false)
		end,
	}
end

local box = Def.ActorFrame{
	Name = "Box",
	-- Full strength while the player is working, almost gone once they stop.
	WakeCommand = function(self)
		self:stoptweening():diffusealpha(1)
			:sleep(idleSeconds):linear(0.6):diffusealpha(idleAlpha)
	end,
	VOLT26QuickModsChangedMessageCommand = function(self) self:playcommand("Wake") end,
	ShowQuickModsCommand = function(self) self:playcommand("Wake") end,
	OnCommand = function(self) self:playcommand("Wake") end,
}

-- Everything in the list rides one frame that slides in from the player's own
-- edge as the menu opens; the fade above stays separate so the two tweens
-- never cancel each other.
local slide = Def.ActorFrame{
	Name = "Slide",
	ShowQuickModsCommand = function(self)
		local from = (player == PLAYER_1) and -110 or 110
		self:stoptweening():x(from):decelerate(0.18):x(0)
	end,
}

local slab = L.Slab("Slab")
slab.InitCommand = function(self)
	self:xy(boxCX, boxCY)
	L.SizeSlab(self, boxW, boxH)
	self:GetChild("Shadow"):diffuse(accent)
end
slide[#slide+1] = slab

-- The header: a rule in the player's colour under the title tag, and the
-- chart the demonstration follows on the right.
local ruleY = boxY + headH - 6
slide[#slide+1] = Def.Quad{
	InitCommand = function(self)
		self:align(0, 0.5):xy(boxX + lean(ruleY) + padX, ruleY)
			:zoomto(boxW - padX*2, 3):diffuse(accent)
	end,
}
local difficultyY = boxY + headH - 26
slide[#slide+1] = L.TagText{
	Name = "Difficulty", Px = 15, Tint = L.White, Align = right,
	X = boxX + lean(difficultyY) + boxW - padX, Y = difficultyY,
}

-- The bar under the setting in hand: a shadow in the player's colour and a
-- white bar, both slanted, a little wider than the list so they reach past the
-- slab's right edge.
local cursorW, cursorH = boxW - padX + 22, rowH - 4
slide[#slide+1] = Def.ActorFrame{
	Name = "Cursor",
	Def.Quad{
		Name = "Shadow",
		InitCommand = function(self)
			L.SlantTo(self, cursorW, cursorH):xy(9, 6):diffuse(accent)
		end,
	},
	Def.Quad{
		Name = "Fill",
		InitCommand = function(self)
			L.SlantTo(self, cursorW, cursorH):diffuse(L.White)
		end,
	},
}

for i = 1, entries do
	-- (x0, not `left`: that name is the engine's alignment constant.)
	local y = rowMid(i)
	local x0 = rowLeft(i)
	slide[#slide+1] = L.TagText{Name = "RowLabel"..i, Px = labelPx, Tint = L.White, Align = left,
		X = x0 + padX, Y = y}
	slide[#slide+1] = L.LabelText{Name = "RowSub"..i, Px = subPx, Tint = L.Mute, Align = left,
		X = x0 + padX, Y = y + 1}
	slide[#slide+1] = L.TagText{Name = "RowValue"..i, Px = valuePx, Tint = L.White, Align = right,
		X = x0 + valueRight, Y = y}
	slide[#slide+1] = arrow("RowLeft"..i, -1, nil, y)
	slide[#slide+1] = arrow("RowRight"..i, 1, x0 + arrowRight, y)
end

-- The title, slapped across the slab's top edge: the player's number on black
-- and the menu's name on white, tilted, over a card in the player's colour.
-- It lands turned and large as the menu opens, the way the dock's card does.
local titleY = boxY + 6
local titleH = 44
local badgeW = 58
local titleTurn = -3
slide[#slide+1] = Def.ActorFrame{
	Name = "Title",
	InitCommand = function(self)
		self:xy(boxX + lean(titleY) + padX - 18, titleY):rotationz(titleTurn)
	end,
	ShowQuickModsCommand = function(self)
		self:stoptweening():zoom(1.3):rotationz(titleTurn - 12)
			:sleep(0.06):decelerate(0.14):zoom(1):rotationz(titleTurn)
	end,
	-- Sized from the words, which change with the language.
	TitleCommand = function(self)
		local name = self:GetChild("Name")
		L.SetTag(name, THEME:GetString("ScreenSelectMusic", "QuickMods"), 26, 300)
		local cardW = name:GetZoomedWidth() + 34
		L.SlantTo(self:GetChild("Card"), cardW, titleH):x(badgeW + cardW/2 - 4)
		L.SlantTo(self:GetChild("Shadow"), badgeW + cardW, titleH)
			:xy((badgeW + cardW)/2 + 10, 8)
	end,
	Def.Quad{
		Name = "Shadow",
		InitCommand = function(self) self:diffuse(accent) end,
	},
	Def.Quad{
		Name = "Card",
		InitCommand = function(self) self:diffuse(L.White) end,
	},
	Def.Quad{
		Name = "Badge",
		InitCommand = function(self)
			L.SlantTo(self, badgeW, titleH):x(badgeW/2):diffuse(L.Black)
		end,
	},
	L.TagText{Name = "Player", Text = pn, Px = 22, Tint = accent, Align = center, X = badgeW/2},
	L.TagText{Name = "Name", Px = 26, Tint = L.Black, Align = left, X = badgeW + 13},
}

box[#box+1] = slide
af[#af+1] = box

return af
