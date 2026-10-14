-- Pack (section) rows of the song wheel.  In the Carousel layout the wheel of
-- ScreenSelectMusic only lists the open pack and hides its heading
-- ([VOLT26SongWheel] in metrics.ini), so these rows show up only on the course
-- wheel or when no pack is open.  In the Simply Love layout
-- ([VOLT26PackSongWheel]) every pack has one.
return LoadActor(THEME:GetPathG("", "VOLT26/SongWheel/Row.lua"), "Section")
