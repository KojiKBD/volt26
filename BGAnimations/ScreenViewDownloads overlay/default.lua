-- sick_wheel_mt is a metatable with global scope defined in ./Scripts/Consensual-sick_wheel.lua
local candidatesScroller = setmetatable({}, sick_wheel_mt)
local candidateItemMt = LoadActor("CandidateItemMT.lua")
local inputHandler = LoadActor("InputHandler.lua", candidatesScroller)
local callback_screen

local function BuildCandidates(snapshot)
	local candidates = {}
	for index, job in ipairs(snapshot) do
		candidates[index] = {
			index=index - 1,
			downloadInfo=job,
			totalItems=#snapshot,
			uuid=job.Id,
		}
	end
	return candidates
end

local af = Def.ActorFrame{
	Name="DownloadsViewer",
	InitCommand=function(self) self:Center() end,
	OnCommand=function(self)
		candidatesScroller.disable_wrapping = true
		callback_screen = SCREENMAN:GetTopScreen()
		callback_screen:AddInputCallback(inputHandler)
		self:queuecommand("RefreshStatus")
	end,
	OffCommand=function(self)
		if callback_screen then
			callback_screen:RemoveInputCallback(inputHandler)
			callback_screen = nil
		end
	end,

	candidatesScroller:create_actors("Candidates", 6, candidateItemMt, -240, -240),

	RefreshStatusCommand=function(self)
		local snapshot = VOLT26.Downloads.Snapshot()
		local candidates = BuildCandidates(snapshot)
		local position = math.min(candidatesScroller.info_pos or 1, math.max(1, #candidates))
		candidatesScroller:set_info_set(candidates, position)
		self:GetChild("NoDownloads"):visible(#candidates == 0)
		self:playcommand("UpdateScrollbar", {numCandidates=#candidates})

		local finished, total = VOLT26.Downloads.GetCounts(snapshot)

		self:GetChild("Completed"):settext(finished.."/"..total)

		for idx1, idx2 in ipairs(candidatesScroller.info_map) do
			candidatesScroller.items[idx1]:set(candidatesScroller.info_set[idx2])
		end

		-- Keep the view synchronized if a future provider adds, removes, or updates jobs.
		self:sleep(0.25):queuecommand("RefreshStatus")
	end
}

af[#af+1] = Def.BitmapText{
	Text=THEME:GetString("Common", "PopupDismissText"),
	Font="Common Normal",
	InitCommand=function(self)
		self:y(170)
	end,
}

af[#af+1] = Def.BitmapText{
	Name="NoDownloads",
	Text=THEME:GetString("GrooveStats", "NoDownloads"),
	Font="Common Normal",
	InitCommand=function(self) self:visible(false):zoom(2) end,
}

af[#af+1] = Def.BitmapText{
	Name="Completed",
	Text="",
	Font="Common Normal",
	InitCommand=function(self)
		self:xy(220, 170):horizalign('HorizAlign_Right')
	end,
}

return af
