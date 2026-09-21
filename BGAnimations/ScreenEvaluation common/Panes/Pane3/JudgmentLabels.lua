local player = ...
local pn = ToEnumShortString(player)
local mods = VOLT26[pn].ActiveModifiers

local TapNoteScores = {Types={}, Names={}}
local Colors = {}
if mods.ShowFaPlusWindow and mods.ShowFaPlusPane then
	TapNoteScores.Types = {'W0', 'W1', 'W2', 'W3', 'W4', 'W5', 'Miss'}
	Colors = {
		VOLT26.JudgmentColors["ITG"][1], -- Fantastic Blue
		VOLT26.JudgmentColors["FA+"][2], -- Just extract the Fantastic white color
        VOLT26.JudgmentColors["ITG"][2], -- Yellow Excellent
		VOLT26.JudgmentColors["ITG"][3], -- Green Great
		VOLT26.JudgmentColors["ITG"][4], -- Purple Decent
		VOLT26.JudgmentColors["ITG"][5], -- Way Off
		VOLT26.JudgmentColors["ITG"][6], -- Red Miss
	}
	-- get all TNS names
	TapNoteScores.Names = {
		THEME:GetString("TapNoteScore", "W1"),
		THEME:GetString("TapNoteScoreFA+", "W2"), -- Extract the Fantastic White Window
		THEME:GetString("TapNoteScore", "W2"),
		THEME:GetString("TapNoteScore", "W3"),
		THEME:GetString("TapNoteScore", "W4"),
		THEME:GetString("TapNoteScore", "W5"),
		THEME:GetString("TapNoteScore", "Miss"),
	}
else
	TapNoteScores.Types = {'W1', 'W2', 'W3', 'W4', 'W5', 'Miss'}
	Colors = {
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][1],
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][2],
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][3],
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][4],
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][5],
		VOLT26.JudgmentColors[VOLT26.Global.GameMode][6],
	}
	local tns_string = "TapNoteScore" .. (VOLT26.Global.GameMode=="ITG" and "" or VOLT26.Global.GameMode)
	-- get TNS names appropriate for the current GameMode, localized to the current language
	for i, judgment in ipairs(TapNoteScores.Types) do
		TapNoteScores.Names[#TapNoteScores.Names+1] = THEME:GetString(tns_string, judgment)
	end
end

local box_height = 146
local row_height = box_height/#TapNoteScores.Types

local t = Def.ActorFrame{
	InitCommand=function(self) self:xy(50 * (player==PLAYER_2 and -1 or 1), _screen.cy-36) end
}

local miss_bmt

local windows = VOLT26[pn].ActiveModifiers.TimingWindows

--  labels: W1 ---> Miss
for i=1, #TapNoteScores.Types do
	-- no need to add BitmapText actors for TimingWindows that were turned off
	if windows[i] or i == #TapNoteScores.Types or (mods.ShowFaPlusWindow and mods.ShowFaPlusPane and windows[i-1]) then

		local window = TapNoteScores.Types[i]
		local label = TapNoteScores.Names[i]

		t[#t+1] = LoadFont("Common Normal")..{
			Text=label:upper(),
			InitCommand=function(self)
				self:zoom(0.8):horizalign(right):maxwidth(65/self:GetZoom())
					:x( (player == PLAYER_1 and -130) or -28 )
					:y( i * row_height )
					:diffuse( Colors[i] )

				if i == #TapNoteScores.Types then miss_bmt = self end
			end
		}
	end
end

t[#t+1] = LoadFont("Common Normal")..{
	Text=ScreenString("Held"),
	InitCommand=function(self)
		self:y(140):zoom(0.6):halign(1)
			:diffuse( VOLT26.JudgmentColors[VOLT26.Global.GameMode][6] )
	end,
	OnCommand=function(self)
		self:x( miss_bmt:GetX() - miss_bmt:GetWidth()/1.15 )
	end
}

return t
