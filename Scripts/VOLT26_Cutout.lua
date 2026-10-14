-- VOLT26.Cutout: "ransom note" lettering for strings only known at runtime.
--
-- Every letter has its own face, size, tilt, baseline offset and sometimes an
-- inverted box, white on a black backing.  The look is baked offline into
-- bitmap fonts (tools/cutout-fonts/generate.py): each character was given its
-- look once, so a letter always looks the same wherever it appears.  A string
-- is drawn with two BitmapTexts over each other -- "Cutout Back" (the
-- backings) then "Cutout Ink" (the letters) -- so every backing lies under
-- every letter and neighbouring backings merge.  Nothing is rendered to a
-- texture, cached or warmed up: a string shows on the frame it is set.
--
-- The module has two halves:
--   * VOLT26.Cutout.Layout(text, opts) is behaviour only: the size the
--     lettering takes, as plain data, from the baked metrics
--     (Scripts/VOLT26_CutoutMetrics.lua, generated with the fonts).
--   * VOLT26.Cutout.CreateSlot(params) is the presentation.
--
-- The grade letters also exist in "Cutout Large Back" / "Cutout Large Ink"
-- (same looks, a larger em), used when a slot draws them big.

VOLT26.Cutout = VOLT26.Cutout or {}
local Cutout = VOLT26.Cutout

-- Tunables.  Sizes are in theme units (the screen is SCREEN_HEIGHT units tall).
-- Any of these can be overridden per slot through CreateSlot's `opts`.  The
-- per-letter look (faces, sizes, boxes, tilts) is baked into the fonts.
Cutout.Defaults = {
	base = 22,            -- letter size (em)
	upperChance = 0.5,    -- 1: every letter upper case, 0: lower case,
	                      -- anything else: the case as typed
	tiltDeg = -5,         -- rotation of the whole block
	fg = color("#FFFFFF"),
	bk = color("#000000"),
}

-- Screens that show the cutout lettering in place of plain text.
Cutout.Screens = {
	ScreenTitleMenu = true,
	-- The menus between the title and song selection share its footer.
	ScreenSelectStyle = true,
	ScreenSelectPlayMode = true,
	ScreenSelectPlayMode2 = true,
	ScreenVOLT26SelectMode = true,
}

function Cutout.IsEnabledOn(screenName)
	return screenName ~= nil and Cutout.Screens[screenName] == true
end

local function merge(opts)
	local o = {}
	for k, v in pairs(Cutout.Defaults) do o[k] = v end
	if opts then for k, v in pairs(opts) do o[k] = v end end
	return o
end
Cutout.MergeOptions = merge

local function characters(text)
	local list = {}
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		list[#list+1] = ch
	end
	return list
end

-- Display pixels per theme unit.
function Cutout.DisplayScale()
	if DISPLAY and DISPLAY.GetDisplayHeight then
		return math.min(3, math.max(1, DISPLAY:GetDisplayHeight() / SCREEN_HEIGHT))
	end
	return 1
end

-- ---------------------------------------------------------------------------
-- Layout

-- Where the block turns, relative to the start of the line on its baseline,
-- in em: the middle of the line, a little above the baseline.
local PIVOT_Y = -0.35

-- Returns a table describing the lettering, or nil plus the first character
-- the fonts cannot draw.  All sizes are in the units of opts.base.
--
--   layout.text       the string as it is drawn (case applied)
--   layout.width      length of the line (sum of the advances)
--   layout.bounds     {minX, minY, maxX, maxY} of everything drawn, tilt
--                     included, relative to the block's pivot
--   layout.large      true when the large fonts can draw the whole string
--   layout.options    the merged options
function Cutout.Layout(text, opts)
	local M = VOLT26.CutoutMetrics
	if not M then return nil, "metrics" end
	local o = merge(opts)
	local base = o.base
	local G = M.glyphs

	local drawn, x, large = {}, 0, true
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local corners = {}
	for _, raw in ipairs(characters(text or "")) do
		local ch = raw
		if o.upperChance >= 1 then ch = M.upper[raw] or raw
		elseif o.upperChance <= 0 then ch = M.lower[raw] or raw end
		-- A letter the fonts only have in the other case (and the like).
		if not G[ch] then ch = M.upper[ch] or M.lower[ch] or ch end
		local g = G[ch]
		if not g then return nil, raw end
		if not M.large[ch] then large = false end
		drawn[#drawn+1] = ch
		if g[4] > g[2] then
			corners[#corners+1] = {x + g[2], g[3]}
			corners[#corners+1] = {x + g[4], g[3]}
			corners[#corners+1] = {x + g[2], g[5]}
			corners[#corners+1] = {x + g[4], g[5]}
		end
		x = x + g[1]
	end
	if #drawn == 0 or #corners == 0 then return nil, "" end

	-- Corners in em relative to the line's start; the bounds are in base
	-- units, relative to the pivot and turned with the block.
	local tilt = math.rad(o.tiltDeg or 0)
	local ct, st = math.cos(tilt), math.sin(tilt)
	local px, py = x / 2, PIVOT_Y
	for _, c in ipairs(corners) do
		local dx, dy = (c[1] - px) * base, (c[2] - py) * base
		local tx, ty = dx * ct - dy * st, dx * st + dy * ct
		if tx < minX then minX = tx end
		if tx > maxX then maxX = tx end
		if ty < minY then minY = ty end
		if ty > maxY then maxY = ty end
	end

	return {
		text = table.concat(drawn),
		width = x * base,
		height = base,
		bounds = {minX, minY, maxX, maxY},
		large = large,
		options = o,
	}
end

-- The zoom of a layout shrunk (never grown) to fit maxW x maxH theme units.
function Cutout.FitZoom(layout, maxW, maxH)
	local b = layout.bounds
	return math.min(1, maxW / math.max(1e-6, b[3] - b[1]), maxH / math.max(1e-6, b[4] - b[2]))
end

-- ---------------------------------------------------------------------------
-- Presentation

-- The large fonts are used once a letter would be drawn bigger than this
-- many times the regular fonts' em in display pixels.
local LARGE_FROM = 1.3

-- params:
--   maxW, maxH   the space the lettering must fit, in theme units
--   halign       0 left, 0.5 centre, 1 right: which edge of the lettering sits
--                on the slot's x
--   valign       0 top, 0.5 centre, 1 bottom, likewise for y
--   maxChars     longest string drawn in cutout (longer strings fall back)
--   opts         overrides for Cutout.Defaults
--   fallbackFont font for strings the cutout fonts cannot draw
--   fallbackZoom its zoom
--   x, y         optional position
--   onInit       optional function(slot) called from the slot's InitCommand
--                (a caller's own InitCommand would replace the slot's)
--   onReady      optional function(slot) called once a string is shown (on
--                the next update after it was set), e.g. to swap two slots
--   held         start held: the string is set but not shown until
--                "CutoutHold" releases it
--
-- Commands: "CutoutSet" with {text=...} draws a string (no-op when unchanged);
-- "CutoutHold" with {held=true|false} hides or shows the lettering.
function Cutout.CreateSlot(params)
	params = params or {}
	local M = VOLT26.CutoutMetrics or {}
	local opts = merge(params.opts)
	local maxW, maxH = params.maxW or 240, params.maxH or opts.base * 2
	local halign, valign = params.halign or 0.5, params.valign or 0.5
	local maxChars = params.maxChars or 16
	local useLarge = M.emLarge and opts.base * Cutout.DisplayScale() > M.em * LARGE_FROM

	local state = { text = nil, held = params.held == true, ready = false, plainShown = false }

	-- One lettering: a pair of BitmapTexts (backing, letters) in a tilted
	-- frame, in the regular or the large fonts.
	local function lettering(name, fonts, em)
		return Def.ActorFrame{
			Name=name,
			InitCommand=function(self)
				state[name] = {
					frame = self,
					tilt = self:GetChild("Tilt"),
					back = self:GetChild("Tilt"):GetChild("Back"),
					ink = self:GetChild("Tilt"):GetChild("Ink"),
					em = em,
				}
				self:visible(false)
			end,
			Def.ActorFrame{
				Name="Tilt",
				LoadFont(fonts.back)..{
					Name="Back",
					InitCommand=function(self) self:halign(0):valign(1):diffuse(opts.bk) end,
				},
				LoadFont(fonts.ink)..{
					Name="Ink",
					InitCommand=function(self) self:halign(0):valign(1):diffuse(opts.fg) end,
				},
			},
		}
	end

	local function hideAll()
		if state.Regular then state.Regular.frame:visible(false) end
		if state.Large then state.Large.frame:visible(false) end
		state.plain:visible(false)
		state.shown = nil
	end

	local function show(layout)
		local L = (layout.large and state.Large) or state.Regular
		local base = layout.options.base
		local b = layout.bounds
		local fit = Cutout.FitZoom(layout, maxW, maxH)
		-- The pivot goes where the bounds put the chosen edges on the slot.
		local x = -(b[1] + halign * (b[3] - b[1])) * fit
		local y = -(b[2] + valign * (b[4] - b[2])) * fit
		L.frame:xy(x, y):zoom(fit)
		L.tilt:rotationz(layout.options.tiltDeg or 0)
		local zoom = base / L.em
		for _, text in ipairs({L.back, L.ink}) do
			text:settext(layout.text):zoom(zoom)
				:xy(-layout.width / 2, -PIVOT_Y * base)
		end
		state.shown = L.frame
		L.frame:visible(not state.held)
	end

	local function setText(text)
		state.text = text
		hideAll()
		local chars = select(2, text:gsub("[^\128-\191]", ""))
		local layout = chars <= maxChars and text ~= "" and Cutout.Layout(text, opts) or nil
		if layout then
			if not useLarge then layout.large = false end
			show(layout)
		elseif text ~= "" then
			state.plain:settext(text):visible(not state.held)
			state.shown = state.plain
		end
		state.ready = true
	end

	local frame = Def.ActorFrame{
		InitCommand=function(self)
			state.self = self
			if params.x then self:xy(params.x, params.y or 0) end
			-- onReady is called on the update after a string is set, as it
			-- was when strings took a few frames to render: callers set their
			-- own state after asking for a string.
			self:SetUpdateFunction(function(slot)
				if state.ready then
					state.ready = false
					if params.onReady then params.onReady(slot) end
				end
			end)
			if params.onInit then params.onInit(self) end
		end,
		CutoutHoldCommand=function(self, p)
			state.held = p and p.held == true
			if state.shown then state.shown:visible(not state.held) end
		end,
		CutoutSetCommand=function(self, p)
			local text = p and p.text or ""
			if text == state.text then
				-- Already shown: still report ready.
				state.ready = true
				return
			end
			setText(text)
		end,

		lettering("Regular", M.font or { back = "Common Normal", ink = "Common Normal" }, M.em or 56),
		LoadFont(params.fallbackFont or "Common Normal")..{
			InitCommand=function(self)
				state.plain = self
				self:align(halign, valign):visible(false)
				if params.fallbackZoom then self:zoom(params.fallbackZoom) end
				self:maxwidth(maxW / (params.fallbackZoom or 1))
			end,
		},
	}
	if useLarge then
		frame[#frame+1] = lettering("Large", M.fontLarge, M.emLarge)
	end
	return frame
end
