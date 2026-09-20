-- The actors the Quick Mods preview draws through.
--
-- A note skin's elements are built when the actor tree is, and the tree cannot
-- be rebuilt while the screen is open -- so a menu that lets the player change
-- skins cannot simply load the one they started on.  Instead every skin gets
-- one hidden sample per column and per rhythm here, and the preview's notes are
-- ActorProxies that are pointed at whichever sample the player's current choice
-- calls for.  Swapping skins then costs a pointer rather than a rebuild.
--
-- The samples are shared by both players, so two players on two skins cost the
-- same as one, and only the rhythms the demonstration chart actually contains
-- are built.
--
-- The combo fonts are here for a different cause: a BitmapText cannot change
-- its face once it is built, because the engine's Lua bindings do not expose
-- LoadFromFont.  The judgment and hold judgment samples are ordinary images, so
-- those the panel simply loads by path.

local Sources = {}

-- ------------------------------------------------------------ note colour
--
-- How the engine colours a note, and why it has to be copied rather than
-- guessed at.
--
-- NoteDisplay draws a tap by loading a *different actor per note colour* and
-- then translating that actor's texture by the skin's own
-- NoteColorTextureCoordSpacing times the note's NoteType index.  The Lua
-- binding NOTESKIN:LoadActorForNoteSkin cannot ask for a colour -- it passes
-- "4th" and nothing else -- so every sample below is the quarter-note actor and
-- the rhythm has to come from that texture translation alone.  Actor's own
-- texturetranslate pushes the same texture matrix the engine pushes, so a
-- sample coloured this way is coloured the way gameplay colours it.
--
-- The spacing is per skin and per axis: cel steps 1/32 across, cyber 1/8
-- across, enchantment 1/8 *down*, ddr-note 1/16 across.  A vivid skin does not
-- step at all -- it picks a frame out of an animation, which Lua has no way to
-- drive -- so a vivid skin previews in one colour and everything that colours
-- by texture coordinates previews exactly.

-- The engine's NoteType order (NoteTypes.cpp), which is what the spacing is
-- multiplied by.  12th comes before 16th.
local noteTypeIndex = {[4]=0, [8]=1, [12]=2, [16]=3, [24]=4, [32]=5, [48]=6, [64]=7}

-- The rhythms the demonstration chart can produce.  Anything outside this set
-- falls back to the quarter-note sample rather than drawing nothing.
Sources.Rhythms = {4, 8, 12, 16, 24}

local fallbackTint = {
	[4]  = color("#e0403a"), [8]  = color("#3f7fe0"), [12] = color("#9b5fd8"),
	[16] = color("#e0c23a"), [24] = color("#e05fa8"), [32] = color("#e08a3a"),
}

function Sources.Tint(quantization)
	return fallbackTint[quantization] or fallbackTint[32]
end

local function metricF(button, name, skin, fallback)
	local ok, value = pcall(function()
		return NOTESKIN:GetMetricFForNoteSkin(button, name, skin)
	end)
	return (ok and tonumber(value)) or fallback
end

local function metricI(button, name, skin, fallback)
	local ok, value = pcall(function()
		return NOTESKIN:GetMetricIForNoteSkin(button, name, skin)
	end)
	return (ok and tonumber(value)) or fallback
end

-- The texture offset that turns the quarter-note sample into this rhythm's
-- note, in the same terms NoteDisplay uses.
local function colourOffset(skin, button, part, quantization)
	local spacingX = metricF(button, part .. "NoteColorTextureCoordSpacingX", skin, 0)
	local spacingY = metricF(button, part .. "NoteColorTextureCoordSpacingY", skin, 0)
	if spacingX == 0 and spacingY == 0 then return 0, 0 end
	local count = math.max(1, metricI(button, part .. "NoteColorCount", skin, 8))
	local index = math.min(noteTypeIndex[quantization] or 0, count - 1)
	return spacingX * index, spacingY * index
end

-- The skins the menu may cycle through, which is every skin the game has: the
-- player can reach any of them from the menu, so a sample has to exist for any
-- of them before the screen opens.
function Sources.Names()
	local ok, all = pcall(function() return NOTESKIN:GetNoteSkinNames(false) end)
	if not (ok and type(all) == "table" and #all > 0) then return {} end
	return all
end

local function columnNames(player)
	local style = GAMESTATE:GetCurrentStyle()
	local count = 4
	local okCount, columns = pcall(function() return style:ColumnsPerPlayer() end)
	if okCount and tonumber(columns) and columns > 0 then count = columns end

	local names = {}
	for i = 1, count do
		local okInfo, info = pcall(function() return style:GetColumnInfo(player, i) end)
		names[i] = (okInfo and info and info.Name) or "Up"
	end
	return names
end

-- The panel is laid out for one player's own columns, and both players are on
-- the same style, so the column names are read once from whoever is playing.
function Sources.Columns()
	local humans = GAMESTATE:GetHumanPlayers()
	return columnNames(humans[1] or PLAYER_1)
end

-- A skin whose element cannot be loaded at all leaves a diamond behind, so a
-- broken skin shows as a plain note rather than as an empty field.
local function fallbackActor(element)
	local mine = element == "Tap Mine"
	local receptor = element == "Receptor"
	return Def.Quad{
		InitCommand = function(self)
			self:zoomto(receptor and 52 or 46, receptor and 8 or 46)
				:diffuse(mine and color("#8a8a94") or color("#f2f0ec"))
				:diffusealpha(receptor and 0.45 or 0.9)
				:rotationz(receptor and 0 or 45)
		end,
	}
end

local function element(skin, columnName, name, actorName)
	local ok, actor = pcall(NOTESKIN.LoadActorForNoteSkin, NOTESKIN, columnName, name, skin)
	if not ok or not actor then actor = fallbackActor(name) end
	actor.Name = actorName
	return actor
end

function Sources.ComboKey(font)
	return "Combo_" .. tostring(font)
end

function Sources.Key(skin, column, kind, quantization)
	if kind == "tap" then
		return ("Tap_%s_%d_%d"):format(skin, column, quantization)
	end
	return ("%s_%s_%d"):format(kind, skin, column)
end

-- Build(shared) -> an ActorFrame holding every sample, hidden.  It files itself
-- in `shared` so the previews can find a sample by the key it was filed under.
function Sources.Build(shared)
	local af = Def.ActorFrame{
		Name = "QuickModsNoteSkinSources",
		InitCommand = function(self)
			shared.Frame = self
			self:visible(false)
		end,
	}
	local columns = Sources.Columns()

	for skin in ivalues(Sources.Names()) do
		for column, columnName in ipairs(columns) do
			for quantization in ivalues(Sources.Rhythms) do
				local offsetX, offsetY = colourOffset(skin, columnName, "TapNote", quantization)
				af[#af+1] = Def.ActorFrame{
					Name = Sources.Key(skin, column, "tap", quantization),
					-- The translate sits on the frame rather than on the element,
					-- so a skin whose note is built from several layers is shifted
					-- whole.
					InitCommand = function(self)
						if offsetX ~= 0 or offsetY ~= 0 then
							self:texturetranslate(offsetX, offsetY)
						end
					end,
					element(skin, columnName, "Tap Note", "Visual"),
				}
			end
			af[#af+1] = element(skin, columnName, "Tap Mine", Sources.Key(skin, column, "mine"))
			af[#af+1] = element(skin, columnName, "Receptor", Sources.Key(skin, column, "receptor"))
			-- Every hold in the demonstration chart starts on a quarter, so the
			-- head needs no colour of its own.
			af[#af+1] = Def.ActorFrame{
				Name = Sources.Key(skin, column, "holdhead"),
				element(skin, columnName, "Hold Head Inactive", "Visual"),
			}
		end
	end

	local okFonts, fonts = pcall(GetComboFonts)
	if okFonts and type(fonts) == "table" then
		for font in ivalues(fonts) do
			if font ~= "None" then
				af[#af+1] = LoadFont("_Combo Fonts/" .. font .. "/" .. font)..{
					Name = Sources.ComboKey(font),
					Text = "247",
				}
			end
		end
	end

	return af
end

return Sources
