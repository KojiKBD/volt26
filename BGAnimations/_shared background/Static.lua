-- --------------------------------------------------------
-- static background image

local file = ...

local style = ThemePrefs.Get("VisualStyle")

local function Brighten(color, intensity)
    color[1] = math.min(1, color[1] * intensity)
    color[2] = math.min(1, color[2] * intensity)
    color[3] = math.min(1, color[3] * intensity)
    return color
end

local af = Def.ActorFrame {
    InitCommand=function(self)
        self:diffusealpha(0)
        -- >>> VOLT26 CHANGE: Added "or style == 'VOLT26'" <<<
        self:visible(style == "SRPG10" or style == "VOLT26")
    end,
    OnCommand=function(self)
        self:accelerate(0.8):diffusealpha(1)
    end,
    VisualStyleSelectedMessageCommand=function(self)
        local style = ThemePrefs.Get("VisualStyle")
        -- >>> VOLT26 CHANGE: Added "or style == 'VOLT26'" <<<
        if style == "SRPG10" or style == "VOLT26" then
            self:visible(true)
        else
            self:visible(false)
        end
    end,
    Def.Sprite {
        Name="Background",
        InitCommand= function(self)
            -- >>> VOLT26 CHANGE: Added VOLT26 path logic <<<
            if style == "SRPG10" then
                local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                if video_allowed then
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/BackgroundVideo.mp4"))
                else
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/SharedBackground.png"))
                end
            elseif style == "VOLT26" then
                -- local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                -- if video_allowed then
                --     self:Load(THEME:GetPathG("", "VOLT26/BackgroundVideo.mp4"))
                -- else
                    self:Load(THEME:GetPathG("", "VOLT26/SharedBackground.png"))
                -- end
            else
                self:Load(nil) 
                return 
            end

            self:halign(0.5):xy(_screen.cx, _screen.cy)
            --     :zoomto(_screen.h * 16 / 9, _screen.h)
            --     :diffuse(Color.White) -- P5 Note: If you want pure P5 red/black without color wheel tinting, change this to :diffuse(Color.White)
            self:visible(true)
        end,
        ColorSelectedMessageCommand=function(self)
            self:diffuse(Brighten(GetCurrentColor(true), 3))
        end,
        VisualStyleSelectedMessageCommand=function(self)
            local style = ThemePrefs.Get("VisualStyle")
            
            -- >>> VOLT26 CHANGE: Added VOLT26 path logic <<<
            if style == "SRPG10" then
                local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                if video_allowed then
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/BackgroundVideo.mp4"))
                else
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/SharedBackground.png"))
                end
            elseif style == "VOLT26" then
                -- local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                -- if video_allowed then
                --     self:Load(THEME:GetPathG("", "VOLT26/BackgroundVideo.mp4"))
                -- else
                    self:Load(THEME:GetPathG("", "VOLT26/SharedBackground.png"))
                -- end
            else
                self:Load(nil) 
                return 
            end

            self:halign(0.5):xy(_screen.cx, _screen.cy)
                -- :zoomto(_screen.h * 16 / 9, _screen.h)
                -- :diffuse(Brighten(GetCurrentColor(true), 3))
        end,
        AllowThemeVideoChangedMessageCommand=function(self)
            local style = ThemePrefs.Get("VisualStyle")
            
            -- >>> VOLT26 CHANGE: Added VOLT26 path logic <<<
            if style == "SRPG10" then
                local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                if video_allowed then
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/BackgroundVideo.mp4"))
                else
                    self:Load(THEME:GetPathG("", "_VisualStyles/SRPG10/SharedBackground.png"))
                end
            elseif style == "VOLT26" then
                -- local video_allowed = ThemePrefs.Get("AllowThemeVideos")
                -- if video_allowed then
                --     self:Load(THEME:GetPathG("", "VOLT26/BackgroundVideo.mp4"))
                -- else
            self:Load(THEME:GetPathG("", "VOLT26/SharedBackground.png"))
                -- end
            else
                self:Load(nil) 
                return 
            end

            self:halign(0.5):xy(_screen.cx, _screen.cy)
                -- :zoomto(_screen.h * 16 / 9, _screen.h)
                -- :diffuse(Brighten(GetCurrentColor(true), 3))
        end,
    },
    Def.Quad{
        InitCommand=function(self)
            self:FullScreen()
             :diffuse(Color.Black)
             :diffusealpha(0.5)
        end,
    }
}

return af