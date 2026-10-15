-- Which rows the Quick Mods menu offers, and in what order.
--
-- Quick Mods is the panel the sort menu raises over song select.  It is meant
-- to be short: the settings a player changes between songs, with the note field
-- beside them showing the result.  Everything else stays on the options screen.
--
-- Edit the list below and restart the theme (or reload it from the service
-- menu).  Remove a line to drop that row, reorder the lines to reorder the
-- menu.  A name that is not one of the rows listed under "Available" is
-- ignored, and an empty or broken list falls back to the built-in order.

return {
	"SpeedModType",
	"SpeedMod",
	"Mini",
	"Reverse",
	"Perspective",
	"NoteSkin",
	"NoteSkinVariant",
	"JudgmentGraphic",
	"ComboFont",
	"HoldJudgment",
}

-- Available:
--
--   SpeedModType      x-mod, c-mod or m-mod
--   SpeedMod          the speed itself, in the unit the type above selects
--   Mini              note size
--   Reverse           receptors at the bottom, arrows scrolling upwards
--   Perspective       overhead, hallway, distant, incoming, space
--   NoteSkin          the arrows themselves
--   NoteSkinVariant   a skin's own variants, greyed out when it has none
--   JudgmentGraphic   the judgment font
--   ComboFont         the combo font
--   HoldJudgment      the hold judgment graphic
--   BackgroundFilter  how far the background is darkened during gameplay
--   MusicRate         the song's own speed -- shared by both players, and it
--                     changes how long the song lasts, so it is left out of
--                     the default list
