local failed = ...

local totalTime = failed and 3 or 1
local af = Def.ActorFrame{
	InitCommand=function(self)
		self:Center()
	end,
	OnCommand=function(self)
		self:sleep(totalTime - 0.5):linear(0.5):diffusealpha(0)
		if failed then
			SOUND:PlayOnce(THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Failed.ogg"))
			self:GetChild("Failed"):play()
		else
			SOUND:PlayOnce(THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Passed.ogg"))
			self:GetChild("Victory"):play()
		end
	end,
	OffCommand=function(self)
		self:GetChild("Victory"):stop()
		self:GetChild("Failed"):stop()
	end,
	Def.Sound{
		Name="Victory",
		File=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Victory.ogg"),
	},
	Def.Sound{
		Name="Failed",
		File=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Failed_theme.ogg"),
	},
}

if failed then
	local sPath    = "_VisualStyles/VOLT26/Eval/defeat_animation_res/"
    local startNum = 0
    local endNum   = 38
	local tytPath    = "_VisualStyles/VOLT26/Eval/tyt_res/"
    local fFPS     = 24
    local fDelay   = 1 / fFPS


	af[#af+1] = Def.Sprite{
		Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/defeat.png"),
		InitCommand=function(self)
			self:zoom(0.5)
			--self:x(-200):y(100)
		end,
		OnCommand=function(self)
			self:decelerate(0.1):zoom(0.3)
			self:sleep(1.8)
			self:linear(0.5):diffusealpha(0)
		end,
	}


    local function framePath(n)
        return THEME:GetPathG("", sPath.."defeat_"..string.format("%05d", n)..".png")
    end

    local anim2 = Def.Sprite{
        Texture=framePath(startNum),
        InitCommand=function(self)
            self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
        end,
        OnCommand=function(self)
            self:sleep(fDelay):queuecommand("Frame"..(startNum + 1))
        end,
    }

    for n = startNum + 1, endNum do
        anim2["Frame"..n.."Command"] = function(self)
            self:Load(framePath(n))
            if n < endNum then
                self:sleep(fDelay):queuecommand("Frame"..(n + 1))
            end
        end
    end


	af[#af+1] = anim2


local function framePath(n)
    return THEME:GetPathG("", tytPath.."tyt_"..string.format("%05d", n)..".png")
end

local loopCount = 0
local maxLoops = 2

	local function frameCommand(n)
		return function(self)
			self:Load(framePath(n))
			local nextN = n + 1
			if nextN > endNum then
				loopCount = loopCount + 1
				if loopCount < maxLoops then
					nextN = startNum
				else
					return -- stop here, animation finished its 2 loops
				end
			end
			self:sleep(fDelay):queuecommand("Frame"..nextN)
		end
	end

	local anim = Def.Sprite{
		Texture=framePath(startNum),
		InitCommand=function(self)
			self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
		end,
		OnCommand=function(self)
			self:sleep(fDelay):queuecommand("Frame"..(startNum + 1))
		end,
	}

	for n = startNum, endNum do
		anim["Frame"..n.."Command"] = frameCommand(n)
	end





    af[#af+1] = anim


	-- af[#af+1] = Def.Sprite{
	-- 	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/srpg.png"),
	-- 	InitCommand=function(self)
	-- 		self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
	-- 	end,
	-- 	OnCommand=function(self)
	-- 		self:decelerate(0.75):zoomto(SCREEN_WIDTH + 600, SCREEN_HEIGHT + 450)
	-- 		--self:decelerate(0.75):zoomto(SCREEN_WIDTH - 600, SCREEN_HEIGHT - 450)
	-- 	end,
	-- }



	-- af[#af+1] = Def.Sprite{
	-- 	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Red Lines.png"),
	-- 	InitCommand=function(self)
	-- 		self:zoom(480 / 1080):diffusealpha(0)
	-- 	end,
	-- 	OnCommand=function(self)
	-- 		self:accelerate(0.1):diffusealpha(1)
	-- 	end,
	-- }

	-- af[#af+1] = Def.Sprite{
	-- 	Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Expedition Failed.png"),
	-- 	InitCommand=function(self)
	-- 		self:zoom(480 / 1080):diffusealpha(0)
	-- 	end,
	-- 	OnCommand=function(self)
	-- 		self:linear(0.375):diffusealpha(1)
	-- 	end,
	-- }
else
    local sPath    = "_VisualStyles/VOLT26/Eval/victory_animation_res/"
    local startNum = 7
    local endNum   = 60
    local fFPS     = 24
    local fDelay   = 1 / fFPS

    local function framePath(n)
        return THEME:GetPathG("", sPath.."victory_"..string.format("%05d", n)..".png")
    end


	af[#af+1] = Def.Quad{
		InitCommand=function(self) self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):diffuse(Color.Black):diffusealpha(0.8) end,
		OnCommand=function(self) self:sleep(2.2):linear(0.1):diffusealpha(0)
		-- self:linear(0.375):diffusealpha(1)
	end,
	}

    local anim = Def.Sprite{
        Texture=framePath(startNum),
        InitCommand=function(self)
            self:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
        end,
        OnCommand=function(self)
            self:sleep(fDelay):queuecommand("Frame"..(startNum + 1))
        end,
    }

    for n = startNum + 1, endNum do
        anim["Frame"..n.."Command"] = function(self)
            self:Load(framePath(n))
            if n < endNum then
                self:sleep(fDelay):queuecommand("Frame"..(n + 1))
            end
        end
    end

    af[#af+1] = anim
	af[#af+1] = Def.Sprite{
		Texture=THEME:GetPathG("", "_VisualStyles/VOLT26/Eval/Victory.png"),
		InitCommand=function(self)
			self:zoom(0.5)
			-- x(-200) moves it left. y(0) keeps it vertically centered.
			-- Change -200 to something like -300 if you want it further left!
			self:x(-200):y(100)
		end,
		OnCommand=function(self)
			self:decelerate(0.1):zoom(0.3) -- Does the zoom animation
			self:sleep(2)                   -- Waits for 2 seconds
			self:linear(0.1):diffusealpha(0) -- Fades out to invisible over 0.5 seconds
		end,
	}

end

return af
