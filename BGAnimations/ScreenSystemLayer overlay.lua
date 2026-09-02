-- This is mostly copy/pasted directly from SM5's _fallback theme with
-- very minor modifications.

local t = Def.ActorFrame{}

-- -----------------------------------------------------------------------

local function CreditsText( player )
	return LoadFont("Common Normal") .. {
		InitCommand=function(self)
			self:visible(false)
			self:name("Credits" .. PlayerNumberToString(player))
			ActorUtil.LoadAllCommandsAndSetXY(self,Var "LoadingScreen")
		end,
		UpdateTextCommand=function(self)
			-- this feels like a holdover from SM3.9 that just never got updated
			local str = ScreenSystemLayerHelpers.GetCreditsMessage(player)
			local pn = ToEnumShortString(player)
			if SL[pn].GrooveStatsUsername ~= "" then
				str = SL[pn].GrooveStatsUsername
			end

			self:settext(str)
		end,
		SetCreditsTextMessageCommand=function(self, params)
			if params.pn == ToEnumShortString(player) then
				self:settext(params.username)
				self:visible(true)
			end
		end,
		UpdateVisibleCommand=function(self)
			local screen = SCREENMAN:GetTopScreen()
			local bShow = true

			local textColor = Color.White
			local shadowLength = 0

			if screen then
				bShow = THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" )

				local screenName = screen:GetName()
				if (screen:GetName() == "ScreenEvaluationStage") or (screen:GetName() == "ScreenEvaluationNonstop") or (screen:GetName() == Branch.GameplayScreen()) then
					-- ignore ShowCreditDisplay metric for ScreenEval
					-- only show this BitmapText actor on Evaluation if the player is joined
					bShow = GAMESTATE:IsHumanPlayer(player)
					--        I am not human^
					--        today, but there's always hope
					--        I'll see tomorrow

					-- dark text for RainbowMode
					if ThemePrefs.Get("RainbowMode") then
						textColor = Color.Black
					end
				end
			end

			self:visible( bShow )
			self:diffuse(textColor)
			self:shadowlength(shadowLength)
		end
	}
end

-- -----------------------------------------------------------------------
-- player avatars
-- see: https://youtube.com/watch?v=jVhlJNJopOQ

for player in ivalues(PlayerNumber) do
	t[#t+1] = Def.Sprite{
		ScreenChangedMessageCommand=function(self)   self:queuecommand("Update") end,
		PlayerJoinedMessageCommand=function(self, params)   if params.Player==player then self:queuecommand("Update") end end,
		PlayerUnjoinedMessageCommand=function(self, params) if params.Player==player then self:queuecommand("Update") end end,
		PlayerProfileSetMessageCommand=function(self, params) if params.Player==player then self:queuecommand("Update") end end,

		UpdateCommand=function(self)
			local path = GetPlayerAvatarPath(player)

			if path == nil and self:GetTexture() ~= nil then
				self:Load(nil):diffusealpha(0):visible(false)
				return
			end

			-- only read from disk if not currently set or if the path has changed
			if self:GetTexture() == nil or path ~= self:GetTexture():GetPath() then
				self:Load(path):finishtweening():linear(0.075):diffusealpha(1)

				local dim = 32
				local h   = (player==PLAYER_1 and left or right)
				local x   = (player==PLAYER_1 and    0 or _screen.w)

				self:horizalign(h):vertalign(bottom)
				self:xy(x, _screen.h):setsize(dim,dim)
			end

			local screen = SCREENMAN:GetTopScreen()
			if screen then
				if THEME:HasMetric(screen:GetName(), "ShowPlayerAvatar") then
					self:visible( THEME:GetMetric(screen:GetName(), "ShowPlayerAvatar") )
				else
					self:visible( THEME:GetMetric(screen:GetName(), "ShowCreditDisplay") )
				end
			end
		end,
	}
end

-- -----------------------------------------------------------------------

-- what is aux?
t[#t+1] = LoadActor(THEME:GetPathB("ScreenSystemLayer","aux"))

-- Credits
t[#t+1] = Def.ActorFrame {
 	CreditsText( PLAYER_1 ),
	CreditsText( PLAYER_2 )
}

-- "Event Mode" or CreditText at lower-center of screen
t[#t+1] = LoadFont("Common Footer")..{
	InitCommand=function(self) self:xy(_screen.cx, _screen.h-16):zoom(0.5):horizalign(center) end,

	OnCommand=function(self) self:playcommand("Refresh") end,
	ScreenChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinModeChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinsChangedMessageCommand=function(self) self:playcommand("Refresh") end,

	RefreshCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()

		-- if this screen's Metric for ShowCreditDisplay=false, then hide this BitmapText actor
		-- PS: "ShowCreditDisplay" isn't a real Metric as far as the engine is concerned.
		-- I invented it for Simply Love and it has (understandably) confused other themers.
		-- Sorry about this.
		if screen then
			self:visible( THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" ) )
		end

		if PREFSMAN:GetPreference("EventMode") then
			self:settext( THEME:GetString("ScreenSystemLayer", "EventMode") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Pay" then
			local credits = GetCredits()
			local text

			if credits.CoinsPerCredit > 1 then
				text = ("%s     %d     %d/%d"):format(
					THEME:GetString("ScreenSystemLayer", "CreditsCredits"),
					credits.Credits,
					credits.Remainder,
					credits.CoinsPerCredit
				)
			else
				text = ("%s     %d"):format(
					THEME:GetString("ScreenSystemLayer", "CreditsCredits"),
					credits.Credits
				)
			end

			self:settext(text)

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Free" then
			self:settext( THEME:GetString("ScreenSystemLayer", "FreePlay") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Home" then
			self:settext('')
		end

		self:diffuse(Color.White)
	end
}

-- -----------------------------------------------------------------------
-- Modules

local function LoadModules()
	-- A table that contains a [ScreenName] -> Table of Actors mapping.
	-- Each entry will then be converted to an ActorFrame with the actors as children.
	local modules = {}
	local files = FILEMAN:GetDirListing(THEME:GetCurrentThemeDirectory().."Modules/")
	for file in ivalues(files) do
		-- Get the file extension (everything past the last period).
		local filetype = file:match("[^.]+$"):lower()
		if filetype == "lua" then
			local full_path = THEME:GetCurrentThemeDirectory().."Modules/"..file
			Trace("Loading module: "..full_path)

			-- Load the Lua file as proper lua.
			local loaded_module, error = loadfile(full_path)
			if loaded_module then
				local status, ret = pcall(loaded_module)
				if status then
					if ret ~= nil then
						for screenName, actor in pairs(ret) do
							if modules[screenName] == nil then
								modules[screenName] = {}
							end
							modules[screenName][#modules[screenName]+1] = actor
						end
					end
				else
					lua.ReportScriptError("Error executing module: "..full_path.." with error:\n    "..ret)
				end
			else
				lua.ReportScriptError("Error loading module: "..full_path.." with error:\n    "..error)
			end
		end
	end

	for screenName, table_of_actors in pairs(modules) do
		local module_af = Def.ActorFrame {
			ScreenChangedMessageCommand=function(self)
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					local name = screen:GetName()
					if name == screenName then
						self:visible(true)
						self:queuecommand("Module")
					else
						self:visible(false)
					end
				else
					self:visible(false)
				end
			end,
		}
		for actor in ivalues(table_of_actors) do
			module_af[#module_af+1] = actor
		end
		t[#t+1] = module_af
	end
end

LoadModules()

-- -----------------------------------------------------------------------
-- The GrooveStats service info pane.
-- We put this in ScreenSystemLayer because if people move through the menus too fast,
-- it's possible that the available services won't be updated before one starts the set.
-- This allows us to set available services "in the background" as we're moving
-- through the menus.

local NewSessionRequestProcessor = function(res, gsInfo)
	if gsInfo == nil then return end
	
	local groovestats = gsInfo:GetChild("GrooveStats")
	local service1 = gsInfo:GetChild("Service1")
	local service2 = gsInfo:GetChild("Service2")
	local service3 = gsInfo:GetChild("Service3")

	service1:visible(false)
	service2:visible(false)
	service3:visible(false)

	local connected, errorCode = VOLT26.GrooveStats.ApplySessionResponse(res)
	if not connected then
		local messages = {
			Blocked = "Access to GrooveStats Host Blocked",
			CannotConnect = "Machine Offline",
			Timeout = "Request Timed Out",
			["response-too-large"] = "Response Too Large",
			["invalid-json"] = "Invalid Service Response",
		}
		groovestats:settext(errorCode == "Timeout" and "Timed Out" or "❌ GrooveStats")
		service1:settext(messages[errorCode] or "Failed to Load 😞"):visible(true)
	else
		local unavailable = {}
		if not VOLT26.GrooveStats.GetScores then unavailable[#unavailable+1] = "❌ Get Scores" end
		if not VOLT26.GrooveStats.Leaderboard then unavailable[#unavailable+1] = "❌ Leaderboard" end
		if not VOLT26.GrooveStats.AutoSubmit then unavailable[#unavailable+1] = "❌ Auto-Submit" end
		for index, text in ipairs(unavailable) do
			gsInfo:GetChild("Service"..index):settext(text):visible(true)
		end
		groovestats:settext(#unavailable == 0 and "✔ GrooveStats" or "⚠ GrooveStats")
	end

	VOLT26.Text.DiffuseEmojis(groovestats:ClearAttributes())
	VOLT26.Text.DiffuseEmojis(service1:ClearAttributes())
	VOLT26.Text.DiffuseEmojis(service2:ClearAttributes())
	VOLT26.Text.DiffuseEmojis(service3:ClearAttributes())
end

local function DiffuseText(bmt)
	local textColor = Color.White
	local shadowLength = 0
	if ThemePrefs.Get("RainbowMode") and not HolidayCheer() then
		textColor = Color.Black
	end

	bmt:diffuse(textColor):shadowlength(shadowLength)
end

t[#t+1] = Def.ActorFrame{
	Name="GrooveStatsInfo",
	InitCommand=function(self)
		-- Put the info in the top right corner.
		self:zoom(0.8):x(10):y(15)
	end,
	ScreenChangedMessageCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if screen:GetName() == "ScreenTitleMenu" or screen:GetName() == "ScreenTitleJoin" then
			self:queuecommand("Reset")
			self:diffusealpha(0):sleep(0.2):linear(0.4):diffusealpha(1):visible(true)
			self:queuecommand("SendRequest")
		else
			self:visible(false)
		end
	end,

	LoadFont("Common Normal")..{
		Name="GrooveStats",
		Text="     GrooveStats",
		InitCommand=function(self)
			self:visible(ThemePrefs.Get("EnableGrooveStats"))
			self:horizalign(left)
			DiffuseText(self)
		end,
		ResetCommand=function(self)
			self:visible(ThemePrefs.Get("EnableGrooveStats"))
			self:settext("     GrooveStats")
		end
	},

	LoadFont("Common Normal")..{
		Name="Service1",
		Text="",
		InitCommand=function(self)
			self:visible(true):addy(18):horizalign(left)
			DiffuseText(self)
		end,
		ResetCommand=function(self) self:settext("") end
	},

	LoadFont("Common Normal")..{
		Name="Service2",
		Text="",
		InitCommand=function(self)
			self:visible(true):addy(36):horizalign(left)
			DiffuseText(self)
		end,
		ResetCommand=function(self) self:settext("") end
	},

	LoadFont("Common Normal")..{
		Name="Service3",
		Text="",
		InitCommand=function(self)
			self:visible(true):addy(54):horizalign(left)
			DiffuseText(self)
		end,
		ResetCommand=function(self) self:settext("") end
	},

	RequestResponseActor(5, 0)..{
		SendRequestCommand=function(self)
			if ThemePrefs.Get("EnableGrooveStats") then
				VOLT26.GrooveStats.ResetCapabilities()
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="?action=newSession&chartHashVersion="..SL.GrooveStats.ChartHashVersion,
					method="GET",
					timeout=10,
					callback=NewSessionRequestProcessor,
					args=self:GetParent()
				})
			end
		end
	}
}

-- -----------------------------------------------------------------------
-- SystemMessage stuff.
-- Put it on top of everything
-- this is what appears when someone uses SCREENMAN:SystemMessage(text)
-- or MESSAGEMAN:Broadcast("SystemMessage", {text})
-- or SM(text)

local bmt = nil
local totalVisibleLines = 19

-- SystemMessage ActorFrame
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self)
		self.IsDisplaying = false
	end,
	OnCommand=function(self)
		self.IsDisplaying = true
	end,
	OffCommand=function(self)
		self.IsDisplaying = false
	end,
	SystemMessageMessageCommand=function(self, params)
		-- Handle case where the message usage is SM(msg, duration)
		local stack = params.Stack or false
		if type(stack) == "number" then
			params.Stack = params.Duration
			params.Duration = stack
		end

		if params.Stack == true then
			if self.IsDisplaying then
				self:finishtweening()
				local newText = bmt:GetText().."\n"..params.Message
				-- Display only the last few lines of text
				local lines = {}
				for line in newText:gmatch("[^\n]+") do
					lines[#lines+1] = line
				end
				local start = math.max(#lines - totalVisibleLines, 1)
				local displayText = table.concat(lines, "\n", start, #lines)
				bmt:settext(displayText)
			else
				bmt:settext( params.Message )
			end
			self:playcommand( "On")
			if params.NoAnimate then
				self:finishtweening()
			end
			self:sleep(type(params.Duration)=="number" and params.Duration or 3.33 + 0.25):queuecommand("Off")
		else
			bmt:settext( params.Message )
			self:playcommand( "On" )
			if params.NoAnimate then
				self:finishtweening()
			end
			self:playcommand( "Off", params )
		end
	end,
	HideSystemMessageMessageCommand=function(self) self:finishtweening() end,

	-- background quad behind the SystemMessage
	Def.Quad {
		InitCommand=function(self)
			self:zoomto(_screen.w, 30)
			self:horizalign(left):vertalign(top)
			self:diffuse(0,0,0,0)
		end,
		OnCommand=function(self)
			self:finishtweening():diffusealpha(0.85)
			self:zoomto(_screen.w, (bmt:GetHeight() + 16) * SL_WideScale(0.8, 1) )
		end,
		OffCommand=function(self, params)
			-- use 3.33 seconds as a default duration if none was provided as the second arg in SM()
			self:sleep(type(params.Duration)=="number" and params.Duration or 3.33):linear(0.25):diffusealpha(0)
		end,
	},

	-- BitmapText for the SystemMessage
	LoadFont("Common Normal")..{
		Name="Text",
		InitCommand=function(self)
			bmt = self

			self:maxwidth(_screen.w-20)
			self:horizalign(left):vertalign(top):xy(10, 10)
			self:diffusealpha(0):zoom(SL_WideScale(0.8, 1))
		end,
		OnCommand=function(self)
			self:finishtweening():diffusealpha(1)
		end,
		OffCommand=function(self, params)
			-- use 3 seconds as a default duration if none was provided as the second arg in SM()
			self:sleep(type(params.Duration)=="number" and params.Duration or 3):linear(0.5):diffusealpha(0)
		end,
	}
}
-- -----------------------------------------------------------------------

return t
