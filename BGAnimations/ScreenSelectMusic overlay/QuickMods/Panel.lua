local args = ...
local L = args.L
local player = args.Player
local state = args.State
local rows = args.Rows
local pn = ToEnumShortString(player)
local accent = player == PLAYER_1 and L.Accent or color("#2f7de0")

-- One player's Quick Mods panel: their note field at the size gameplay draws
-- it, and a narrow list of settings in the corner of their own half.
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
local holdJudgmentY = metricOr("Player", "HoldJudgmentYStandard", -90) / L.Scale

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
-- the last thing Start reaches.
local entries = #rows + 1
local boxW = 420
local rowH = 32
local headH = 32
local padX = 14
local padY = 8
local boxH = headH + padY*2 + entries*rowH
local boxY = L.HalfH - 28 - boxH
local boxX = (player == PLAYER_1) and (-L.HalfW + 28) or (L.HalfW - 28 - boxW)

local labelW = 150
local subX = padX + labelW + 6
local valueRight = boxW - 34

-- How long the list waits before it fades, and how far.
local idleSeconds = 3
local idleAlpha = 0.16

local function rowY(index)
	return boxY + headH + padY + (index-1)*rowH
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
		self:GetChild("Field"):x(solo and -centreX or 0)
		self:playcommand("Perspective", {Solo = solo})

		local box = self:GetChild("Box")
		L.SetLabel(box:GetChild("Difficulty"), difficultyText(), 9, 150)

		local index = state[pn].Index
		for i = 1, entries do
			local definition = definitionOf(i)
			local focused = (i == index)
			local available = definition == nil
				or definition.Available == nil or definition.Available(player) ~= false

			box:GetChild("RowWash"..i):visible(focused)
			box:GetChild("RowBar"..i):visible(focused)

			local label = box:GetChild("RowLabel"..i)
			L.SetLabel(label, definition and definition.Label()
				or THEME:GetString("ScreenSelectMusic", "QuickModsExit"), 10, labelW)
			label:diffuse(focused and L.Ink or (available and L.Mute or L.Dim))

			local sub = box:GetChild("RowSub"..i)
			local subText = definition and definition.Sub and definition.Sub(player) or ""
			sub:visible(subText ~= "")
			if subText ~= "" then L.SetLabel(sub, subText, 9, 96) end

			local value = box:GetChild("RowValue"..i)
			local text = definition and (available and definition.Value(player) or "--")
				or exitChoiceText()
			L.SetDisplay(value, text, 15, 150)
			value:diffuse(focused and L.Ink or (available and L.Mute or L.Dim))

			-- The arrows are drawn only on the row in hand: on a list this
			-- narrow, ten pairs of them would be the loudest thing in it.
			local left = box:GetChild("RowLeft"..i)
			local right = box:GetChild("RowRight"..i)
			left:visible(focused and available):diffuse(accent)
				:x(boxX + valueRight - value:GetZoomedWidth() - 14)
			right:visible(focused and available):diffuse(accent)
		end

		loadIfChanged(self:GetChild("Field"):GetChild("Judgment"), judgmentPath())
		loadIfChanged(self:GetChild("Field"):GetChild("HoldJudgment"), holdJudgmentPath())

		local combo = self:GetChild("Field"):GetChild("Combo")
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
	-- point and the same rotation.  The figures are ScreenGameplay's own.
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
		local zoom = tilt > 0 and scale(tilt, 0, 1, 1, 0.9) or scale(tilt, 0, -1, 1, 0.9)
		local offset = tilt > 0 and scale(tilt, 0, 1, 0, -45) or scale(tilt, 0, -1, 0, -20)
		tilted:rotationx(scale(tilt, -1, 1, 30, -30)):zoom(zoom):y(offset / L.Scale)
	end,
	VOLT26QuickModsChangedMessageCommand = function(self) self:playcommand("Refresh") end,
	ShowQuickModsCommand = function(self) self:playcommand("Refresh") end,
	OnCommand = function(self) self:playcommand("Refresh") end,
}

-- ------------------------------------------------------------- the field

local field = Def.ActorFrame{Name = "Field"}

-- The band the arrows stand on: enough ground to read them against, and no
-- more, so the song select still shows on either side of it.
field[#field+1] = Def.Quad{
	InitCommand = function(self)
		self:align(0.5,0):xy(centreX, -L.HalfH)
			:zoomto(fieldW + 24, fieldBottom + L.HalfH)
			:diffuse(L.Panel):diffusealpha(0.55)
	end,
}
field[#field+1] = L.Rule{
	X = centreX - fieldW/2 - 12, Y = -L.HalfH, Width = 1, Height = fieldBottom + L.HalfH,
}
field[#field+1] = L.Rule{
	X = centreX + fieldW/2 + 12, Y = -L.HalfH, Width = 1, Height = fieldBottom + L.HalfH,
}

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
		ReceptorY = receptorY, BottomY = fieldBottom,
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
		self:xy(centreX, 0):visible(false):zoom(1/L.Scale)
	end,
}
field[#field+1] = Def.ActorProxy{
	Name = "Combo",
	InitCommand = function(self)
		self:xy(centreX, 92):visible(false):zoom(0.75/L.Scale)
	end,
}
af[#af+1] = field

-- --------------------------------------------------------------- the list

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

box[#box+1] = Def.Quad{
	InitCommand = function(self)
		self:align(0,0):xy(boxX, boxY):zoomto(boxW, boxH):diffuse(L.Panel):diffusealpha(0.94)
	end,
}
local edge = L.Frame("BoxEdge", L.Line)
edge.InitCommand = function(self)
	self:xy(boxX + boxW/2, boxY + boxH/2)
	L.SizeFrame(self, boxW, boxH, 1)
end
box[#box+1] = edge
box[#box+1] = L.Rule{X = boxX, Y = boxY, Width = boxW, Height = 2, Tint = accent}
box[#box+1] = L.Rule{X = boxX, Y = boxY + headH, Width = boxW, Height = 1}

local badgeW = 38
box[#box+1] = Def.Quad{
	InitCommand = function(self)
		self:align(0,0.5):xy(boxX + padX, boxY + headH/2):zoomto(badgeW, 18):diffuse(accent)
	end,
}
box[#box+1] = L.LabelText{
	Text = pn, Px = 10, Tint = L.Ink, Align = center,
	X = boxX + padX + badgeW/2, Y = boxY + headH/2,
}
box[#box+1] = L.LabelText{
	Text = THEME:GetString("ScreenSelectMusic", "QuickMods"), Px = 11, Tint = L.Ink,
	Align = left, X = boxX + padX + badgeW + 12, Y = boxY + headH/2,
}
box[#box+1] = L.LabelText{
	Name = "Difficulty", Px = 9, Tint = L.Mute, Align = right,
	X = boxX + boxW - padX, Y = boxY + headH/2,
}

for i = 1, entries do
	local y = rowY(i)
	box[#box+1] = Def.Quad{
		Name = "RowWash"..i,
		InitCommand = function(self)
			self:align(0,0):xy(boxX, y):zoomto(boxW, rowH)
				:diffuse(accent):diffusealpha(0.22)
				:diffuserightedge(color("0,0,0,0")):visible(false)
		end,
	}
	box[#box+1] = Def.Quad{
		Name = "RowBar"..i,
		InitCommand = function(self)
			self:align(0,0):xy(boxX, y):zoomto(3, rowH):diffuse(accent):visible(false)
		end,
	}
	box[#box+1] = L.LabelText{Name = "RowLabel"..i, Px = 10, Tint = L.Mute, Align = left,
		X = boxX + padX + 8, Y = y + rowH/2}
	box[#box+1] = L.LabelText{Name = "RowSub"..i, Px = 9, Tint = L.Dim, Align = left,
		X = boxX + subX, Y = y + rowH/2}
	box[#box+1] = L.DisplayText{Name = "RowValue"..i, Px = 15, Tint = L.Ink, Align = right,
		X = boxX + valueRight, Y = y + rowH/2}
	box[#box+1] = L.LabelText{Name = "RowLeft"..i, Text = "<", Px = 11, Tint = accent,
		Align = center, Y = y + rowH/2}
	box[#box+1] = L.LabelText{Name = "RowRight"..i, Text = ">", Px = 11, Tint = accent,
		Align = center, X = boxX + boxW - 16, Y = y + rowH/2}
end

box[#box+1] = L.LabelText{
	Text = THEME:GetString("ScreenSelectMusic", "QuickModsHint"), Px = 9, Tint = L.Dim,
	Align = center, X = boxX + boxW/2, Y = boxY + boxH + 14,
}
af[#af+1] = box

return af
