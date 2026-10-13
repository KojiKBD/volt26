-- VOLT26.Cutout.Styles: the geometry of the cutout slots whose strings are
-- known before their screen opens (profile names, pack names, the credit
-- line), in one place.
--
-- The screens build their slots from these entries, and the startup warm-up
-- (Scripts/VOLT26_CutoutCache.lua) pre-renders the same strings with the same
-- entries.  The cache is keyed by the string, the lettering options and the
-- drawn size, so a slot only finds a pre-rendered string when both sides use
-- exactly these numbers: change a slot's size here, not in its screen.
--
-- Design entries are in pixels of the screens' 1920x1080 artboards; Style()
-- answers them in theme units.  Scale "Fit" uses the music kit's scale
-- (min(w/1920, h/1080)); scale "Axes" scales widths by w/1920 and heights by
-- h/1080, as ScreenSelectProfile does.  Theme entries are already in theme
-- units.

VOLT26.Cutout = VOLT26.Cutout or {}
local Cutout = VOLT26.Cutout

Cutout.StyleDesign = {
	-- ScreenSelectProfile: the focused profile's name under each card
	-- (underlay/PlayerFrame.lua).
	ProfileName  = { Scale="Axes", MaxW=430, MaxH=120, Base=66, Tilt=-2, MaxChars=20 },
	-- ScreenVOLT26SelectPack: the focused pack's name (overlay/default.lua).
	PackName     = { Scale="Fit", MaxW=1600, MaxH=130, Base=70, Tilt=-2, MaxChars=64 },
	-- ScreenSelectMusic (overlay/SongWheel/P5.lua, P.CutoutSpecs): the open
	-- pack, the players' names on their cards and in the footer.
	SongPack     = { Scale="Fit", MaxW=340, MaxH=76, Base=44, Tilt=-4, MaxChars=40 },
	SongCardName = { Scale="Fit", MaxW=330, MaxH=54, Base=36, Tilt=-3, MaxChars=16 },
	SongFooterName = { Scale="Fit", MaxW=320, MaxH=52, Base=36, Tilt=-3, MaxChars=16 },
	-- The focused song's grade on the left of the wheel (overlay/SongWheel/
	-- Grade.lua).  Grades read in capitals, so every letter is upper case.
	-- White with one player; with two, each player's grade in their colour
	-- (P5.lua's P.Flag and P.Blue).
	SongGrade    = { Scale="Fit", MaxW=124, MaxH=92, Base=70, Tilt=-6, MaxChars=2,
		Opts={ upperChance=1 } },
	SongGradeP1  = { Scale="Fit", MaxW=124, MaxH=92, Base=70, Tilt=-6, MaxChars=2,
		Opts={ upperChance=1, fg=color("#fe0003") } },
	SongGradeP2  = { Scale="Fit", MaxW=124, MaxH=92, Base=70, Tilt=-6, MaxChars=2,
		Opts={ upperChance=1, fg=color("#00b1ff") } },
	-- ScreenEvaluationStage, the WANTED page (overlay/Wanted/Side.lua): the
	-- player's name on the top-left plate and the letter grade beside the
	-- judgment ladder.  Player 2's are the same, mirrored in place.
	EvalName     = { Scale="Fit", MaxW=360, MaxH=118, Base=62, Tilt=3, MaxChars=16 },
	EvalGrade    = { Scale="Fit", MaxW=250, MaxH=170, Base=120, Tilt=-10, MaxChars=2,
		Opts={ upperChance=1 } },
	-- ScreenSystemLayer: the credit line (theme units already).
	CreditPlayer = { Scale="Theme", MaxW=260, MaxH=44, Base=22, MaxChars=16 },
	CreditCentre = { Scale="Theme", MaxW=300, MaxH=50, Base=26, MaxChars=16 },
}

-- The letters of the lettered grades, drawn in cutout lettering (styles
-- SongGrade, SongGradeP1, SongGradeP2) and pre-rendered once at startup.  The
-- star grades (Tier00-04) are drawn with the grade star picture instead.
Cutout.GradeLetters = {
	Grade_Tier05 = "S+", Grade_Tier06 = "S", Grade_Tier07 = "S-",
	Grade_Tier08 = "A+", Grade_Tier09 = "A", Grade_Tier10 = "A-",
	Grade_Tier11 = "B+", Grade_Tier12 = "B", Grade_Tier13 = "B-",
	Grade_Tier14 = "C+", Grade_Tier15 = "C", Grade_Tier16 = "C-",
	Grade_Tier17 = "D", Grade_Tier99 = "Q", Grade_Failed = "F",
}

local function scales(kind)
	if kind == "Theme" then return 1, 1 end
	local sx, sy = SCREEN_WIDTH / 1920, SCREEN_HEIGHT / 1080
	if kind == "Axes" then return sx, sy end
	local s = math.min(sx, sy)
	return s, s
end

-- A style in theme units: {maxW, maxH, maxChars, opts={base, tiltDeg}}, the
-- fields CreateSlot takes.  Built on every call (SCREEN_* can change with a
-- theme reload); callers keep what they need.
function Cutout.Style(name)
	local d = Cutout.StyleDesign[name]
	if not d then return nil end
	local sx, sy = scales(d.Scale)
	local opts = { base = d.Base * sy }
	if d.Tilt then opts.tiltDeg = d.Tilt end
	if d.Opts then for k, v in pairs(d.Opts) do opts[k] = v end end
	return {
		maxW = d.MaxW * sx, maxH = d.MaxH * sy,
		maxChars = d.MaxChars or 16,
		opts = opts,
	}
end
