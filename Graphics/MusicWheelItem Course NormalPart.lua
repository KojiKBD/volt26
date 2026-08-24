local num_items = THEME:GetMetric("MusicWheel", "NumWheelItems")
-- subtract 2 from the total number of MusicWheelItems
-- one MusicWheelItem will be offsceen above, one will be offscreen below
local num_visible_items = num_items - 2

local item_width = _screen.w / 2.125

local standard = Def.ActorFrame {
    -- the MusicWheel is centered via metrics under [ScreenSelectMusic]; offset by a slight amount to the right here
	InitCommand = function(self)
		self:x(WideScale(28, 33))
		self:visible(false)
	end,
	SetCommand = function(self)
		self:visible(false)
	end,

    Def.Quad {
        InitCommand = function(self)
            self:horizalign(left):diffuse(0, 10 / 255, 17 / 255, 0.5):zoomto(item_width, _screen.h / num_visible_items)
        end
    },
    Def.Quad {
        InitCommand = function(self)
            self:horizalign(left):diffuse(DarkUI() and {1, 1, 1, 0.5} or {10 / 255, 20 / 255, 27 / 255, 1}):zoomto(item_width, (_screen.h / num_visible_items) - 1)
        end,
		SetCommand=function(self, params)
			if params.Song then
				local song = params.Song
				local offset = round(SONGMAN:GetGroup(song):GetSyncOffset(), 3)
				if offset == -0.009 then
					self:diffuserightedge(DarkUI() and {1, 1, 1, 0.5} or {10 / 255, 20 / 255, 27 / 255, 1})
				else
					self:diffuserightedge(DarkUI() and {1, 0.5, 0.5, 0.5} or {80 / 255, 20 / 255, 27 / 255, 1})
				end
			end
		end,
    }
}

return Def.ActorFrame{
	standard,
	LoadActor(THEME:GetPathG("", "VOLT26/SongSelection/MusicWheelItem.lua"), "Course"),
}
