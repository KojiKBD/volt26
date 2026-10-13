-- VOLT26.Cutout.Cache: one texture cache for the cutout lettering, shared by
-- every slot on every screen, and the startup warm-up that fills it.
--
-- Without it each slot renders its strings in its own ActorFrameTexture: a
-- string costs three frames (during which it is invisible) every time it comes
-- back, and nothing survives a change of screen.  The cache keeps rendered
-- strings in a few large pages (ActorFrameTextures of PAGE_W x PAGE_H, packed
-- in shelves) owned by a host actor in ScreenSystemLayer, which outlasts every
-- screen.  A slot that asks for a string already there shows its region of the
-- page at once; a new string is rendered into a page in three frames by the
-- host's single stamper.  Because the stamper holds a BitmapText of each of the
-- six faces, the cutout fonts also stay loaded for the whole session.
--
-- Entries are keyed by the string, the merged lettering options
-- (Cutout.Signature) and the drawn zoom, so a slot of a different size or look
-- never picks up a mismatched texture.  Slots touch the entries they show every
-- frame; a page is reclaimed only when none of its entries has been touched
-- for STALE seconds and none is still rendering, least recently used first.
--
-- Warm-up: Cache.WarmStartup() (called by ScreenVOLT26Warmup) queues the
-- strings already known at startup -- the credit line, the song wheel's grade
-- letters (kept for the whole session), every local profile's name and the
-- names of the packs around the ones the profiles last played --
-- in the sizes VOLT26.Cutout.Styles gives their screens.  It only fills free
-- page space; it never evicts.
--
-- This module owns no layout or screen decisions: the slots (Cutout.CreateSlot)
-- ask, the styles file says how large the warmed strings are drawn.

VOLT26.Cutout = VOLT26.Cutout or {}
local Cutout = VOLT26.Cutout
Cutout.Cache = Cutout.Cache or {}
local Cache = Cutout.Cache

local PAGE_W, PAGE_H = 2048, 1024   -- 8 MB of video memory per page
local SHELF_STEP = 8                -- shelf heights are rounded up to this
local STALE = 0.5                   -- seconds untouched before an entry may go
local CAPACITY = 64                 -- longest string (letters) the stamper draws
local DISPLAY_CHECK = 1             -- seconds between display-reset checks
local WARM_MISSES = 6               -- consecutive strings that did not fit
                                    -- before the warm-up stops trying

-- Pages are created only when needed, up to this many.
local function maxPages()
	if VOLT26.Performance and VOLT26.Performance.IsEnabled() then return 2 end
	return 4
end

-- The live cache (nil until the host is built; replaced on a theme reload,
-- which rebuilds ScreenSystemLayer).
local C = nil

local function now() return GetTimeSinceStart() end

-- ---------------------------------------------------------------------------
-- Page space

-- Shelf packing: a page is cut into horizontal shelves as strings arrive; a
-- string goes on the first shelf tall enough (and not far too tall), else on
-- a new shelf below the last.
local function allocIn(page, w, h)
	for pass = 1, 2 do
		for _, shelf in ipairs(page.shelves) do
			if h <= shelf.h and (pass == 2 or h >= shelf.h * 0.6) and shelf.x + w <= PAGE_W then
				local x = shelf.x
				shelf.x = shelf.x + w
				return x, shelf.y
			end
		end
		if pass == 1 then
			local sh = math.ceil(h / SHELF_STEP) * SHELF_STEP
			if page.top + sh <= PAGE_H then
				local shelf = { y = page.top, h = sh, x = w }
				page.top = page.top + sh
				page.shelves[#page.shelves+1] = shelf
				return 0, shelf.y
			end
		end
	end
	return nil
end

local function resetPage(page)
	for _, e in ipairs(page.entries) do
		e.dead = true
		C.entries[e.key] = nil
	end
	page.entries, page.shelves, page.top = {}, {}, 0
end

-- A page may be reclaimed when nothing on it is rendering, in use or kept.
local function pageIdle(page, t)
	for _, e in ipairs(page.entries) do
		if e.keep or not e.ready or t - e.used < STALE then return false end
	end
	return true
end

local function lastUse(page)
	local last = -math.huge
	for _, e in ipairs(page.entries) do last = math.max(last, e.used) end
	return last
end

local function allocate(w, h, mayEvict)
	if w > PAGE_W or h > PAGE_H then return nil end
	for _, page in ipairs(C.pages) do
		if page.created then
			local x, y = allocIn(page, w, h)
			if x then return page, x, y end
		end
	end
	for _, page in ipairs(C.pages) do
		if not page.created then
			page.aft:Create()
			page.created, page.fresh = true, true
			page.texture = page.aft:GetTexture()
			local x, y = allocIn(page, w, h)
			if x then return page, x, y end
		end
	end
	if not mayEvict then return nil end
	local t, oldest = now(), nil
	for _, page in ipairs(C.pages) do
		if page.created and pageIdle(page, t) and (not oldest or lastUse(page) < lastUse(oldest)) then
			oldest = page
		end
	end
	if not oldest then return nil end
	resetPage(oldest)
	local x, y = allocIn(oldest, w, h)
	if x then return oldest, x, y end
	return nil
end

-- ---------------------------------------------------------------------------
-- Entries

function Cache.Key(text, signature, zoom)
	return signature .. "|" .. ("%.3f"):format(zoom) .. "|" .. text
end

local function promote(e)
	for i, queued in ipairs(C.queue) do
		if queued == e then
			table.remove(C.queue, i)
			table.insert(C.queue, 1, e)
			return
		end
	end
end

-- The entry for `text` drawn from `layout` at `zoom` (texture pixels per
-- layout unit): rendered (entry.ready) or queued.  nil when the cache cannot
-- take it.  `urgent` puts a new or queued string first in line; `mayEvict`
-- lets it reclaim an idle page when every page is full.
local function request(text, signature, layout, zoom, urgent, mayEvict)
	if not C or not layout or #layout.glyphs > CAPACITY then return nil end
	local key = Cache.Key(text, signature, zoom)
	local e = C.entries[key]
	if e then
		e.used = now()
		if urgent and not e.ready and e ~= C.current then promote(e) end
		return e, false
	end
	local b, m = layout.bounds, Cutout.Margin
	local w = math.ceil((b[3] - b[1]) * zoom) + 2 * m
	local h = math.ceil((b[4] - b[2]) * zoom) + 2 * m
	local page, x, y = allocate(w, h, mayEvict)
	if not page then return nil end
	e = {
		key = key, page = page, texture = page.texture,
		x = x, y = y, w = w, h = h, pageW = PAGE_W, pageH = PAGE_H,
		layout = layout, zoom = zoom, passes = Cutout.Passes(layout), pass = 0,
		used = now(), ready = false, dead = false,
	}
	C.entries[key] = e
	page.entries[#page.entries+1] = e
	if urgent then table.insert(C.queue, 1, e) else C.queue[#C.queue+1] = e end
	return e, true
end

-- For Cutout.CreateSlot.
function Cache.Acquire(text, signature, layout, zoom)
	return (request(text, signature, layout, zoom, true, true))
end

-- A slot still shows `entry`.
function Cache.Touch(entry)
	entry.used = now()
end

function Cache.IsAvailable()
	return C ~= nil
end

-- Drops every entry (their slots ask again).  Used when the display may have
-- lost the pages' contents.
function Cache.Flush()
	if not C then return end
	for _, page in ipairs(C.pages) do
		resetPage(page)
		page.fresh = true
		page.aft:visible(false)
	end
	C.queue, C.current = {}, nil
	if C.warmLeft > 0 then
		C.warmLeft = 0
		MESSAGEMAN:Broadcast("VOLT26CutoutWarmupComplete")
	end
	-- Kept strings are drawn again straight away.
	if #C.kept > 0 then Cache.Warm(C.kept) end
end

-- ---------------------------------------------------------------------------
-- Warm-up

-- Queues strings to pre-render, behind anything a slot is waiting for.
-- items: { {text=..., style=<VOLT26.Cutout.Style name>, keep=true|nil}, ... }.
-- Strings that are already cached or cannot be drawn are skipped; the warm-up
-- stops once WARM_MISSES strings in a row found no free page space.  A kept
-- string is never reclaimed (its page stays), and is drawn again after a
-- display reset; keep it for a small set drawn once for the whole session.
-- Answers how many were queued.
function Cache.Warm(items)
	if not C then return 0 end
	local scale = Cutout.DisplayScale()
	local styles, queued, misses = {}, 0, 0
	for _, item in ipairs(items) do
		local text = item.text
		local style = styles[item.style]
		if not style then
			style = Cutout.Style(item.style)
			if style then
				style.merged = Cutout.MergeOptions(style.opts)
				style.signature = Cutout.Signature(style.merged)
				styles[item.style] = style
			end
		end
		if style and type(text) == "string" and text ~= "" then
			local chars = select(2, text:gsub("[^\128-\191]", ""))
			local layout = chars <= style.maxChars and Cutout.Layout(text, style.merged) or nil
			if layout then
				local zoom = Cutout.FitZoom(layout, style.maxW, style.maxH, scale)
				local e, new = request(text, style.signature, layout, zoom, false, false)
				if e and item.keep and not e.keep then
					e.keep = true
					local id = item.style .. "|" .. text
					if not C.keptIds[id] then
						C.keptIds[id] = true
						C.kept[#C.kept+1] = { text = text, style = item.style, keep = true }
					end
				end
				if not e then
					misses = misses + 1
					if misses >= WARM_MISSES then break end
				else
					misses = 0
					if new then
						e.warm = true
						queued = queued + 1
					end
				end
			end
		end
	end
	C.warmLeft = C.warmLeft + queued
	C.warmTotal = C.warmTotal + queued
	return queued
end

local function addPackOrder(items, list, seeds)
	local count = #list
	if count == 0 then return end
	local taken, order = {}, {}
	for d = 0, count - 1 do
		for _, seed in ipairs(seeds) do
			for _, index in ipairs(d == 0 and { seed } or { seed + d, seed - d }) do
				index = (index - 1) % count + 1
				if not taken[index] then
					taken[index] = true
					order[#order+1] = index
				end
			end
		end
		if #order >= count then break end
	end
	for _, index in ipairs(order) do
		local name = list[index].Name
		items[#items+1] = { text = name, style = "SongPack" }
		items[#items+1] = { text = name, style = "PackName" }
	end
end

-- The strings known before any screen asks for them.  Answers how many were
-- queued; "VOLT26CutoutWarmupComplete" is broadcast once they are all drawn.
function Cache.WarmStartup()
	if not C then return 0 end
	local items = {}
	local function add(text, style)
		if type(text) == "string" and text ~= "" then items[#items+1] = { text = text, style = style } end
	end
	local function themeString(section, name)
		local ok, value = pcall(function() return THEME:GetString(section, name) end)
		return ok and value or nil
	end

	-- The credit line (ScreenSystemLayer overlay.lua).
	add(themeString("ScreenSystemLayer", "EventMode"), "CreditCentre")
	add(themeString("ScreenSystemLayer", "FreePlay"), "CreditCentre")
	for _, player in ipairs({ PLAYER_1, PLAYER_2 }) do
		local ok, message = pcall(function() return ScreenSystemLayerHelpers.GetCreditsMessage(player) end)
		if ok then add(message, "CreditPlayer") end
	end

	-- The lettered grades of the song wheel (overlay/SongWheel/Grade.lua),
	-- drawn once and kept for the whole session.
	local letters = {}
	for _, letter in pairs(Cutout.GradeLetters or {}) do letters[#letters+1] = letter end
	table.sort(letters)
	for _, style in ipairs({ "SongGrade", "SongGradeP1", "SongGradeP2" }) do
		for _, letter in ipairs(letters) do
			items[#items+1] = { text = letter, style = style, keep = true }
		end
	end

	-- Profiles: the profile screen's card, the song wheel's cards and footer.
	-- A guest plays as "P1"/"P2" on the song wheel (its S.PlayerName).
	local names, lastGroups = {}, {}
	pcall(function()
		for i = 0, PROFILEMAN:GetNumLocalProfiles() - 1 do
			local profile = PROFILEMAN:GetLocalProfileFromIndex(i)
			if profile then
				names[#names+1] = profile:GetDisplayName()
				local song = profile:GetLastPlayedSong()
				if song then lastGroups[#lastGroups+1] = song:GetGroupName() end
			end
		end
	end)
	add(themeString("ScreenSelectProfile", "GuestProfile"), "ProfileName")
	for _, name in ipairs(names) do
		add(name, "ProfileName")
		add(name, "SongCardName")
		add(name, "SongFooterName")
	end
	for _, short in ipairs({ "P1", "P2" }) do
		add(short, "SongCardName")
		add(short, "SongFooterName")
	end

	-- Packs, nearest first around the packs the profiles last played and the
	-- one the carousel opens on.  (PackSelection.List() also empties its
	-- artwork and summary caches, which are still empty at startup.)
	local PackSelection = VOLT26.PackSelection
	if PackSelection then
		local ok, list = pcall(PackSelection.List)
		if ok and type(list) == "table" and #list > 0 then
			local seeds, seen = {}, {}
			local function seed(index)
				if index and not seen[index] then seen[index] = true; seeds[#seeds+1] = index end
			end
			for _, group in ipairs(lastGroups) do
				for index, entry in ipairs(list) do
					if entry.Name == group then seed(index) end
				end
			end
			local okIndex, initial = pcall(PackSelection.InitialIndex, list)
			seed(okIndex and initial or 1)
			addPackOrder(items, list, seeds)
		end
	end

	local queued = Cache.Warm(items)
	if C.warmLeft == 0 then MESSAGEMAN:Broadcast("VOLT26CutoutWarmupComplete") end
	return queued
end

-- Diagnostics: pages created, entries held (with their regions), strings
-- waiting to render.
function Cache.Stats()
	local stats = { pages = 0, entries = 0, queued = 0, regions = {} }
	if not C then return stats end
	for _, page in ipairs(C.pages) do
		if page.created then stats.pages = stats.pages + 1 end
		for _, e in ipairs(page.entries) do
			stats.entries = stats.entries + 1
			stats.regions[#stats.regions+1] = { page = page.index, x = e.x, y = e.y, w = e.w, h = e.h, ready = e.ready }
		end
	end
	stats.queued = #C.queue + (C.current and 1 or 0)
	return stats
end

-- Warm-up strings drawn and queued so far.
function Cache.WarmProgress()
	if not C then return 0, 0 end
	return C.warmTotal - C.warmLeft, C.warmTotal
end

-- ---------------------------------------------------------------------------
-- The host

-- What a display reset would change.  A new video mode can recreate the
-- rendering context, and render targets lose their contents with it.
local function displaySignature()
	local parts = {}
	pcall(function()
		parts[#parts+1] = DISPLAY:GetDisplayWidth()
		parts[#parts+1] = DISPLAY:GetDisplayHeight()
	end)
	for _, name in ipairs({ "Windowed", "FullscreenIsBorderlessWindow", "DisplayColorDepth", "Vsync" }) do
		local ok, value = pcall(function() return PREFSMAN:GetPreference(name) end)
		parts[#parts+1] = ok and tostring(value) or "?"
	end
	return table.concat(parts, ",")
end

-- Whether the host is drawn this frame without a fade (which would be baked
-- into the stamps).  Tweens elsewhere in the system layer do not matter.
local function drawable(actor)
	while actor do
		if not actor:GetVisible() or actor:GetDiffuseAlpha() < 1 then return false end
		actor = actor:GetParent()
	end
	return true
end

local function finish(job)
	job.page.aft:visible(false)
	job.ready = true
	job.layout, job.passes = nil, nil
	C.current = nil
	if job.warm then
		job.warm = false
		C.warmLeft = math.max(0, C.warmLeft - 1)
		MESSAGEMAN:Broadcast("VOLT26CutoutWarmupProgress", {
			Done = C.warmTotal - C.warmLeft, Total = C.warmTotal,
		})
		if C.warmLeft == 0 then MESSAGEMAN:Broadcast("VOLT26CutoutWarmupComplete") end
	end
end

-- One pass of one string per frame: the pass set up here is drawn into its
-- page this frame, and the next update moves on.
local function update(host)
	if not C then return end
	local t = now()
	if t >= C.nextCheck then
		C.nextCheck = t + DISPLAY_CHECK
		local display = displaySignature()
		if display ~= C.display then
			C.display = display
			Cache.Flush()
		end
	end

	local job = C.current
	if job and job.pass >= #job.passes then
		finish(job)
		job = nil
	end
	if not job then
		job = table.remove(C.queue, 1)
		while job and job.dead do job = table.remove(C.queue, 1) end
		if not job then return end
		C.current = job
	end
	if not drawable(host) then return end

	job.pass = job.pass + 1
	local page, first = job.page, job.pass == 1
	-- A page's very first pass clears it whole; afterwards only the region
	-- being drawn is cleared (by the CopySrc quad), so the rest survives.
	page.aft:EnablePreserveTexture(not (first and page.fresh))
	if first then page.fresh = false end
	C.clear:visible(first)
	if first then C.clear:xy(job.x, job.y):zoomto(job.w, job.h) end
	local b, m, zoom = job.layout.bounds, Cutout.Margin, job.zoom
	C.stamper.Frame(job.layout, job.x + m - b[1] * zoom, job.y + m - b[2] * zoom, zoom)
	C.stamper.Pass(job.layout, job.passes[job.pass])
	for _, other in ipairs(C.pages) do
		if other ~= page then other.aft:visible(false) end
	end
	page.aft:visible(true)
end

-- The host actor, for ScreenSystemLayer.  It draws nothing on screen: the
-- pages render into their textures, and the stage they stamp is only drawn
-- through their proxies.
function Cache.CreateHost()
	local stamper = Cutout.NewStamper(CAPACITY)
	local generation = math.floor(GetTimeSinceStart() * 1000)
	C = {
		pages = {}, entries = {}, queue = {}, current = nil,
		stamper = stamper, warmLeft = 0, warmTotal = 0, kept = {}, keptIds = {},
		display = displaySignature(), nextCheck = 0,
	}
	local live = C

	local host = Def.ActorFrame{
		Name = "VOLT26CutoutCache",
		InitCommand = function(self)
			self:SetUpdateFunction(update)
		end,
		Def.ActorFrame{
			Name = "Stage",
			InitCommand = function(self) self:visible(false) end,
			Def.Quad{
				InitCommand = function(self)
					live.clear = self
					-- CopySrc overwrites the region with this colour; the engine
					-- skips actors whose alpha is exactly 0, so it carries an
					-- alpha that still rounds to 0 in an 8-bit target.
					self:halign(0):valign(0):diffuse(0, 0, 0, 0.001)
						:blend("BlendMode_CopySrc"):visible(false)
				end,
			},
			stamper.Actor(),
		},
	}
	for i = 1, maxPages() do
		host[#host+1] = Def.ActorFrameTexture{
			InitCommand = function(self)
				-- Created (and its memory taken) only when first needed.
				self:setsize(PAGE_W, PAGE_H)
				self:SetTextureName(("VOLT26CutoutPage%d_%d"):format(i, generation))
				self:EnableAlphaBuffer(true):EnablePreserveTexture(true):visible(false)
				live.pages[i] = {
					index = i, aft = self, created = false, fresh = true,
					shelves = {}, top = 0, entries = {},
				}
			end,
			Def.ActorProxy{
				InitCommand = function(self)
					self:SetTarget(self:GetParent():GetParent():GetChild("Stage"))
				end,
			},
		}
	end
	return host
end
