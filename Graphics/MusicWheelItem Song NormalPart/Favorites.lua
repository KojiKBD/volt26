local player = ...
local pn = ToEnumShortString(player)

local af = Def.ActorFrame {
	PlayerJoinedMessageCommand=function(self, params)
		if not PROFILEMAN:IsPersistentProfile(params.Player) then
			GAMESTATE:ResetPlayerOptions(params.Player)
			VOLT26.Core.GetPlayerState(params.Player):initialize()
		end
		if pn == nil then
			player = params.Player
			pn = ToEnumShortString(player)
		end
	end,
    Def.Sprite{
        InitCommand=function(self)
            self:animate(false):visible(false):x(-23)
            self:Load( THEME:GetPathG("", "fave-icon.png") )
            self:diffuseshift():effectperiod(0.8)
            if pn == "P1" then
                self:effectcolor1(Color.Blue)
                self:effectcolor2(lerp_color(
                    0.70, color("#ffffff"), Color.Blue))
            else
                self:effectcolor1(color("#ff7777"))
                self:effectcolor2(lerp_color(
                    0.70, color("#ffffff"), color("#ff7777")))
            end
        end,
        SetCommand=function(self, params)
			-- Favorites are represented in VOLT26's detail UI, not in wheel rows.
			self:visible(false)
        end,
    }
}

return af
