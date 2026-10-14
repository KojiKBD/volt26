-- Name entry, in the dress of the session summary ("gameover" artboard; the
-- shared pieces are in "_volt26 gameover kit.lua").  Each player's half
-- shows, on the left (player 2: on the right), a score card that walks
-- through the stages they played, and beside it the entry: the name on the
-- card's bands, the alphabet on a score plate and the machine's best scores
-- on the stage the card shows.  A player who cannot enter a name (no record
-- this session) sees "out of ranking" in place of the alphabet.
--
-- The behaviour is Simply Love's: InputHandler.lua, the sick_wheel alphabet,
-- SL[pn].HighScores and GAMESTATE:StoreRankingName.
local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))
local K, P = G.K, G.P
local players = G.Players()
local solo = #players == 1

local DURATION_PER_STAGE = 4
local CHAR_W = 74
local HIGH_SCORES = 5

-- The zoom of the Bold face for a cap height in artboard pixels.
local function BOLD(cap) return cap / 0.72 / 48 end

local PossibleCharacters = {
	"&BACK;", "&OK;",
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "?", "!"
}
local GLYPH = { ["&BACK;"] = "DEL", ["&OK;"] = "OK" }

local AlphabetWheels = {}
for player in ivalues(players) do
	local pn = ToEnumShortString(player)
	if SL[pn].HighScores.EnteringName then
		AlphabetWheels[pn] = setmetatable({}, sick_wheel_mt)
	end
end

-- A letter of the alphabet: white on the plate, black in a white box when
-- it has the focus.
local alphabet_character_mt = {
	__index = {
		create_actors = function(self, name)
			self.name = name
			return Def.ActorFrame{
				Name = name,
				InitCommand = function(subself) self.container = subself end,
				HideCommand = function(subself) subself:linear(0.25):diffusealpha(0) end,
				Def.Quad{
					InitCommand = function(subself)
						self.box = subself
						subself:zoomto(CHAR_W - 10, 70):diffuse(G.White):visible(false)
					end,
				},
				LoadFont(G.Font.Bold)..{
					InitCommand = function(subself)
						self.bmt = subself
						subself:zoom(BOLD(40)):diffuse(G.White)
					end,
				},
			}
		end,
		transform = function(self, item_index, num_items, has_focus)
			self.container:finishtweening()
			local edge = item_index <= 0 or item_index >= num_items - 1
			self.container:linear(0.075):diffusealpha(edge and 0 or 1)
				-- The focused letter (the middle one shown) on the plate's centre.
				:x(CHAR_W * (item_index - (num_items - 1) / 2))
			self.box:visible(has_focus)
			self.bmt:diffuse(has_focus and G.Black or G.White)
		end,
		set = function(self, character)
			if not character then return end
			self.bmt:settext(GLYPH[character] or character)
			local w = self.bmt:GetZoomedWidth()
			if w > CHAR_W - 16 then self.bmt:zoomx(self.bmt:GetZoomY() * (CHAR_W - 16) / w) end
		end,
	}
}

-- The machine's best scores on a stage's chart.
local function highScores(player, stage)
	local snapshot = VOLT26.Evaluation.GetPlayerStageSnapshot(player, stage)
	local context = VOLT26.Evaluation.GetStageContext(stage)
	local item = context and (context.item or context.song)
	local steps = snapshot and snapshot.steps
	if not item or not steps then return {} end
	local ok, list = pcall(function()
		return PROFILEMAN:GetMachineProfile():GetHighScoreList(item, steps):GetHighScores()
	end)
	return ok and list or {}
end

-- One player's half.
local function half(player, delay)
	local pn = ToEnumShortString(player)
	local a = G.Anchor(player, solo)
	local m = a.M
	local entering = SL[pn].HighScores.EnteringName
	local stages = G.PlayerStages(player)

	-- The name the entry starts from (Simply Love's PlayerNameAndDecorations).
	if entering then SL[pn].HighScores.Name = "" end
	if PROFILEMAN:IsPersistentProfile(player) then
		SL[pn].HighScores.Name = PROFILEMAN:GetProfile(player):GetLastUsedHighScoreName()
	end

	-- Places of the entry, on player 1's artboard (the card is at its own
	-- place, see the kit).
	local BANDS = { X = 1250, Y = 150, Zoom = 1.3 }
	local PLATE = { X = 1250, Y = 362, Zoom = 1.7 }
	local LIST = { X = 1630, Y = 112, Gap = 52, W = 270 }
	local bands = G.Art.Pieces.Bands
	local bandTop = BANDS.Y - bands.H * BANDS.Zoom / 2

	local function at(x, y) return G.At(x, y, m) end
	local bx, by = at(BANDS.X, BANDS.Y)
	local px, py = at(PLATE.X, PLATE.Y)
	local labelX = at(BANDS.X - bands.W * BANDS.Zoom / 2 + 30, 0)
	local nameX = labelX

	local af = Def.ActorFrame{
		Name = "Half" .. pn,
		InitCommand = function(self) self:xy(a.X, a.Y) end,
		OnCommand = function(self)
			G.Arrive(self, m, delay)
			self:queuecommand("NextStage")
		end,
		NextStageCommand = function(self)
			-- No stage of this player in the session: no card, no list.
			if #stages == 0 then
				self:GetChild("Card"):visible(false)
				return
			end
			self.index = (self.index or 0) % #stages + 1
			local stage = stages[self.index]
			G.FillCard(self:GetChild("Card"), player, stage)
			self:GetChild("List"):playcommand("Fill", { Scores = highScores(player, stage) })
			if #stages > 1 then self:sleep(DURATION_PER_STAGE):queuecommand("NextStage") end
		end,
		OffCommand = function(self) G.Leave(self, m) end,
	}
	af[#af+1] = G.Card("Card", m)

	-- The name: the label on the black band, the name on the white one.
	local entry = Def.ActorFrame{
		Name = "PlayerNameAndDecorations_" .. pn,
		Def.Sprite{
			Texture = THEME:GetPathG("", "VOLT26/GameOver/bands.png"),
			InitCommand = function(self) self:xy(bx, by):zoom(BANDS.Zoom):zoomx(BANDS.Zoom * m) end,
		},
		P.Text{ Name = "Label", Cap = 30, X = nameX, Baseline = select(2, at(0, bandTop + 58)),
			Align = m < 0 and 1 or 0, Tint = G.White, Text = ScreenString("EnterName"):upper() },
		LoadFont(G.Font.Bold)..{
			Name = "PlayerName",
			InitCommand = function(self)
				self:halign(m < 0 and 1 or 0):valign(0.5):xy(nameX, select(2, at(0, bandTop + 118)))
					:zoom(BOLD(52)):diffuse(G.Black)
			end,
			OnCommand = function(self) self:playcommand("Set") end,
			SetCommand = function(self)
				local name = SL[pn].HighScores.Name or ""
				self:settext(name ~= "" and name or (entering and "----" or ""))
			end,
		},
		-- The alphabet's plate (InputHandler hides the "Cursor" when done).
		Def.ActorFrame{
			Name = "Cursor",
			InitCommand = function(self) self:xy(px, py):zoom(PLATE.Zoom) end,
			HideCommand = function(self) self:linear(0.25):diffusealpha(0) end,
			Def.Sprite{
				Texture = THEME:GetPathG("", "VOLT26/GameOver/score_plate.png"),
				InitCommand = function(self) self:zoomx(m) end,
			},
		},
		LoadFont(G.Font.Bold)..{
			Name = "OutOfRanking",
			Text = ScreenString("OutOfRanking"):upper(),
			InitCommand = function(self)
				self:xy(px, py + 10):zoom(BOLD(34)):diffuse(G.Pink):visible(not entering)
					:maxwidth(560 / BOLD(34))
			end,
		},
	}
	af[#af+1] = entry

	-- The machine's best scores on the stage the card shows.
	local list = Def.ActorFrame{
		Name = "List",
		FillCommand = function(self, p)
			for i = 1, HIGH_SCORES do
				local line = self:GetChild("Line" .. i)
				local hs = p.Scores and p.Scores[i]
				line:visible(hs ~= nil)
				if hs then
					local name = hs:GetName()
					if name == "" then name = "----" end
					G.SetLine(line, name, ("  %.2f"):format(hs:GetPercentDP() * 100))
				end
			end
		end,
	}
	for i = 1, HIGH_SCORES do
		-- Player 2's list is on the far left (its start mirrors the end of
		-- player 1's).
		local lx, ly = at(LIST.X + (m < 0 and LIST.W or 0), LIST.Y + (i - 1) * LIST.Gap)
		local line = G.Run("Line" .. i, {
			{ "Tag", 16, i == 1 and G.Cyan or G.White, i .. ". " },
			{ "Value", 24, G.White, "" },
			{ "Tail", 22, G.Pink, "" },
		}, "Bold")
		local init = line.InitCommand
		line.InitCommand = function(self) init(self); self:xy(lx, ly):rotationz(-3 * m):visible(false) end
		list[#list+1] = line
	end
	af[#af+1] = list

	if entering then
		af[#af+1] = AlphabetWheels[pn]:create_actors("AlphabetWheel_" .. pn, 9, alphabet_character_mt, px, py + 6)
	end
	return af, pn
end

local root = Def.ActorFrame{
	InitCommand = function(self)
		self:xy(K.Left, K.Top):zoom(K.Scale)
		self:queuecommand("CaptureInput")
	end,
	CaptureInputCommand = function(self)
		for player in ivalues(players) do
			local pn = ToEnumShortString(player)
			if AlphabetWheels[pn] then
				local profile = PROFILEMAN:GetProfile(player)
				-- With a high score name already, start on OK; else on A.
				local start = (profile and profile:GetLastUsedHighScoreName() ~= "" and 2) or 3
				AlphabetWheels[pn]:set_info_set(PossibleCharacters, start)
			end
		end
		SCREENMAN:GetTopScreen():AddInputCallback(LoadActor(THEME:GetPathB("ScreenNameEntryTraditional", "underlay/InputHandler.lua"), { self, AlphabetWheels, players }))
	end,
	AttemptToFinishCommand = function(self)
		if not SL.P1.HighScores.EnteringName and not SL.P2.HighScores.EnteringName then
			self:playcommand("Finish")
		end
	end,
	MenuTimerExpiredCommand = function(self)
		for player in ivalues(players) do
			local pn = ToEnumShortString(player)
			if SL[pn].HighScores.EnteringName then
				local entry = self:GetChild("Half" .. pn):GetChild("PlayerNameAndDecorations_" .. pn)
				entry:GetChild("Cursor"):queuecommand("Hide")
				self:GetChild("Half" .. pn):GetChild("AlphabetWheel_" .. pn):queuecommand("Hide")
				self:GetChild("enter"):playforplayer(player)
			end
		end
		self:playcommand("Finish")
	end,
	FinishCommand = function(self)
		for player in ivalues(players) do
			local pn = ToEnumShortString(player)
			GAMESTATE:StoreRankingName(player, SL[pn].HighScores.Name)
			if PROFILEMAN:IsPersistentProfile(player) then
				PROFILEMAN:GetProfile(player):SetLastUsedHighScoreName(SL[pn].HighScores.Name)
			end
		end
		SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
	end,
}

for i, player in ipairs(players) do root[#root+1] = (half(player, 0.1 + (i - 1) * 0.08)) end

-- The title, on the band between the halves (above the half with one player).
root[#root+1] = G.Title(ScreenString("HeaderText"), solo)

root[#root+1] = LoadActor(THEME:GetPathS("", "_change value"))..{ Name = "delete", IsAction = true, SupportPan = true }
root[#root+1] = LoadActor(THEME:GetPathS("Common", "start"))..{ Name = "enter", IsAction = true, SupportPan = true }
root[#root+1] = LoadActor(THEME:GetPathS("MusicWheel", "change"))..{ Name = "move", IsAction = true, SupportPan = true }
root[#root+1] = LoadActor(THEME:GetPathS("common", "invalid"))..{ Name = "invalid", IsAction = true, SupportPan = true }

return root
