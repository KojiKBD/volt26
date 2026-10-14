-- The preview of a pack row in the Simply Love layout (theme preference
-- MusicSelectionLayout), where the wheel lists every pack: while the wheel
-- rests on a pack (or a series of packs, or a section of another sort) the
-- song's details step aside and this takes their place.
--
--   * the jacket frame keeps the pack's artwork (Header.lua's badge, which
--     follows S.Pack(), the hovered pack here);
--   * the mockup's dark info panel (the Panel piece) carries a heading drawn
--     as a wheel row -- the song count and meter range on the black band, the
--     pack's name on the white one -- and under it the pack's songs, one line
--     each: number, jacket or banner thumbnail, title and artist, and the top
--     meter as a small badge.  A series lists its packs instead.  A list
--     longer than the panel turns its pages by itself.
--
-- The Carousel layout has the Joker for these rows (Joker.lua); this part then
-- never shows.  Behaviour comes from VOLT26.PackSelection
-- (WheelSectionContents, Summary, Artwork); this file only presents it.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local R = P.Art.Row

local GREY = color("#9a9aa2")
local FILL_DELAY = 0.12        -- the wheel must rest this long before the list fills
local PAGE_SECONDS = 3.2       -- how long a page of a long list stays
local PAGE_FADE = 0.12

-- The heading: a wheel row (Graphics/VOLT26/SongWheel/Row.lua) drawn larger at
-- the panel's top left.  Positions inside it are the row's own.
local HEAD = { X = 1232, Y = 404, Zoom = 1.2 }
local HEAD_INFO = { X = 14, Baseline = 48, Cap = 30, Width = 380 }
local HEAD_NAME = { X = 8, Baseline = 102, Cap = 38, Width = 395 }
local TEXT_ROT = 1.2

-- The list, on the panel under the heading (the panel's left edge runs from
-- x 1213 at its top to 1238 at its bottom, its foot is at y 850 on the left).
local ROWS = 6
local ROW_TOP, PITCH = 584, 44
local INDEX_X = 1252
local THUMB = { X = 1312, Size = 38 }
local TEXT_X, TEXT_W = 1342, 440
local BADGE = { X = 1836, Zoom = 0.24 }
local RANGE = { X = 1878, Baseline = 856, Cap = 18 }

local function setText(actor, text, width, minScale)
	P.FitText(actor, text or "", width, minScale or 0.6, true)
end

-- The line under the heading's black band: how much the pack holds.
local function infoLine(contents)
	if contents.Kind == "Series" then
		return ("COLLECTION - %d PACKS - %d SONGS"):format(#contents.Packs, contents.Songs)
	end
	local count = #contents.Songs
	local text = ("%d SONG%s"):format(count, count == 1 and "" or "S")
	if contents.Kind == "Pack" then
		local summary = VOLT26.PackSelection.Summary(contents.Name)
		if summary and summary.MinMeter and summary.MaxMeter then
			if summary.MinMeter == summary.MaxMeter then
				text = text .. (" - LV %d"):format(summary.MinMeter)
			else
				text = text .. (" - LV %d-%d"):format(summary.MinMeter, summary.MaxMeter)
			end
		end
	end
	return text
end

-- One line of the list for an item (a song, or a pack of a series):
-- title, sub line, artwork path and cache directory, meter.
local function lineFor(contents, item)
	if contents.Kind == "Series" then
		local count = #(SONGMAN:GetSongsInGroup(item) or {})
		local art = VOLT26.PackSelection.Artwork(item)
		return item, ("%d SONG%s"):format(count, count == 1 and "" or "S"),
			art and art.Path or nil, art and art.Kind or nil, nil
	end
	local path, cacheDir = K.SongArt(item)
	return VOLT26.SongBrowsing.WheelTitle(item), item:GetDisplayArtist() or "", path, cacheDir, P.TopMeter(item)
end

local function items(contents)
	if not contents then return {} end
	return contents.Kind == "Series" and contents.Packs or contents.Songs
end

local function fillRow(row, contents, item, number)
	row:visible(item ~= nil)
	if not item then return end
	local title, sub, path, cacheDir, meter = lineFor(contents, item)
	setText(row:GetChild("Index"), ("%02d"):format(number), 40, 1)
	setText(row:GetChild("Title"), title, TEXT_W, 0.7)
	P.FitEllipsis(row:GetChild("Sub"), sub, TEXT_W, 0.8)
	P.SetBadge(row:GetChild("Badge"), meter)
	local art = row:GetChild("Art")
	if path ~= row.loadedArt then
		row.loadedArt = path
		-- The small cached copy: a thumbnail needs no more.
		if K.LoadStill(art, path, cacheDir) then
			K.Cover(art, THUMB.Size, THUMB.Size)
			row.hasArt = true
		else
			row.hasArt = false
		end
	end
	art:visible(row.hasArt == true)
end

local function showPage(self)
	local list = items(self.contents)
	local first = (self.page - 1) * ROWS
	local rows = self:GetChild("List")
	for i = 1, ROWS do
		local index = first + i
		fillRow(rows:GetChild("Row" .. i), self.contents, list[index], index)
	end
	local count = #list
	local last = math.min(count, first + ROWS)
	setText(self:GetChild("Range"), count > ROWS and ("%02d-%02d / %d"):format(first + 1, last, count) or "", 200, 1)
end

local function pages(self)
	return math.max(1, math.ceil(#items(self.contents) / ROWS))
end

local function rightSide(layout)
	local info = layout:GetChild("Info")
	return info and info:GetChild("Right") or nil
end

local af = Def.ActorFrame{
	Name = "PackPreview",
	InitCommand = function(self)
		self.section, self.shown, self.modal = nil, false, false
		self:visible(false)
	end,
	-- Light: runs on every step of the wheel.  Showing, hiding and the name
	-- follow at once; the list waits for the wheel to rest (FillCommand).
	RefreshCommand = function(self)
		local name, parent = S.HoveredSection()
		local key = name and (tostring(parent) .. "|" .. name) or nil
		local wanted = key ~= nil
		if wanted ~= self.shown then
			self.shown = wanted
			self:visible(wanted and not self.modal)
			local right = rightSide(self:GetParent())
			if right then right:visible(not wanted) end
		end
		if key == self.section then return end
		self.section = key
		self:stoptweening()
		self:GetChild("List"):stoptweening():diffusealpha(0)
		self:GetChild("Range"):settext("")
		if not wanted then return end
		self.name, self.parent = name, parent
		local head = self:GetChild("Head")
		setText(head:GetChild("Name"), name, HEAD_NAME.Width, 0.55)
		head:GetChild("Info"):settext("")
		self:sleep(FILL_DELAY):queuecommand("Fill")
	end,
	FillCommand = function(self)
		if not self.section then return end
		self.contents = VOLT26.PackSelection.WheelSectionContents(self.name, self.parent)
		if not self.contents then return end
		P.FitEllipsis(self:GetChild("Head"):GetChild("Info"), infoLine(self.contents), HEAD_INFO.Width, 0.8)
		self.page = 1
		showPage(self)
		self:GetChild("List"):stoptweening():linear(PAGE_FADE):diffusealpha(1)
		if pages(self) > 1 then self:sleep(PAGE_SECONDS):queuecommand("Turn") end
	end,
	-- The next page of a long list: out, refilled, back in.
	TurnCommand = function(self)
		if not self.section or not self.contents then return end
		self:GetChild("List"):stoptweening():linear(PAGE_FADE):diffusealpha(0)
		self:sleep(PAGE_FADE):queuecommand("TurnIn")
	end,
	TurnInCommand = function(self)
		if not self.section or not self.contents then return end
		self.page = self.page % pages(self) + 1
		showPage(self)
		self:GetChild("List"):stoptweening():linear(PAGE_FADE):diffusealpha(1)
		self:sleep(PAGE_SECONDS):queuecommand("Turn")
	end,
	-- A modal overlay (sort menu, song search...) owns the screen meanwhile.
	VOLT26ModalOverlayOpenedMessageCommand = function(self)
		self.modal = true
		self:visible(false)
	end,
	VOLT26ModalOverlayClosedMessageCommand = function(self)
		self.modal = false
		self:visible(self.shown)
	end,
	OffCommand = function(self) self:stoptweening() end,
}

-- The mockup's info panel, under everything else, in the heading's black so
-- the heading's black band runs into it seamlessly.
af[#af+1] = P.Piece("Panel", 0, 0, {
	OnCommand = function(self) self:diffuse(P.Black) end,
})

-- The heading, as a wheel row.
af[#af+1] = Def.ActorFrame{
	Name = "Head",
	InitCommand = function(self) self:xy(HEAD.X, HEAD.Y):zoom(HEAD.Zoom) end,
	P.Piece("RowBands", R.Anchors[-1][1], R.Anchors[-1][2]),
	P.Text{ Name="Info", Cap=HEAD_INFO.Cap, X=HEAD_INFO.X, Baseline=HEAD_INFO.Baseline,
		Rot=TEXT_ROT, Tint=P.White },
	P.Text{ Name="Name", Cap=HEAD_NAME.Cap, X=HEAD_NAME.X, Baseline=HEAD_NAME.Baseline,
		Rot=TEXT_ROT, Tint=P.Black },
}

-- The list.
local list = Def.ActorFrame{ Name = "List", InitCommand = function(self) self:diffusealpha(0) end }
for i = 1, ROWS do
	local y = ROW_TOP + (i - 1) * PITCH
	list[#list+1] = Def.ActorFrame{
		Name = "Row" .. i,
		InitCommand = function(self) self:y(y):visible(false) end,
		P.Text{ Name="Index", Cap=18, X=INDEX_X, Baseline=7, Tint=GREY },
		-- The thumbnail's place; a song without artwork leaves it dark.
		Def.Quad{ InitCommand=function(self)
			self:x(THUMB.X):zoomto(THUMB.Size, THUMB.Size):diffuse(color("#222226"))
		end },
		-- Upright, like every jacket (.agents/presentation.md).
		Def.Sprite{ Name="Art", InitCommand=function(self) self:x(THUMB.X):visible(false) end },
		P.Text{ Name="Title", Cap=22, X=TEXT_X, Baseline=1, Tint=P.White },
		P.Text{ Name="Sub", Cap=14, X=TEXT_X, Baseline=20, Tint=GREY },
		P.Badge{ Name="Badge", X=BADGE.X, Y=0, Zoom=BADGE.Zoom },
	}
end
af[#af+1] = list

af[#af+1] = P.Text{ Name="Range", Cap=RANGE.Cap, X=RANGE.X, Baseline=RANGE.Baseline, Align=1, Tint=GREY }

return af
