local player, pss, isTwoPlayers, graph, target_score = unpack(...)
local pn = ToEnumShortString(player)
local mods = VOLT26.Options.GetPlayerModifiers(player)
local tracker = VOLT26.TargetScore.NewTracker()

local pacemaker = Def.BitmapText{
	Name="Pacemaker" .. pn,
	Font="Common Bold",
	JudgmentMessageCommand=function(self)
		self:queuecommand("Update")
	end,

	-- common logic used for both the Pacemaker text and the ActionOnTargetMissed mod
	UpdateCommand=function(self)
		local progress, newlyMissed = VOLT26.TargetScore.UpdateTracker(
			tracker,
			pss:GetActualDancePoints(),
			pss:GetCurrentPossibleDancePoints(),
			pss:GetPossibleDancePoints(),
			target_score
		)
		self:settext(string.format("%+."..progress.places.."f", progress.difference * 100))

		-- have we already missed so many dance points
		-- that the current goal is not possible anymore?
		if progress.missed then
			self:diffusealpha(0.65)
			if newlyMissed then MESSAGEMAN:Broadcast("TargetGradeMissed", {Player=player}) end
		end
	end
}

--------------------------------------------------------------
-- if the player wanted the Pacemaker mod

if mods.Pacemaker then

	pacemaker.InitCommand=function(self)

		local isCentered = (GetNotefieldX(player) == _screen.cx)
		local _y = 56
		local zoomF = 0.4

		local _x = {
			[PLAYER_1] = GetNotefieldX(PLAYER_1) + 64,
			[PLAYER_2] = GetNotefieldX(PLAYER_2) - 64
		}

		if isTwoPlayers and mods.NPSGraphAtTop then
			_x[PLAYER_1] = GetNotefieldX(PLAYER_1) - 128
			_x[PLAYER_2] = GetNotefieldX(PLAYER_2) + 128
			_y = 84
		end

		self:horizalign(center):zoom(zoomF)
		self:y(_y)
		self:x( _x[player] )

		if (not isTwoPlayers) and mods.NPSGraphAtTop then
			if not isCentered then
				self:x( _x[OtherPlayer[player]] )
			else
				self:x( _x[player] + (82 * (player==PLAYER_1 and 1 or -1)) )
			end
		end
	end

--------------------------------------------------------------
-- the player didn't want the Pacemaker mod

else
	pacemaker.InitCommand=function(self)
		-- so don't bother with any of the (above) positioning code
		-- and don't even draw the BitmapText actor
		self:visible(false)
	end
end

return pacemaker
