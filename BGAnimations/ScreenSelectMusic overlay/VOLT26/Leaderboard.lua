local H = ...
local MAX_ROWS = 10

local function scoresFor(profile, item, chart)
	if not profile or not item or not chart then return {} end
	local ok, scores = pcall(function()
		return profile:GetHighScoreList(item, chart):GetHighScores()
	end)
	return ok and scores or {}
end

local function localResult(player)
	if not GAMESTATE:IsHumanPlayer(player) then return nil end
	local item, chart = H.Item(), H.Chart(player)
	if not item or not chart then return nil end
	local profile = PROFILEMAN:GetProfile(player)
	local personal = scoresFor(profile, item, chart)
	local best = personal[1]
	if not best then return {player=player, rank=nil, name=H.PlayerName(player), grade="NO SCORE", chart=chart} end
	local machine = scoresFor(PROFILEMAN:GetMachineProfile(), item, chart)
	local value = best:GetPercentDP()
	local rank = 1
	for _, score in ipairs(machine) do
		if score:GetPercentDP() > value + 0.0000001 then rank = rank + 1 end
	end
	return {
		player=player, rank=rank, name=H.PlayerName(player), grade=H.GradeText(best:GetGrade()),
		chart=chart, value=value, initials=best:GetName(),
	}
end

local function buildRows()
	local item = H.Item()
	local master = GAMESTATE:GetMasterPlayerNumber()
	local chart = master and H.Chart(master) or nil
	if not item or not chart then return {}, "SELECT A SONG" end
	local machine = scoresFor(PROFILEMAN:GetMachineProfile(), item, chart)
	local locals = {}
	for _, player in ipairs({PLAYER_1, PLAYER_2}) do
		local result = localResult(player)
		if result then locals[#locals+1] = result end
	end

	-- A pinned P2 result may belong to a different selected chart. Its rank is
	-- computed against that chart's own machine list and placed below a cutoff,
	-- so the UI never implies that two different-chart ranks are adjacent.
	local topCount = MAX_ROWS
	local pinned = {}
	for _=1,3 do
		pinned = {}
		for _, result in ipairs(locals) do
			if result.chart ~= chart or not result.rank or result.rank > topCount then pinned[#pinned+1] = result end
		end
		local reserve = #pinned + (#pinned > 0 and 1 or 0)
		local nextCount = math.max(1, MAX_ROWS-reserve)
		if nextCount == topCount then break end
		topCount = nextCount
	end

	local rows = {}
	for i=1,math.min(topCount, #machine) do
		local score = machine[i]
		local row = {rank=i, name=score:GetName(), grade=H.GradeText(score:GetGrade())}
		for _, result in ipairs(locals) do
			if result.chart == chart and result.rank == i and result.initials == score:GetName()
			and math.abs((result.value or -1)-score:GetPercentDP()) < 0.0000001 then
				row.player = result.player
			end
		end
		rows[#rows+1] = row
	end
	if #pinned > 0 then rows[#rows+1] = {ellipsis=true} end
	for _, result in ipairs(pinned) do rows[#rows+1] = result end
	return rows, "LOCAL LEADERBOARD"
end

local af = Def.ActorFrame{
	Name="VOLT26Leaderboard",
	InitCommand=function(self) self:xy(640,157):rotationz(0.7) end,
	RefreshCommand=function(self)
		local rows, title = buildRows()
		self:GetChild("Title"):settext(title)
		for i=1,MAX_ROWS do
			local actor = self:GetChild("Row"..i)
			local data = rows[i]
			actor:visible(data ~= nil)
			if data then actor:playcommand("SetRow", data) end
		end
	end,
}

af[#af+1] = H.Polygon({{-8,3},{204,-5},{213,231},{3,236}}, color("#080808ee"))
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(-3,-3):zoomto(154,3):rotationz(-2):diffuse(H.White) end}
af[#af+1] = Def.Quad{InitCommand=function(self) self:align(0,0):xy(54,228):zoomto(155,3):rotationz(1.5):diffuse(H.White) end}
af[#af+1] = H.Polygon({{4,3},{184,-2},{199,31},{-2,36}}, H.P1)
af[#af+1] = Def.BitmapText{
	Name="Title", Font=H.Font, Text="LOCAL LEADERBOARD",
	InitCommand=function(self) self:xy(99,17):zoom(0.075):diffuse(H.White):rotationz(-2):maxwidth(185/0.075) end,
}

for i=1,MAX_ROWS do
	local row = Def.ActorFrame{
		Name="Row"..i,
		InitCommand=function(self) self:xy(3,42+(i-1)*18) end,
		SetRowCommand=function(self, data)
			local accent = data.player and H.Accent(data.player) or H.White
			self:GetChild("Back"):visible(data.player ~= nil):diffuse(data.player and H.Accent(data.player) or H.Black)
			self:GetChild("Rank"):settext(data.ellipsis and "..." or (data.rank and tostring(data.rank) or "--")):diffuse(accent)
			self:GetChild("Name"):settext(data.ellipsis and "CUT" or (data.name or "")):diffuse(data.player and H.White or H.Muted)
			self:GetChild("Grade"):settext(data.ellipsis and "" or (data.grade or H.Dash)):diffuse(data.player and H.White or H.White)
		end,
	}
	row[#row+1] = Def.Quad{
		Name="Back", InitCommand=function(self) self:align(0,0):xy(0,-8):zoomto(203,17):skewx(-0.08):visible(false) end,
	}
	row[#row+1] = Def.Quad{
		InitCommand=function(self) self:align(0,0):xy(8,9):zoomto(190,1):rotationz((i%3-1)*0.7):diffuse(H.White):diffusealpha(0.18) end,
	}
	row[#row+1] = Def.BitmapText{Name="Rank", Font=H.Font, InitCommand=function(self) self:x(8):horizalign(left):zoom(0.052) end}
	row[#row+1] = Def.BitmapText{Name="Name", Font=H.Font, InitCommand=function(self) self:x(41):horizalign(left):zoom(0.052):maxwidth(112/0.052) end}
	row[#row+1] = Def.BitmapText{Name="Grade", Font=H.Font, InitCommand=function(self) self:x(197):horizalign(right):zoom(0.055):maxwidth(42/0.055) end}
	af[#af+1] = row
end

H.AddRefresh(af)
return af
