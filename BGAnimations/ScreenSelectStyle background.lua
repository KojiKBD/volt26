-- ScreenSelectStyle shows one full-screen face per choice (see the underlay);
-- behind them is only the faces' red, so a face sliding in never shows a gap.
return Def.Quad{
	InitCommand=function(self)
		self:FullScreen():diffuse(color("#E40001"))
	end,
}
