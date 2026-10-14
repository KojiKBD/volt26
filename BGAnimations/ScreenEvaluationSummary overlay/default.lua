-- The session summary, after the owner's "gameover" artboard: every stage a
-- player played this session as a score card (the player's name in cutout
-- lettering, the song, its meter, the jacket, the grade, ITG and EX), in a
-- row that runs sideways.  Player 1's row fills the upper half, player 2's
-- the lower half mirrored (its next cards are on the left); a lone player's
-- row sits in the middle.  The shared pieces are in "_volt26 gameover kit.lua".
--
-- The focused card is whole, the next ones are seen faintly beside it.  Each
-- row moves on by itself every AUTO seconds; a player's left/right (and
-- up/down) steps through their own row, which then waits PAUSE seconds before
-- moving on again.
local G = LoadActor(THEME:GetPathB("", "_volt26 gameover kit.lua"))
local players = G.Players()
local solo = #players == 1

local AUTO = 4      -- seconds per card while nobody scrolls
local PAUSE = 8     -- seconds a row rests after its player scrolled it
local SLOTS = 4     -- cards per row: the one before, the focused one, two after
local MOVE = 0.34   -- seconds a step takes

-- Input: screen directions.  Player 2's row is mirrored, so for that player
-- left and right swap (the next card is on the left).
local STEP = {
	MenuLeft = -1, Left = -1, DownLeft = -1, MenuUp = -1, Up = -1,
	MenuRight = 1, Right = 1, DownRight = 1, MenuDown = 1, Down = 1,
}
local SIDEWAYS = { MenuLeft = true, Left = true, DownLeft = true, MenuRight = true, Right = true, DownRight = true }
if PREFSMAN:GetPreference("OnlyDedicatedMenuButtons") then
	for _, name in ipairs({ "Left", "Right", "Up", "Down", "DownLeft", "DownRight" }) do STEP[name] = nil end
end

-- Draw orders among the root's children: the faded cards under the halves'
-- art (as in the artboard), the focused cards over it.
local UNDER, ART, OVER = 10, 15, 20

-- A player's row: SLOTS cards, children of the root itself (so the art can
-- go between them), placed from the player's anchor.
local function row(player, delay, root)
	local pn = ToEnumShortString(player)
	local a = G.Anchor(player, solo)
	local m = a.M
	local stages = G.PlayerStages(player)
	local n = #stages
	local focus = 1
	local slots = {}

	local function wrap(i) return n > 0 and ((i - 1) % n) + 1 or 1 end
	local function shown(o) return n > 0 and (o == 0 or (o > 0 and o < n) or (o < 0 and n > 1)) end
	local function xAt(o) return a.X + o * G.Step * m end
	local function alphaAt(o) return o == 0 and 1 or (o > 0 and G.Art.Card.NeighbourAlpha or 0) end

	-- Puts a card at its offset from the focused one; `jump` places it there
	-- at once (a card coming round from the other end).
	local function place(s, jump)
		local card = s.actor
		local stage = stages[wrap(focus + s.o)]
		if s.stage ~= stage then
			s.stage = stage
			G.FillCard(card, player, stage)
		end
		card:visible(shown(s.o))
		card:draworder(s.o == 0 and OVER or UNDER - s.o)
		if jump then card:stoptweening():x(xAt(s.o)):diffusealpha(0) end
		card:stoptweening():decelerate(MOVE):x(xAt(s.o)):diffusealpha(alphaAt(s.o))
	end

	local function move(d)
		if n < 2 then return end
		focus = wrap(focus + d)
		for _, s in ipairs(slots) do
			s.o = s.o - d
			local jump = false
			if s.o < -1 then s.o, jump = s.o + SLOTS, true
			elseif s.o > SLOTS - 2 then s.o, jump = s.o - SLOTS, true end
			place(s, jump)
		end
		root:SortByDrawOrder()
	end

	-- The row's clock and input live on an empty frame of its own.
	local af = Def.ActorFrame{
		Name = "Row" .. pn,
		OnCommand = function(self)
			root = self:GetParent()
			for k = 1, SLOTS do
				local card = root:GetChild("Card" .. pn .. k)
				slots[k] = { actor = card, o = k - 2 }
				card:y(a.Y)
				place(slots[k], false)
				card:finishtweening()
				-- Arrive: slide in from the player's side to the card's place.
				local x, alpha = card:GetX(), card:GetDiffuseAlpha()
				card:x(x - 700 * m):diffusealpha(0):sleep(delay)
					:decelerate(0.32):x(x + 14 * m):diffusealpha(alpha):decelerate(0.08):x(x)
			end
			root:SortByDrawOrder()
			local wait, elapsed = AUTO + 1, 0
			self.rest = function() wait, elapsed = PAUSE, 0 end
			self:SetUpdateFunction(function(_, dt)
				elapsed = elapsed + (dt or 0)
				if elapsed >= wait then
					elapsed, wait = 0, AUTO
					move(1)
				end
			end)
		end,
		MoveCommand = function(self, p)
			self.rest()
			move(p.Dir)
		end,
		OffCommand = function(self)
			self:SetUpdateFunction(nil)
			for _, s in ipairs(slots) do G.Leave(s.actor, m) end
		end,
	}
	local cards = {}
	for k = 1, SLOTS do cards[k] = G.Card("Card" .. pn .. k, m) end
	return af, cards
end

local t = G.Root{
	Name = "VOLT26Summary",
	CodeMessageCommand = function(self, param)
		-- Screenshots go where Simply Love put them.
		if param.Name == "Screenshot" then
			local month = ("%02d-%s"):format(MonthOfYear() + 1, THEME:GetString("Months", "Month" .. MonthOfYear() + 1))
			SaveScreenshot(param.PlayerNumber, false, false, "Simply_Love/" .. Year() .. "/" .. month .. "/")
			return
		end
		local d = STEP[param.Name]
		if not d or not param.PlayerNumber then return end
		if SIDEWAYS[param.Name] and param.PlayerNumber == PLAYER_2 then d = -d end
		local r = self:GetChild("Row" .. ToEnumShortString(param.PlayerNumber))
		if r then r:playcommand("Move", { Dir = d }) end
	end,
}
for i, player in ipairs(players) do
	local af, cards = row(player, 0.1 + (i - 1) * 0.08)
	t[#t+1] = af
	for _, card in ipairs(cards) do t[#t+1] = card end
end
for _, layer in ipairs(G.Layers(ART)) do t[#t+1] = layer end

return t
