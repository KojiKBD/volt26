-- Bottom band: what the buttons do here.  Opaque, like the header, so the
-- wheel's lowest rows slide out under it.
local p = ...
local K = p.K

local top = 1004

local keys = GAMESTATE:IsCourseMode()
	and { "HintPlay", "HintMenu", "HintExit" }
	or { "HintPlay", "HintPacks", "HintMenu" }
local hints = {}
for _, key in ipairs(keys) do hints[#hints+1] = K.String(key) end

local af = Def.ActorFrame{ Name="Footer" }
af[#af+1] = K.Rule{ Name="Band", X=-K.W, Y=top, Width=K.W*3, Height=K.H, Tint=K.Bg, Alpha=0.94 }
af[#af+1] = K.Rule{ Name="Divider", Y=top, Width=K.W, Height=1 }
af[#af+1] = K.Text{ Name="Hints", Px=13, Tint=K.Mute, X=40, Y=top + 38, Text=table.concat(hints, "        ") }
return af
