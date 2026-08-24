if SL.Global.GameMode == "Casual" then return end

local player = ...
local NumPlayers = #GAMESTATE:GetHumanPlayers()

local GraphWidth  = THEME:GetMetric("GraphDisplay", "BodyWidth")
local GraphHeight = THEME:GetMetric("GraphDisplay", "BodyHeight")
local timeline = VOLT26.Analysis.GetTimeline(player)

local af = Def.ActorFrame{
	Name="JudgeGraph",
	InitCommand=function(self)
		self:y(_screen.cy + 124)
		if NumPlayers == 1 then
			-- not quite an even 0.25 because we need to accomodate the extra 10px
			-- that would normally be between the left and right panes
			self:addx(GraphWidth * 0.2541)
		end
	end,

	-- Draw a Quad behind the GraphDisplay (lifebar graph) and Judgment ScatterPlot
	Def.Quad{
		InitCommand=function(self)
			self:zoomto(GraphWidth, GraphHeight):diffuse(color("#101519")):vertalign(top)
		end
	},
}

-- Only add the background histogram in normal gameplay.
-- Course mode needs to get all subsong density graphs and put them togetehr which we
-- don't currently support.
if not GAMESTATE:IsCourseMode() then
	af[#af+1] = NPS_Histogram(player, GraphWidth, GraphHeight, 0.5)..{
		Name="DensityGraph",
		OnCommand=function(self)
			self:addx(-GraphWidth/2):addy(GraphHeight)
			-- Lower the opacity otherwise some of the scatter plot points might become hard to see.
			self:diffusealpha(0.5)
			self:queuecommand("Redraw")
		end,
	}
else
	af[#af+1] = NPS_Histogram_Static_Course(player, GraphWidth, GraphHeight, 0.5)..{
		Name="DensityGraph",
		OnCommand=function(self)
			self:addx(-GraphWidth/2):addy(GraphHeight)
			-- Lower the opacity otherwise some of the scatter plot points might become hard to see.
			self:diffusealpha(0.65)
		end,
	}
end

af[#af+1] = LoadActor("./ScatterPlot.lua", {player=player, GraphWidth=GraphWidth, GraphHeight=GraphHeight} )

-- The GraphDisplay provided by the engine provides us a solid color histogram detailing
-- the player's lifemeter during gameplay capped by a white line.
-- in normal gameplay (non-CourseMode), we hide the solid color but leave the white line.
-- in CourseMode, we hide the white line (for aesthetic reasons) and leave the solid color
-- Course mode keeps the filled life graph while the scatter plot supplies
-- alternating chart segments on the shared course timeline.
af[#af+1] = Def.GraphDisplay{
	Name="GraphDisplay",
	InitCommand=function(self)
		self:vertalign(top)
		local ColorIndex = ((SL.Global.ActiveColorIndex + (player==PLAYER_1 and -1 or 1)) % #SL.Colors) + 1
		self:Load("GraphDisplay" .. ColorIndex )

		if not GAMESTATE:IsCourseMode() then
			local chartStartSecond = GAMESTATE:GetCurrentSong():GetFirstSecond()
			local duration = math.max(timeline.lastSecond - timeline.firstSecond, 0.001)

			-- GraphDisplay starts at chartStartSecond, but the NPS graph
			-- and the scatter plot start at firstSecond, so we have to
			-- move the lifebar to the correct offset to align it with the
			-- NPS graph.
			local offsetFactor = (chartStartSecond - timeline.firstSecond) / duration
			local offset = GraphWidth * offsetFactor
			self:addx(offset/2)
			self:SetWidth(GraphWidth - offset)
		else
			local duration = TotalCourseLength(player)
			local liveDuration = TotalCourseLengthPlayed(player)

			if liveDuration ~= -1 then
				self:SetWidth(liveDuration / duration * GraphWidth):x(-GraphWidth/2):horizalign(left)
			end
		end

		local playerStageStats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
		local stageStats = STATSMAN:GetCurStageStats()
		self:Set(stageStats, playerStageStats)
		
		-- hide the GraphDisplay's body (2nd unnamed child)
		self:GetChild("")[2]:visible(false)
		self:GetChild("Line"):addy(1)
	end
}

af[#af+1] = Def.Quad{
	Name="ZeroLine",
	InitCommand=function(self)
		self:zoomto(GraphWidth,1)
		self:y(GraphHeight/2)
		self:diffusealpha(0.1)
	end
}

local failure = VOLT26.Failure.GetSnapshot(player)

if failure then
	local seconds = failure.total_seconds
	local deathSecond = failure.death_second
	local deathMeasures = failure.death_measures
	local graphPercentage = seconds > 0 and clamp(deathSecond / seconds, 0, 1) or 0
	local secondsLeft = seconds - deathSecond

	-- If the player failed, check how much time was remaining
	af[#af+1] = Def.ActorFrame {
		InitCommand=function(self)
			self:zoom(1.25)
			-- Start at the start of the graph
			self:addx(-GraphWidth / 2):addy(GraphHeight - 10)
			-- Move to where the player failed
			self:addx(GraphWidth * graphPercentage)
		end,
		Def.ActorFrame {
			Name="BGQuad",
			SetSizeCommand=function(self, params)
				if params.lines == 2 then self:addy(-10) end
			end,
			Def.Quad {
				InitCommand=function(self)
					self:diffuse(Color.Red)
				end,
				SetSizeCommand=function(self, params)
					self:zoomto(params.width + 1, 10 * params.lines + 1)
					self:addx(params.addx)
				end
			},
			Def.Quad {
				InitCommand=function(self)
					self:diffuse(Color.Black)
				end,
				SetSizeCommand=function(self, params)
					self:zoomto(params.width,10 * params.lines)
					self:addx(params.addx)
				end
			},
		},
		LoadFont("Common Normal")..{
			InitCommand=function(self)
				self:zoom(0.5)
				self:diffuse(Color.Red)
				local text
				-- fail time formatting
				if secondsLeft > 3600 then
					-- format to display as H:MM:SS
					text = math.floor(secondsLeft / 3600) .. ":" .. SecondsToMMSS(secondsLeft % 3600)
				else
					-- format to display as M:SS
					text = SecondsToMSS(secondsLeft)
				end	
				if deathMeasures then text = text .. "\n" .. deathMeasures self:addy(-10) end
				self:settext(text)
				local width = self:GetWidth() * 0.65
				local addx = math.max(width * 0.8, 10)
				local quad = self:GetParent():GetChild("BGQuad")
				quad:playcommand("SetSize", { width=width, addx=addx, lines=(deathMeasures ~= nil and 2 or 1) })
				self:addx(addx)
			end
		}	
	}
end

return af
