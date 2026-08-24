local index = Var("GameCommand"):GetIndex()
local has_focus = false

local t = Def.ActorFrame{}

t[#t+1] = LoadFont("Common Bold")..{
    Name="Choice"..index,
    Text=THEME:GetString( 'ScreenTitleMenu', Var("GameCommand"):GetText() ),

    InitCommand=function(self)
        self:shadowlength(0.5):diffusealpha(0)
    end,
    
    OnCommand=function(self)
        self:diffusealpha(0)
    end,
    
    OffCommand=function(self)
        if index==0 and has_focus then
            MESSAGEMAN:Broadcast("TitleMenuToGameplay")
        end
        self:sleep(index*0.075):linear(0.18):diffusealpha(0)
    end,
    UpdateColorCommand=function(self)
        self:diffuse(has_focus and GetCurrentColor(true) or color(VOLT26.Brand.TextColor))
    end,

    GainFocusCommand=function(self)
        has_focus = true
        
        MESSAGEMAN:Broadcast("VOLT26_Hover", {idx=index})
    end,
    
    LoseFocusCommand=function(self)
        has_focus = false
        
        MESSAGEMAN:Broadcast("VOLT26_Hover", {idx=-999})
    end
}

return t
