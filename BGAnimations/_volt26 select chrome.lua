-- Shared presentation for the screens a player walks through before Song
-- Select: ScreenSelectProfile and ScreenSelectPlayMode2.
--
-- The two screens ask different questions but wear the same frame -- a title
-- block with the step's name, a row of choices on the left, a detail panel on
-- the right that describes whatever the cursor is on, and a line of key hints
-- along the bottom.  Keeping that frame in one file is what makes the two
-- screens read as one sequence instead of two screens that happen to share a
-- palette.
--
-- This file owns appearance only.  It builds actors and returns them; it holds
-- no selection state, reads no profiles, and knows nothing about input.  The
-- screens own all of that.
--
-- Geometry is written in the theme's own 854x480 coordinate space, top-left
-- anchored, so a caller positions a box by the corner it can see.

local Chrome = {}

-- ----------------------------------------------------------------------------
-- Palette
--
-- The accent is the brand's, resolved through SL-Colors so that a screen never
-- hardcodes the red and Player 2 stays differentiated.

Chrome.Color = {
	Line      = color("#2e2727"),
	LineFaint = color("#201b1b"),
	Surface   = color("#141010"),
	Text      = color("#f1eded"),
	Dim       = color("#938787"),
	Faint     = color("#665c5c"),
}

Chrome.SurfaceAlpha = 0.82

function Chrome.Accent(player)
	if player then return PlayerColor(player) end
	return GetCurrentColor()
end

-- ----------------------------------------------------------------------------
-- Metrics shared by both screens

Chrome.Metrics = {
	Margin      = 20,
	HeaderTop   = 16,
	HeaderH     = 34,
	SectionY    = 62,
	BodyY       = 78,
	HintsY      = 452,
	RuleY       = 440,
}

function Chrome.Right()
	return _screen.w - Chrome.Metrics.Margin
end

-- ----------------------------------------------------------------------------
-- Text
--
-- Both helpers take the design's pixel size and hand off to VOLT26.Type, which
-- owns the mapping from a pixel size to a zoom for each face.

local function text(font, params)
	local t = LoadFont(font)..{
		Name = params.name,
		InitCommand=function(self)
			self:align(params.halign or 0, params.valign or 0)
				:xy(params.x or 0, params.y or 0)
				:diffuse(params.color or Chrome.Color.Text)
			if params.alpha then self:diffusealpha(params.alpha) end
		end,
	}
	return t
end

-- Small uppercase captions: the words that name a value rather than state one.
function Chrome.Label(params)
	local t = text(VOLT26.Type.Label, params)
	local previous = t.InitCommand
	t.InitCommand=function(self)
		previous(self)
		VOLT26.Type.SetLabel(self, (params.text or ""):upper(), params.px or 9, params.width)
	end
	return t
end

-- Names, numbers, anything the player actually reads for content.
function Chrome.Display(params)
	local t = text(VOLT26.Type.Display, params)
	local previous = t.InitCommand
	t.InitCommand=function(self)
		previous(self)
		VOLT26.Type.SetDisplay(self, params.text or "", params.px or 16, params.width)
		if params.wrap then
			self:_wrapwidthpixels(params.wrap / self:GetZoom()):vertspacing(params.vertspacing or 1)
		end
	end
	return t
end

-- ----------------------------------------------------------------------------
-- Boxes
--
-- A box is a one-pixel border with a dark fill inside it.  Every surface on
-- these screens is that, differing only in whether the border carries the
-- accent.  Children named "Border" and "Fill" so a screen can re-colour a box
-- when the cursor arrives on it without rebuilding it.

function Chrome.Box(params)
	local w, h = params.w, params.h
	local line = params.line or Chrome.Color.Line
	local fill = params.fill or Chrome.Color.Surface
	local alpha = params.fillalpha or Chrome.SurfaceAlpha

	local af = Def.ActorFrame{
		Name = params.name,
		InitCommand=function(self) self:xy(params.x or 0, params.y or 0) end,

		Def.Quad{
			Name="Border",
			InitCommand=function(self) self:align(0,0):zoomto(w, h):diffuse(line) end,
		},
		Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:align(0,0):xy(1,1):zoomto(w-2, h-2):diffuse(fill):diffusealpha(alpha)
			end,
		},
	}

	return af
end

-- Re-colour an existing box.  `focused` boxes take the accent on the border and
-- a wash of it inside, which is the only state distinction these screens make.
function Chrome.SetBoxFocus(box, focused, accent, duration)
	if not box then return end
	local border, fill = box:GetChild("Border"), box:GetChild("Fill")
	duration = duration or 0.08

	if border then
		border:stoptweening():linear(duration)
			:diffuse(focused and accent or Chrome.Color.Line)
	end
	if fill then
		fill:stoptweening():linear(duration)
			:diffuse(focused and accent or Chrome.Color.Surface)
			:diffusealpha(focused and 0.14 or Chrome.SurfaceAlpha)
	end
end

-- ----------------------------------------------------------------------------
-- Title block
--
-- The step's name, with the accent rule that marks it, and the sequence of
-- steps shown as tabs on the right so a player can see where in the run-up to
-- Song Select they are.  `active` is the tab's own name.

local function Tab(params)
	local accent = params.accent
	local active = params.active

	return Def.ActorFrame{
		Name = "Tab"..params.name,
		InitCommand=function(self)
			self:xy(params.x, params.y)

			local label = self:GetChild("Label")
			local width = label:GetZoomedWidth() + 20
			local height = 16

			-- The label is centred in the pill, and the pill is laid out from
			-- its right edge so that a row of tabs can be packed right-to-left
			-- without measuring twice.
			self:GetChild("Border"):zoomto(width, height)
			self:GetChild("Fill"):zoomto(width-2, height-2)
			label:xy(-width/2 + 10, 0)
		end,

		Def.Quad{
			Name="Border",
			InitCommand=function(self)
				self:align(1,0.5):diffuse(active and accent or Chrome.Color.Line)
			end,
		},
		Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:align(1,0.5):x(-1):diffuse(active and accent or Chrome.Color.Surface)
					:diffusealpha(active and 0.12 or Chrome.SurfaceAlpha)
			end,
		},
		Chrome.Label{
			name="Label", text=params.name, px=9,
			halign=1, valign=0.5,
			color=active and accent or Chrome.Color.Dim,
		},
	}
end

-- `params.title` names this screen; `params.tabs` is the ordered list of step
-- names; `params.active` is the one this screen is.
function Chrome.TitleBlock(params)
	local m = Chrome.Metrics
	local accent = params.accent or Chrome.Accent()

	local af = Def.ActorFrame{
		Name="TitleBlock",
		OnCommand=function(self) self:diffusealpha(0):linear(0.15):diffusealpha(1) end,
		OffCommand=function(self) self:linear(0.12):diffusealpha(0) end,

		-- the accent rule
		Def.Quad{
			InitCommand=function(self)
				self:align(0,0):xy(m.Margin, m.HeaderTop+2):zoomto(3, 26):diffuse(accent)
			end,
		},
		Chrome.Label{ text="Select", px=9, x=m.Margin+10, y=m.HeaderTop, color=Chrome.Color.Dim },
		Chrome.Display{
			text=(params.title or ""):upper(), px=26,
			x=m.Margin+9, y=m.HeaderTop+12, width=420,
		},
	}

	-- Tabs are packed from the right edge inwards, each one measuring itself.
	local x = Chrome.Right()
	for i = #params.tabs, 1, -1 do
		local name = params.tabs[i]
		af[#af+1] = Tab{
			name=name, x=x, y=m.HeaderTop+13,
			accent=accent, active=(name == params.active),
		}
		-- Pill widths are text-derived, so the next slot is stepped by a
		-- generous constant rather than a measurement that is not available
		-- until the child has initialised.
		x = x - (#name * 5.5 + 28)
	end

	return af
end

-- ----------------------------------------------------------------------------
-- Section caption above the choices, e.g. "WHO IS PLAYING"

function Chrome.SectionLabel(caption)
	return Chrome.Label{
		text=caption, px=9,
		x=Chrome.Metrics.Margin, y=Chrome.Metrics.SectionY,
		color=Chrome.Color.Dim,
	}
end

-- ----------------------------------------------------------------------------
-- Key hints
--
-- The bottom line: what START does on the left, the cabinet's mode in the
-- middle, and who is playing on the right.  The leading word is accented
-- because it names a button.

function Chrome.Hints(params)
	local m = Chrome.Metrics
	local accent = params.accent or Chrome.Accent()

	local af = Def.ActorFrame{
		Name="Hints",
		OnCommand=function(self) self:diffusealpha(0):sleep(0.1):linear(0.15):diffusealpha(1) end,
		OffCommand=function(self) self:linear(0.12):diffusealpha(0) end,

		Def.Quad{
			InitCommand=function(self)
				self:align(0,0):xy(m.Margin, m.RuleY):zoomto(_screen.w - m.Margin*2, 1)
					:diffuse(Chrome.Color.LineFaint)
			end,
		},
		Chrome.Label{ name="Button", text=params.button or "Start", px=9, x=m.Margin, y=m.HintsY, color=accent },
		Chrome.Label{ name="Action", text=params.action or "", px=9, x=m.Margin+38, y=m.HintsY, color=Chrome.Color.Dim },
	}

	if params.center then
		af[#af+1] = Chrome.Label{
			name="Center", text=params.center, px=9,
			x=_screen.cx, y=m.HintsY, halign=0.5, color=Chrome.Color.Faint,
		}
	end

	if params.right then
		af[#af+1] = Chrome.Label{
			name="Right", text=params.right, px=9,
			x=Chrome.Right()-10, y=m.HintsY, halign=1, color=Chrome.Color.Dim,
		}
		af[#af+1] = Def.Quad{
			InitCommand=function(self)
				self:xy(Chrome.Right()-3, m.HintsY+5):zoomto(5,5):rotationz(45):diffuse(accent)
			end,
		}
	end

	return af
end

-- ----------------------------------------------------------------------------
-- Detail panel furniture
--
-- A stat tile states one value and names it underneath: the shape the panels on
-- both screens are built from.

function Chrome.Tile(params)
	local af = Chrome.Box{ name=params.name, x=params.x, y=params.y, w=params.w, h=params.h }

	af[#af+1] = Chrome.Display{
		name="Value", text=params.value or "", px=params.px or 14,
		x=9, y=(params.h/2) - 11, width=params.w-18,
	}
	af[#af+1] = Chrome.Label{
		name="Caption", text=params.caption or "", px=9,
		x=9, y=(params.h/2) + 2, width=params.w-18, color=Chrome.Color.Faint,
	}

	return af
end

-- Set a tile that has already been built.  `width` caps both lines, so a tile
-- in a narrow panel truncates its value instead of spilling out of its border.
function Chrome.SetTile(tile, value, caption, width)
	if not tile then return end
	local valueActor = tile:GetChild("Value")
	if valueActor and value ~= nil then
		VOLT26.Type.SetDisplay(valueActor, tostring(value):upper(), 14, width)
	end
	local captionActor = tile:GetChild("Caption")
	if captionActor and caption ~= nil then
		VOLT26.Type.SetLabel(captionActor, tostring(caption):upper(), 9, width)
	end
end

-- A meter: a caption, a value on the right, and a bar underneath it.
function Chrome.Meter(params)
	local width = params.w

	return Def.ActorFrame{
		Name=params.name,
		InitCommand=function(self) self:xy(params.x, params.y) end,

		Chrome.Label{ name="Caption", text=params.caption or "", px=9, color=Chrome.Color.Dim },
		Chrome.Display{ name="Value", text=params.value or "", px=18, x=width, y=-6, halign=1 },

		Def.Quad{
			InitCommand=function(self)
				self:align(0,0):y(18):zoomto(width, 3):diffuse(Chrome.Color.Line)
			end,
		},
		Def.Quad{
			Name="Fill",
			InitCommand=function(self)
				self:align(0,0):y(18):zoomto(width * clamp(params.fraction or 0, 0, 1), 3)
					:diffuse(params.accent or Chrome.Accent())
			end,
		},
	}
end

return Chrome
