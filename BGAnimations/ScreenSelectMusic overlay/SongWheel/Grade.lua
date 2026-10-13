-- The focused song's grade, on the left of the song wheel beside the focused
-- row, where the mockup has four decorative stars (no longer drawn, see
-- Scene.lua).
--
-- It is the player's best grade on the chart they have selected
-- (VOLT26.ScoreIndex through S.Best):
--   * a lettered grade (S+ .. D, Q, F) in cutout lettering in the middle of
--     the cluster.  The letters are drawn once at startup and kept for the
--     whole session (VOLT26.Cutout.Cache; styles SongGrade, SongGradeP1,
--     SongGradeP2 in Scripts/VOLT26_CutoutStyles.lua), so a grade never waits
--     to render;
--   * a star grade (one to five stars) as the grade star picture, laid out
--     as the evaluation screen lays it out (Graphics/_grades/Grade_Tier00-04:
--     one large star, two on a diagonal, three in a triangle, four in the
--     corners, five in a circle).  They pop in turning and then turn with
--     the song's tempo, as the mockup's decorative stars did; five stars are
--     holographic foil: a rainbow that runs from star to star and a
--     travelling glint.
--
-- One player: the grade is white.  Two players: each player's grade is in
-- their colour (red P1, blue P2), and the two take turns -- every FLIP_EVERY
-- seconds the grade turns over like a card.  A player with no grade on their
-- chart is left out (a single grade does not turn); with no grade at all the
-- place stays empty.
local p = ...
local K, S = p.K, p.S
local P = LoadActor(THEME:GetPathB("ScreenSelectMusic", "overlay/SongWheel/P5.lua"))
local idle = true

local LETTER = { X = 200, Y = 226 }  -- the middle of the cluster
local FLIP_EVERY = 2.5               -- seconds each player's grade shows
local FLIP_HALF = 0.08               -- seconds for half a turn

-- The star grades' layouts, copied from the evaluation screen's grade actors
-- (Graphics/_grades/Grade_Tier04 .. Grade_Tier00): for each number of stars,
-- every star's {x, y, zoom} in those actors' own units (the 200 px grade
-- picture).  STAR_SCALE turns them into design pixels; every layout spans
-- about 190 units, so 0.9 fills the place of the mockup's star cluster.
local STAR_SCALE = 0.9
local LAYOUTS = {
	[1] = { { 0, 0, 0.8 } },
	[2] = { { -39, 40, 0.6 }, { 39, -40, 0.6 } },
	[3] = { { -45, 40, 0.5 }, { 0, -40, 0.5 }, { 45, 40, 0.5 } },
	[4] = { { -46, -46, 0.5 }, { 46, -46, 0.5 }, { -46, 46, 0.5 }, { 46, 46, 0.5 } },
	-- The circle: top, upper left, upper right, lower left, lower right.
	[5] = { { 0, -54, 0.35 }, { -52, -16, 0.35 }, { 52, -16, 0.35 }, { -32, 50, 0.35 }, { 32, 50, 0.35 } },
}

-- Each star turns its own way round and a little faster or slower, one turn
-- every TURN_BEATS beats of the song's BPM at the music rate.
local TURN_BEATS = 8
local DEFAULT_BPM = 120
local SPIN = { 1, -0.8, 1.25, -0.9, 1.1 }
-- Five stars, holographic foil: the colours cycle every FOIL_PERIOD seconds
-- and each star runs FOIL_STEP of a cycle behind the one before, so the
-- rainbow travels across them, and a white glint sweeps from star to star.
local FOIL_PERIOD = 2.4
local FOIL_STEP = 0.14
local GLINT_PERIOD = 1.6

local LETTERS = { White = "Letter", [PLAYER_1] = "LetterP1", [PLAYER_2] = "LetterP2" }

local function songBpm()
	local song = GAMESTATE:GetCurrentSong()
	if not song or GAMESTATE:IsCourseMode() then return DEFAULT_BPM end
	local ok, bpm = pcall(function()
		if song:IsDisplayBpmRandom() then return nil end
		local bpms = song:GetDisplayBpms()
		return math.max(tonumber(bpms[1]) or 0, tonumber(bpms[2]) or 0)
	end)
	bpm = ok and tonumber(bpm) or nil
	if not bpm or bpm <= 0 then bpm = DEFAULT_BPM end
	return bpm * VOLT26.MusicSelection.GetMusicRate()
end

-- What a player's grade on the chart looks like, or nil without one.
local function gradeOf(player, item)
	local best = S.Best(player, item, S.Chart(player))
	local grade = best and best.Grade
	if not grade then return nil end
	local letter = VOLT26.Cutout.GradeLetters[grade]
	local _, stars = P.Grade(grade)
	if not letter and stars == 0 then return nil end
	return { player = player, grade = grade, letter = letter, stars = stars }
end

-- The slot a grade's letter is drawn in.
local function letterSlot(g, versus)
	return versus and LETTERS[g.player] or LETTERS.White
end

-- Puts one player's grade on the face.
local function show(face, g, versus)
	local slot = g.letter and letterSlot(g, versus) or nil
	for _, name in pairs(LETTERS) do face:GetChild(name):visible(name == slot) end

	local tint = versus and P.PlayerColor(g.player) or P.White
	local lit = g.stars == 5
	local rate = songBpm() / 60 / TURN_BEATS * 360
	for i = 1, 5 do
		local star = face:GetChild("Star" .. i)
		local shown = not g.letter and i <= g.stars
		star:visible(shown)
		if shown then
			local ink, glint = star:GetChild("Ink"), star:GetChild("Glint")
			local at = LAYOUTS[g.stars][i]
			star:xy(at[1] * STAR_SCALE, at[2] * STAR_SCALE)
			ink:zoom(at[3] * STAR_SCALE)
			glint:zoom(at[3] * STAR_SCALE)
			if lit then
				-- The rainbow replaces the colour (white or the player's); the
				-- black of the picture stays black, like foil under ink.
				local phase = (i - 1) * FOIL_STEP * FOIL_PERIOD
				ink:diffuse(P.White):rainbow():effectperiod(FOIL_PERIOD):effectoffset(phase)
				glint:visible(true):diffuseshift():effectperiod(GLINT_PERIOD)
					:effectoffset((i - 1) * GLINT_PERIOD / 5)
					:effectcolor1(1, 1, 1, 0):effectcolor2(1, 1, 1, 0.6)
			else
				ink:stopeffect():diffuse(tint)
				glint:stopeffect():visible(false)
			end
			-- Pop in turning, then turn with the song.
			star:finishtweening():stopeffect():zoom(0):rotationz(-160):sleep((i - 1) * 0.04)
				:decelerate(0.14):zoom(1.25):rotationz(10):decelerate(0.07):zoom(1):rotationz(0)
			if idle then star:spin():effectmagnitude(0, 0, rate * SPIN[i]) end
		end
	end
end

-- The face turns over between the players; the frame around it (at the
-- middle of the cluster) takes the kicks, so a kick never cuts a turn short.
local face = Def.ActorFrame{
	Name = "Face",
	-- Half a turn, then the other player's grade, then the other half.
	FlipCommand = function(self)
		self:linear(FLIP_HALF):zoomx(0):queuecommand("Turn")
	end,
	TurnCommand = function(self)
		local grade = self:GetParent()
		local shown = grade.shown
		if #shown < 2 then self:zoomx(1); return end
		grade.turn = grade.turn % #shown + 1
		show(self, shown[grade.turn], true)
		self:linear(FLIP_HALF):zoomx(1):sleep(FLIP_EVERY):queuecommand("Flip")
	end,
}
-- Five stars at most; show() places and sizes them for the grade.
for i = 1, 5 do
	face[#face+1] = Def.ActorFrame{
		Name = "Star" .. i,
		InitCommand = function(self) self:visible(false) end,
		Def.Sprite{ Name = "Ink", Texture = P.GradeStarPath },
		-- Five stars' glint: the star once more, added on in white.
		Def.Sprite{ Name = "Glint", Texture = P.GradeStarPath,
			InitCommand = function(self) self:blend("BlendMode_Add"):visible(false) end },
	}
end
face[#face+1] = P.CutoutSlot{ Name = LETTERS.White, Id = "Grade", X = 0, Y = 0, Scale = K.Scale }
face[#face+1] = P.CutoutSlot{ Name = LETTERS[PLAYER_1], Id = "GradeP1", X = 0, Y = 0, Scale = K.Scale }
face[#face+1] = P.CutoutSlot{ Name = LETTERS[PLAYER_2], Id = "GradeP2", X = 0, Y = 0, Scale = K.Scale }

return Def.ActorFrame{
	Name = "Grade",
	InitCommand = function(self)
		self:xy(LETTER.X, LETTER.Y):visible(false)
		self.shown, self.turn = {}, 1
	end,
	RefreshCommand = function(self)
		local item = S.Item()
		local face = self:GetChild("Face")
		local players = GAMESTATE:GetHumanPlayers()
		local versus = #players > 1
		local shown = {}
		for _, player in ipairs(players) do
			local g = item and gradeOf(player, item) or nil
			if g then
				shown[#shown+1] = g
				if g.letter then P.SetCutout(face:GetChild(letterSlot(g, versus)), g.letter) end
			end
		end

		local key = { tostring(versus) }
		for _, g in ipairs(shown) do key[#key+1] = tostring(g.player) .. g.grade end
		key = table.concat(key, "|")
		local newSong = item ~= self.item
		self.item = item
		if key == self.key then
			-- The same grades: a new song still gets a kick, and the stars
			-- take up its tempo.
			if newSong and #shown > 0 then
				self:finishtweening():zoom(1.15):decelerate(0.12):zoom(1)
				if #shown == 1 then show(face, shown[1], versus) end
			end
			return
		end
		self.key, self.shown, self.turn = key, shown, 1

		face:stoptweening():zoomx(1)
		self:finishtweening():zoom(1)
		self:visible(#shown > 0)
		if #shown == 0 then return end
		show(face, shown[1], versus)
		if #shown > 1 then face:sleep(FLIP_EVERY):queuecommand("Flip") end
	end,
	face,
}
