local index = Var("GameCommand"):GetIndex()
local has_focus = false
local style = ThemePrefs.Get("VisualStyle") 

local t = Def.ActorFrame{}

t[#t+1] = LoadFont("Common Bold")..{
    Name="Choice"..index,
    Text=THEME:GetString( 'ScreenTitleMenu', Var("GameCommand"):GetText() ),

    InitCommand=function(self) 
        self:shadowlength(0.5) 
        if style == "VOLT26" then
            self:diffusealpha(0)
        end
    end,
    
    -- >>> THE FIX IS HERE <<<
    OnCommand=function(self) 
        if style == "VOLT26" then
            self:diffusealpha(0) -- Force it to stay invisible, cancel the original fade-in
        else
            self:diffusealpha(0):sleep(index*0.075):linear(0.2):diffusealpha(1)
        end
    end,
    
    OffCommand=function(self)
        if index==0 and has_focus then
            MESSAGEMAN:Broadcast("TitleMenuToGameplay")
        end
        self:sleep(index*0.075):linear(0.18):diffusealpha(0)
    end,
    VisualStyleSelectedMessageCommand=function(self)
        self:playcommand("UpdateColor")
    end,
    UpdateColorCommand=function(self)
        if has_focus then
            local textColor = PlayerColor(PLAYER_2)
            if ThemePrefs.Get("VisualStyle") == "SRPG10" or ThemePrefs.Get("VisualStyle") == "VOLT26" then
                textColor = GetCurrentColor(true)
            end
            self:diffuse(textColor)
        else
            local textColor = color("#888888")
            if ThemePrefs.Get("RainbowMode") then
                textColor = Color.White
            end
            if ThemePrefs.Get("VisualStyle") == "SRPG10" or ThemePrefs.Get("VisualStyle") == "VOLT26"  then
                textColor = color(SL.SRPG10.TextColor)
            end
            self:diffuse(textColor)
        end
    end,

    GainFocusCommand=function(self)
        has_focus = true
        
        -- ADD THESE TWO LINES
        if ThemePrefs.Get("VisualStyle") == "VOLT26" then 
            MESSAGEMAN:Broadcast("VOLT26_Hover", {idx=index})
            return 
        end
        -- END ADD
        
        self:stoptweening():zoom(0.5)
        self:accelerate(0.1):glow(1,1,1,0.5)
        self:decelerate(0.05):glow(1,1,1,0)
        self:playcommand("UpdateColor")
    end,
    
    LoseFocusCommand=function(self)
        has_focus = false
        
        -- ADD THESE TWO LINES
        if ThemePrefs.Get("VisualStyle") == "VOLT26" then 
            MESSAGEMAN:Broadcast("VOLT26_Hover", {idx=-999}) 
            return 
        end
        -- END ADD
        
        self:stoptweening():zoom(0.4)
        self:accelerate(0.1):glow(1,1,1,0)
        self:playcommand("UpdateColor")
    end
}

return t