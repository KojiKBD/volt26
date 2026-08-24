local SCREEN_NAME = "ScreenMementosDash"
local is_volt26 = ThemePrefs.Get("VisualStyle") == "VOLT26"

local function S(key)
	return THEME:GetString(SCREEN_NAME, key)
end

local lane_spacing = math.min(_screen.w * 0.22, 165)
local lane_x = { _screen.cx - lane_spacing, _screen.cx, _screen.cx + lane_spacing }
local spawn_y = 58
local player_y = _screen.h - 82
local despawn_y = _screen.h + 75
local obstacle_pool_size = 12
local treasure_pool_size = 6
local effect_pool_size = 6

local state = {
	mode = "countdown",
	lane = 2,
	elapsed = 0,
	score = 0,
	treasures = 0,
	alert = 0,
	invulnerable = 0,
	countdown = 3.5,
	spawn_timer = 0,
	high_score = tonumber(ThemePrefs.Get("VOLT26MementosDashHighScore")) or 0,
	new_record = false,
	exiting = false,
	music_elapsed = 0,
	music_length = 0,
}

local root
local player_actor
local music_actor
local obstacles = {}
local treasures = {}
local effects = {}

local function deactivate(item)
	item.active = false
	item.collided = false
	if item.actor then
		item.actor:stoptweening():visible(false)
	end
end

local function clear_pools()
	for _, item in ipairs(obstacles) do deactivate(item) end
	for _, item in ipairs(treasures) do deactivate(item) end
	for _, effect in ipairs(effects) do
		effect.active = false
		if effect.actor then effect.actor:stoptweening():visible(false) end
	end
end

local function play_once(path)
	if path and FILEMAN:DoesFileExist(path) then SOUND:PlayOnce(path) end
end

local function trigger_effect(x, y, tint)
	for _, effect in ipairs(effects) do
		if not effect.active and effect.actor then
			effect.active = true
			effect.actor:stoptweening():visible(true):xy(x, y):diffuse(tint)
				:zoom(0.35):diffusealpha(1):rotationz(math.random(-25, 25))
				:decelerate(0.20):zoom(1.25):diffusealpha(0)
				:queuecommand("Deactivate")
			return
		end
	end
end

local function update_score()
	state.score = math.floor(state.elapsed * 10) + state.treasures * 100
	MESSAGEMAN:Broadcast("MementosDashScore", {
		score = state.score,
		best = math.max(state.high_score, state.score),
	})
end

local function start_run()
	clear_pools()
	state.mode = "countdown"
	state.lane = 2
	state.elapsed = 0
	state.score = 0
	state.treasures = 0
	state.alert = 0
	state.invulnerable = 0
	state.countdown = 3.5
	state.spawn_timer = 0.30
	state.new_record = false
	if player_actor then
		player_actor:stoptweening():xy(lane_x[state.lane], player_y)
			:diffusealpha(1):rotationz(0):visible(true)
	end
	MESSAGEMAN:Broadcast("MementosDashReset", { best = state.high_score })
end

local function finish_run()
	if state.mode ~= "running" then return end
	state.mode = "gameover"
	update_score()
	state.new_record = state.score > state.high_score
	if state.new_record then
		state.high_score = state.score
		ThemePrefs.Set("VOLT26MementosDashHighScore", state.high_score)
		ThemePrefs.Save()
	end
	for _, item in ipairs(obstacles) do deactivate(item) end
	for _, item in ipairs(treasures) do deactivate(item) end
	play_once(THEME:GetCurrentThemeDirectory() .. "Sounds/VOLT26-GameOver.ogg")
	MESSAGEMAN:Broadcast("MementosDashGameOver", {
		score = state.score,
		best = state.high_score,
		new_record = state.new_record,
	})
end

local function move_player(direction)
	if state.mode ~= "running" then return end
	local next_lane = math.max(1, math.min(3, state.lane + direction))
	if next_lane == state.lane then return end
	state.lane = next_lane
	if player_actor then
		player_actor:stoptweening():decelerate(0.10):x(lane_x[state.lane])
	end
	play_once(THEME:GetPathG("", "VOLT26/changeoption.ogg"))
end

local function spawn_from_pool(pool, lane)
	for _, item in ipairs(pool) do
		if not item.active and item.actor then
			item.active = true
			item.collided = false
			item.lane = lane
			item.y = spawn_y
			item.actor:stoptweening():xy(lane_x[lane], spawn_y)
				:diffusealpha(1):rotationz(0):visible(true)
			return item
		end
	end
	return nil
end

local function shuffled_lanes()
	local result = { 1, 2, 3 }
	for i = #result, 2, -1 do
		local j = math.random(i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

local function spawn_row(difficulty)
	local lanes = shuffled_lanes()
	local obstacle_count = math.random() < (0.25 + difficulty * 0.50) and 2 or 1
	local blocked = {}
	for i = 1, obstacle_count do
		blocked[lanes[i]] = true
		spawn_from_pool(obstacles, lanes[i])
	end

	if math.random() < 0.65 then
		local open_lanes = {}
		for lane = 1, 3 do
			if not blocked[lane] then open_lanes[#open_lanes+1] = lane end
		end
		if #open_lanes > 0 then
			spawn_from_pool(treasures, open_lanes[math.random(#open_lanes)])
		end
	end
end

local function hit_obstacle(item)
	if state.invulnerable > 0 or state.mode ~= "running" then return end
	deactivate(item)
	state.alert = state.alert + 1
	state.invulnerable = 1.25
	trigger_effect(lane_x[state.lane], player_y, {1, 0, 0, 1})
	play_once(THEME:GetPathG("", "VOLT26/knife.ogg"))
	MESSAGEMAN:Broadcast("MementosDashHit", { alert = state.alert })
	if state.alert >= 3 then finish_run() end
end

local function collect_treasure(item)
	deactivate(item)
	state.treasures = state.treasures + 1
	update_score()
	trigger_effect(lane_x[state.lane], player_y - 18, {1, 0.78, 0.12, 1})
	play_once(THEME:GetPathS("Common", "Start"))
	MESSAGEMAN:Broadcast("MementosDashTreasure")
end

local function update_pool(pool, speed, collision_fn)
	for _, item in ipairs(pool) do
		if item.active then
			item.y = item.y + speed
			item.actor:y(item.y)
			if item.y > despawn_y then
				deactivate(item)
			elseif not item.collided
			and item.lane == state.lane
			and math.abs(item.y - player_y) < 43 then
				item.collided = true
				collision_fn(item)
			end
		end
	end
end

local function update_game(frame, delta)
	if state.exiting then return end

	if music_actor and state.music_length > 0 then
		state.music_elapsed = state.music_elapsed + delta
		if state.music_elapsed >= state.music_length then
			state.music_elapsed = state.music_elapsed - state.music_length
			music_actor:stop()
			music_actor:play()
		end
	end

	if state.mode == "countdown" then
		state.countdown = state.countdown - delta
		MESSAGEMAN:Broadcast("MementosDashCountdown", { time = state.countdown })
		if state.countdown <= 0 then
			state.mode = "running"
			MESSAGEMAN:Broadcast("MementosDashStart")
		end
		return
	end

	if state.mode ~= "running" then return end

	state.elapsed = state.elapsed + delta
	state.invulnerable = math.max(0, state.invulnerable - delta)
	update_score()

	if player_actor then
		if state.invulnerable > 0 then
			player_actor:diffusealpha(math.floor(state.invulnerable * 12) % 2 == 0 and 0.25 or 1)
		else
			player_actor:diffusealpha(1)
		end
	end

	local difficulty = math.min(state.elapsed / 90, 1)
	local fall_duration = 3.0 - 1.5 * difficulty
	local speed = ((despawn_y - spawn_y) / fall_duration) * delta
	local spawn_interval = 1.10 - 0.55 * difficulty

	state.spawn_timer = state.spawn_timer - delta
	if state.spawn_timer <= 0 then
		spawn_row(difficulty)
		state.spawn_timer = state.spawn_timer + spawn_interval
	end

	update_pool(obstacles, speed, hit_obstacle)
	if state.mode == "running" then
		update_pool(treasures, speed, collect_treasure)
	end
end

local function exit_to_title()
	if state.exiting then return end
	state.exiting = true
	if root then root:SetUpdateFunction(nil) end
	if music_actor then music_actor:stop() end
	SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
end

local function input(event)
	if not event or event.type ~= "InputEventType_FirstPress" then return false end
	local button = event.GameButton
	if button == "Back" then
		exit_to_title()
	elseif button == "MenuLeft" or button == "Left" then
		move_player(-1)
	elseif button == "MenuRight" or button == "Right" then
		move_player(1)
	elseif button == "Start" and state.mode == "gameover" then
		start_run()
	end
	return false
end

local af = Def.ActorFrame{
	Name = "MementosDashRoot",
	InitCommand = function(self)
		root = self
		self:draworder(200)
	end,
	OnCommand = function(self)
		if not is_volt26 then
			state.exiting = true
			SCREENMAN:SetNewScreen("ScreenTitleMenu")
			return
		end
		local screen = SCREENMAN:GetTopScreen()
		if screen then screen:AddInputCallback(input) end
		music_actor = self:GetChild("Music")
		if music_actor then
			music_actor:play()
			local sound = music_actor:get()
			state.music_length = sound and sound:get_length() or 0
			state.music_elapsed = 0
		end
		start_run()
		self:SetUpdateFunction(update_game)
	end,
	OffCommand = function(self)
		self:SetUpdateFunction(nil)
		if music_actor then music_actor:stop() end
	end,
}

af[#af+1] = Def.Quad{
	InitCommand=function(self) self:FullScreen():diffuse(color("#E60012")) end
}

-- Animated comic-book slashes behind the playfield.
for i = 1, 9 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:zoomto(_screen.w * 0.55, 4 + (i % 3) * 3)
				:xy(_screen.cx + ((i % 2 == 0) and -1 or 1) * _screen.w * 0.34,
					40 + i * (_screen.h / 9))
				:rotationz((i % 2 == 0) and -18 or 18)
				:diffuse((i % 3 == 0) and Color.White or Color.Black)
				:diffusealpha(0.32)
		end,
		OnCommand=function(self)
			self:cropleft(1):linear(0.18 + i * 0.015):cropleft(0)
		end,
	}
end

-- Central three-lane road.
af[#af+1] = Def.Quad{
	InitCommand=function(self)
		self:zoomto(math.min(_screen.w * 0.72, 560), _screen.h + 20)
			:xy(_screen.cx, _screen.cy):diffuse(color("#090909"))
	end
}

for _, x in ipairs({ _screen.cx - lane_spacing / 2, _screen.cx + lane_spacing / 2 }) do
	for dash = 0, 7 do
		af[#af+1] = Def.Quad{
			InitCommand=function(self)
				self:zoomto(4, 30):xy(x, 40 + dash * 68)
					:diffuse(Color.White):diffusealpha(0.30)
			end
		}
	end
end

-- Pool collision burst actors.
for i = 1, effect_pool_size do
	effects[i] = { active = false, actor = nil }
	af[#af+1] = Def.ActorFrame{
		Name="Burst"..i,
		InitCommand=function(self)
			effects[i].actor = self
			self:visible(false):draworder(20)
		end,
		DeactivateCommand=function(self)
			effects[i].active = false
			self:visible(false)
		end,
		Def.Quad{ InitCommand=function(self) self:zoomto(120, 12):rotationz(25) end },
		Def.Quad{ InitCommand=function(self) self:zoomto(120, 12):rotationz(-25) end },
		Def.Quad{ InitCommand=function(self) self:zoomto(85, 8):rotationz(90):diffuse(Color.White) end },
	}
end

for i = 1, obstacle_pool_size do
	obstacles[i] = { active = false, actor = nil, lane = 1, y = spawn_y }
	af[#af+1] = Def.ActorFrame{
		Name="Obstacle"..i,
		InitCommand=function(self)
			obstacles[i].actor = self
			self:visible(false):draworder(10)
		end,
		LoadActor(THEME:GetPathG("", "VOLT26/MementosDash/shadow.png"))..{
			InitCommand=function(self) self:zoomto(86, 86):bob():effectmagnitude(0, 4, 0):effectperiod(0.55) end
		}
	}
end

for i = 1, treasure_pool_size do
	treasures[i] = { active = false, actor = nil, lane = 1, y = spawn_y }
	af[#af+1] = Def.ActorFrame{
		Name="Treasure"..i,
		InitCommand=function(self)
			treasures[i].actor = self
			self:visible(false):draworder(11)
		end,
		LoadActor(THEME:GetPathG("", "VOLT26/MementosDash/treasure.png"))..{
			InitCommand=function(self)
				self:zoomto(58, 58):spin():effectmagnitude(0, 0, 65)
			end
		}
	}
end

af[#af+1] = Def.ActorFrame{
	Name="Player",
	InitCommand=function(self)
		player_actor = self
		self:xy(lane_x[2], player_y):draworder(30)
	end,
	LoadActor(THEME:GetPathG("", "VOLT26/MementosDash/runner.png"))..{
		InitCommand=function(self)
			self:zoomto(112, 128):bob():effectmagnitude(0, 3, 0):effectperiod(0.30)
		end
	}
}

-- Header and score cards.
af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(18, 18):draworder(40) end,
	Def.Quad{
		InitCommand=function(self)
			self:halign(0):valign(0):zoomto(250, 66):skewx(-0.12):diffuse(Color.Black)
		end
	},
	LoadFont("Persona")..{
		Text="COLOTTI DASH",
		InitCommand=function(self)
			self:halign(0):xy(15, 10):zoom(0.68):diffuse(Color.White):strokecolor(color("#E60012"))
		end
	},
	LoadFont("Common Bold")..{
		Name="Score",
		InitCommand=function(self) self:halign(0):xy(16, 44):zoom(0.52):diffuse(Color.White) end,
		MementosDashResetMessageCommand=function(self, params)
			self:settext(string.format("%s 000000   %s %06d", S("Score"), S("Best"), params.best))
		end,
		MementosDashScoreMessageCommand=function(self, params)
			self:settext(string.format("%s %06d   %s %06d", S("Score"), params.score, S("Best"), params.best))
		end,
	}
}

af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(_screen.w - 142, 30):draworder(40) end,
	LoadFont("Persona")..{
		Text=S("Alert"),
		InitCommand=function(self) self:x(-24):zoom(0.62):diffuse(Color.Black) end,
	}
}

for i = 1, 3 do
	af[#af+1] = Def.Quad{
		InitCommand=function(self)
			self:xy(_screen.w - 92 + (i - 1) * 31, 30):zoomto(21, 21):rotationz(45)
				:diffuse(Color.White):draworder(40)
		end,
		MementosDashResetMessageCommand=function(self) self:diffuse(Color.White) end,
		MementosDashHitMessageCommand=function(self, params)
			self:stoptweening():diffuse(i <= params.alert and color("#FF0000") or Color.White)
			if i == params.alert then self:zoom(1.45):decelerate(0.15):zoom(1) end
		end,
	}
end

-- Countdown and controls.
af[#af+1] = Def.ActorFrame{
	Name="CountdownPanel",
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy):draworder(50) end,
	MementosDashResetMessageCommand=function(self) self:visible(true):diffusealpha(1) end,
	MementosDashStartMessageCommand=function(self) self:stoptweening():decelerate(0.18):diffusealpha(0):visible(false) end,
	Def.Quad{
		InitCommand=function(self) self:zoomto(math.min(_screen.w * 0.72, 550), 150):skewx(-0.08):diffuse(0,0,0,0.88) end
	},
	LoadFont("Persona")..{
		Name="Countdown",
		InitCommand=function(self) self:y(-22):zoom(1.35):diffuse(Color.White):strokecolor(color("#E60012")) end,
		MementosDashResetMessageCommand=function(self) self:settext("3") end,
		MementosDashCountdownMessageCommand=function(self, params)
			if params.time > 0.5 then self:settext(tostring(math.max(1, math.ceil(params.time - 0.5))))
			else self:settext(S("Go")) end
		end,
	},
	LoadFont("Common Bold")..{
		Text=S("Controls"),
		InitCommand=function(self) self:y(40):zoom(0.55):maxwidth(math.min(_screen.w * 1.2, 900)):diffuse(Color.White) end,
	}
}

-- Game-over card.
af[#af+1] = Def.ActorFrame{
	Name="GameOverPanel",
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy):visible(false):draworder(60) end,
	MementosDashResetMessageCommand=function(self) self:stoptweening():visible(false) end,
	MementosDashGameOverMessageCommand=function(self, params)
		self:visible(true):diffusealpha(0):zoom(1.35):rotationz(-3)
			:decelerate(0.18):diffusealpha(1):zoom(1):rotationz(0)
		self:GetChild("FinalScore"):settext(string.format("%s %06d\n%s %06d", S("Score"), params.score, S("Best"), params.best))
		self:GetChild("NewRecord"):visible(params.new_record)
	end,
	Def.Quad{
		InitCommand=function(self) self:zoomto(math.min(_screen.w * 0.76, 580), 225):skewx(-0.10):diffuse(Color.Black) end
	},
	Def.Quad{
		InitCommand=function(self) self:y(-86):zoomto(math.min(_screen.w * 0.70, 530), 8):rotationz(-2):diffuse(color("#E60012")) end
	},
	LoadFont("Persona")..{
		Text=S("GameOver"),
		InitCommand=function(self) self:y(-64):zoom(1.10):diffuse(Color.White):strokecolor(color("#E60012")) end,
	},
	LoadFont("Common Bold")..{
		Name="FinalScore",
		InitCommand=function(self) self:y(1):zoom(0.62):diffuse(Color.White) end,
	},
	LoadFont("Persona")..{
		Name="NewRecord",
		Text=S("NewRecord"),
		InitCommand=function(self) self:y(56):zoom(0.67):diffuse(color("#FFD21C")):visible(false):wag():effectmagnitude(0,0,3) end,
	},
	LoadFont("Common Bold")..{
		Text=S("Retry"),
		InitCommand=function(self) self:y(91):zoom(0.48):diffuse(Color.White) end,
	}
}

local music_path = THEME:GetPathG("", "VOLT26/menuost.ogg")
if FILEMAN:DoesFileExist(music_path) then
	af[#af+1] = Def.Sound{ Name="Music", File=music_path }
end

return af
