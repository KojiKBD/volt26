-- Pack (section) rows of the song wheel.  On ScreenSelectMusic the wheel only
-- lists the open pack and hides its heading ([VOLT26SongWheel] in metrics.ini),
-- so these rows show up only on the course wheel or when no pack is open.
return LoadActor(THEME:GetPathG("", "VOLT26/SongWheel/Row.lua"), "Section")
