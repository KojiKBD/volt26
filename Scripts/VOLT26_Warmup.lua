-- Incremental asset warm-up for hardware with slow integrated graphics.
-- Loading one texture per tick avoids moving the whole decode/upload cost into
-- a screen transition, while PREFETCHMAN keeps the decoded texture available.

VOLT26.Warmup = VOLT26.Warmup or {}

local groups = {
	Core = {
		"VOLT26/SharedBackground.png",
		"VOLT26/logo_main (doubleres).png",
		"VOLT26/trainoverlay.png",
		"VOLT26/black_bars.png",
		"VOLT26/Stars/star_00000.png",
		"VOLT26/gameplay_text.png",
		"VOLT26/edit_text.png",
		"VOLT26/options_text.png",
		"VOLT26/exit_text.png",
		"VOLT26/Knife.png",
		"VOLT26/daysuntil.png",
	},
	Selection = {
		"VOLT26/SharedBackground.png",
		"VOLT26/SelectColor.png",
		"VOLT26/Select_B.png",
		"VOLT26/bg_ss@2x.png",
	},
	Play = {
		"VOLT26/GameplayIn minisplode.png",
		"VOLT26/GameplayIn splode.png",
		"VOLT26/Combo 100milestone minisplode.png",
		"VOLT26/Combo 100milestone splode.png",
		"VOLT26/Combo 1000milestone swoosh.png",
		"VOLT26/Eval/Victory.png",
		"VOLT26/Eval/defeat.png",
	},
}

local warmed = {}
local warmedPaths = {}

local function Resolve(group)
	local paths = {}
	for _, relativePath in ipairs(groups[group] or {}) do
		local path = THEME:GetPathG("", relativePath)
		if not warmedPaths[path] then paths[#paths+1] = path end
	end
	return paths
end

function VOLT26.Warmup.IsComplete(group)
	return warmed[group] == true
end

function VOLT26.Warmup.CreateActor(group, options)
	options = options or {}
	local paths = Resolve(group)
	local interval = tonumber(options.Interval) or 0.06
	local showProgress = options.ShowProgress == true
	local current = 0

	local af = Def.ActorFrame{
		Name="VOLT26_Warmup_" .. tostring(group),
		InitCommand=function(self)
			self:visible(not warmed[group])
		end,
	}

	af[#af+1] = Def.Sprite{
		Name="TextureLoader",
		Texture=THEME:GetPathG("", "_blank.png"),
		InitCommand=function(self)
			-- A tiny visible sample forces renderer upload without affecting the UI.
			self:xy(-_screen.w, -_screen.h):zoom(0.001):diffusealpha(0.01)
		end,
		OnCommand=function(self)
			if warmed[group] or #paths == 0 then
				warmed[group] = true
				MESSAGEMAN:Broadcast("VOLT26WarmupComplete", {Group=group})
				self:GetParent():visible(false)
				return
			end
			self:queuecommand("LoadNext")
		end,
		LoadNextCommand=function(self)
			current = current + 1
			local path = paths[current]
			if path then
				if PREFETCHMAN then PREFETCHMAN:Add(path) end
				self:Load(path)
				warmedPaths[path] = true
				MESSAGEMAN:Broadcast("VOLT26WarmupProgress", {
					Group=group, Current=current, Total=#paths
				})
			end

			if current < #paths then
				self:sleep(interval):queuecommand("LoadNext")
			else
				warmed[group] = true
				self:sleep(interval):queuecommand("FinishWarmup")
			end
		end,
		FinishWarmupCommand=function(self)
			MESSAGEMAN:Broadcast("VOLT26WarmupComplete", {Group=group})
			self:GetParent():visible(false)
		end,
	}

	if showProgress then
		af[#af+1] = Def.Quad{
			Name="ProgressTrack",
			InitCommand=function(self)
				self:xy(0, -_screen.h/2 + 34):zoomto(_screen.w * 0.34, 3)
					:diffuse(color("#2A2A2A"))
			end,
		}
		af[#af+1] = Def.Quad{
			Name="ProgressFill",
			InitCommand=function(self)
				self:xy(-_screen.w * 0.17, -_screen.h/2 + 34):halign(0)
					:zoomto(0, 3):diffuse(color("#FF0000"))
			end,
			VOLT26WarmupProgressMessageCommand=function(self, params)
				if params.Group ~= group or params.Total < 1 then return end
				self:stoptweening():linear(interval * 0.8)
					:zoomtowidth(_screen.w * 0.34 * params.Current / params.Total)
			end,
		}
		af[#af+1] = LoadFont("Common Normal")..{
			Name="ProgressLabel",
			Text="PREPARING VOLT26",
			InitCommand=function(self)
				self:xy(0, -_screen.h/2 + 22):zoom(0.34)
					:diffuse(color("#B8B8B8")):shadowlength(1)
			end,
		}
	end

	return af
end
