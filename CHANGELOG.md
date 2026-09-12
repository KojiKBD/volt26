# Changelog

All notable VOLT26 changes are documented here. Versions follow Semantic Versioning; release candidates use the `-rc.N` suffix.

## Unreleased

### Removed

- `ScreenSelectColor` and the per-session colour choice it drove. The screen is gone from the screen graph (`metrics.ini`), from navigation (`Navigation.AllowScreenSelectColor` / `AfterScreenSelectColor` are folded into `Navigation.AfterSelectProfile`), and from the Theme Options menu, along with the `AllowScreenSelectColor`, `VOLT26Color` and legacy `SimplyLoveColor` preferences and their strings in every shipped language. `VOLT26/SelectColor.png` is no longer warmed up.

### Changed

- The theme accent is now fixed rather than chosen at runtime. `VOLT26.Brand.AccentColorIndex` pins every shared element to Phantom Red (`#FF0000`); `VOLT26.Brand.PlayerAccentColorIndex` gives Player 1 that same red and differentiates Player 2 with Metaverse Violet (`#9B1BFF`). `GetCurrentColor()` and `PlayerColor()` read from those, and `SL.Global.ActiveColorIndex` is a constant.
- `DifficultyColor()` no longer derives from the accent index. It delegates to `VOLT26.ChartData.GetDifficultyColor()`, the fixed per-difficulty palette, so difficulty tints stay stable and legible now that the accent never rotates.
- `ScreenSelectStyle` pads are tinted from `PlayerColor()`: single/double/solo red, versus red on the left and violet on the right.
- Solo Song Select leaderboards now share the card's divider and the `BEST - ITG` label baseline. The local panel takes the height its scores need (a compact empty state when none exist), and GrooveStats uses the remaining column with evenly spaced scores and subtle row separators. Space for a personal score outside the top ten is reserved only when that score exists. Two-player chart layout is unchanged.
- Pack selection now replaces the player cards with a pack preview styled with the current dark panels, red rules, and display/label typography. It restores the recycled scrolling song list from `ef389ebd`, with nine visible thumbnail/title/artist rows, a pack banner and song count, a settled-hover delay, and modal pause. Thumbnails use cached still artwork and skip movie banners.
- The Sort Menu is now a centered, bordered panel instead of a 210x204 box holding a scrolling wheel, and every option it can offer is drawn in that one layout (`BGAnimations/ScreenSelectMusic overlay/SortMenu/`). Its local design space scales uniformly into a 1120x760 panel on the virtual 1920x1080 Song Select canvas, with 400px horizontal and 160px vertical margins, an opaque background, and a thin dark-red outline: a header with the open menu's name and the sort currently in force, a fixed list of nine rows on the left, a context panel on the right, and a footer with the button legend and a red action button carrying the verb for the focused choice.
- The list holds still and the cursor moves through it. That is the one behavioural change: an option keeps its position on screen rather than scrolling under a fixed centre focus, so it can be found by where it sits. Lists longer than the band page a row at a time and the footer says which page is showing. Navigation still wraps at both ends.
- Each row reads as three columns: the small letter-spaced label saying what kind of option it is (`SORT BY`, `CATEGORY`, `ACTION`, and so on), the option's own name set large, and a figure on the right -- the number of packs a sort would group into, how many entries a category holds, `A - Z`, `ASCENDING`, and `ACTIVE` on the sort already in force. The focused row washes from a deep red at its left edge back to the screen's ground, with a full-height accent bar on its left.
- The context panel answers what the focused option would do, for every option rather than only for sorts. Group-like sorts get a preview of the packs with their song counts, leading with the pack the player is currently in; a category previews the options it contains; favorites preview their per-player counts. Anything with no list to show gets a short details block instead. The bottom of the panel is pinned to the current selection -- the chart's level and the song's title -- so it does not move as the cursor travels.
- An option the current state cannot offer is now drawn greyed with `UNAVAILABLE` and refuses `Start`, rather than being dropped from the list. Today the only case that reaches this is `Genre` in a library whose songs declare no genre; the rest of the option tree still filters as it did.
- The overlay is set in Helvetica Normal throughout: the bold weight was too heavy for a layout whose names are drawn this large. Two faces carry it and they are the same glyphs -- the letter-spaced `VOLT26 Light Label` for every uppercase label, and plain `Helvetica Normal` for names, titles and the one line that is a sentence. Weight is not what separates the roles on this page; size, tracking and tint are. Sizes are given in design pixels and converted through Helvetica's own 26-unit cap height.

- `ScreenSelectProfile` is now a strip of profile cards instead of a per-player wheel of names. `[ GUEST ]` leads the strip, the local profiles follow in PROFILEMAN's order, and a panel beside them describes whichever card the cursor is on: the profile's name, four figures (songs played, best grade, top combo, last seen) and the modifiers saved in its `UserPrefs.ini`. With one player the strip runs across the screen under a full-height panel; with two it splits at the centre line and each side gets a column of rows and a compact panel. The engine still owns joining, unjoining, memory cards and the profile assignment itself -- the screen hands it an index on `Finish()` exactly as before, including `-3` for `[ GUEST ]`.
- `ScreenSelectPlayMode2` (and the disabled `ScreenSelectPlayMode` behind it) wears the same frame: the choices are a column of rows down the left, drawn by `Graphics/ScreenSelectPlayMode Icon.lua` at the `IconChoice*` coordinates, with a panel on the right that describes the focused choice from live state -- stages left against the operator's `SongsPerPlay` (or `EVENT`), life, difficulty and the number of players. The faux playfield preview (`GameplayDemo.lua`) is no longer loaded.
- Both screens hide the shared header and footer bars (`HeaderOnCommand`/`FooterOnCommand`, `ShowFooter=false`) because they now draw their own title block and key-hint line.
- `ScreenSelectPlayMode`'s `Start` handler called `SetGameModePreferences()`, a global that no longer exists; it now goes through `VOLT26.ThemePrefs.ApplyGameMode()` and writes `VOLT26.State.Global.GameMode` rather than the `SL` alias. The screen stays out of the graph -- `Navigation.AllowScreenSelectPlayMode()` still pins the mode to ITG -- but it no longer errors if it is reached.

### Added

- `SortMenu/Layout.lua`, `Descriptors.lua`, `Row.lua`, `Panel.lua`, `Chrome.lua`: the palette, type scale and geometry; the per-option descriptor that drives both a row and the panel; and the three components that draw them. A new option only has to say what it is in `Descriptors.lua` to get the same treatment as everything else.
- English and Italian strings for the overlay's chrome, row figures, action verbs and per-action descriptions, under the `SortMenu*` prefix in `[ScreenSelectMusic]`. `it.ini` also picks up `ChangePlayMode`, `ImLovinIt`, `MixTape`, `OnlineLobbies`, `BottomText`, `SetSummary` and `SetSummaryText`, which it was missing. Other languages fall back to the raw key rather than erroring.
- `Layout.Upper` maps the Latin-1 lowercase accents to their own capitals rather than flattening them, so an uppercased Italian label keeps its accent; the Helvetica pages carry the accented capitals.
- `Fonts/VOLT26 Light Label` (`Fonts/VOLT26/_volt26 light label.*`): the regular-weight twin of `VOLT26 Label`. Same letter-spacing and the same metrics, over Helvetica Normal's pages instead of Helvetica Bold's, for screens whose type is set entirely in the regular weight. `VOLT26 Label` is unchanged and still used everywhere else. The word order matters: ThemeManager resolves a theme element by listing `<name>*`, so a face named `VOLT26 Label Light` also answers a request for `VOLT26 Label` and the engine refuses both as ambiguous.

- `BGAnimations/_volt26 select chrome.lua`: the frame the two pre-Song-Select screens share -- palette, 854x480 geometry, the title block with its step tabs, boxes with a focused state, stat tiles, a meter and the key-hint line. It builds actors and holds no state.
- `Scripts/VOLT26_ProfileSummary.lua`: best grade, top combo and last-played for a profile *directory*, read from the score index that profile already carries. The per-player helpers in `VOLT26.ScoreIndex` resolve a profile through PROFILEMAN's slots, which a picker cannot do because it is listing profiles the engine has not loaded. It never triggers a rebuild -- a profile with no usable index simply reports nothing -- and caches per directory, so a figure is read once however often the cursor passes over it.
- `VOLT26.ScoreIndex` now carries `MaxCombo` per chart entry. The combo of the best-scoring run is not the best combo a profile has held, so it is merged independently. The schema version is deliberately not bumped: a bump would invalidate every existing index and charge the next Song Select a full snapshot walk, so the field fills itself in as new scores are recorded.
- `BGAnimations/ScreenSelectProfile underlay/Selection.lua`: the cursor, the visible window and who has committed, kept out of both the frames and the input handler.
- English strings for both screens' chrome, captions and choice blurbs, and a `[VOLT26ProfileSummary]` section for the relative dates.

### Notes

- The option tree, its conditions and categories, and the keys `SortMenu_InputHandler.lua` branches on are unchanged. The handler now calls `Move()` and `Focused()` on the list model; `Focused()` answers in the same shape the wheel's focused actor did (`kind`, `sort_by`, `change`, `new_overlay`), so every `Start` branch reads as it always did.
- Descriptors are built once per list rather than once per keypress, because resolving a category walks the option tree and, for playlists, reads a directory. Moving the cursor repaints nine rows and the panel and nothing else.
- `SortMenu/WheelItemMT.lua` is left in place but is no longer loaded, and no theme file references `Scripts/Consensual-sick_wheel.lua` any more. Neither was removed.
- `Series` reports the group count, because the sort orders the same groups; it is not a separate series count. A library with no genre metadata is what greys `Genre` out, and that check scans the song list once per screen.

- `ScreenSelectProfile underlay/ScrollerItemMT.lua`, `JudgmentGraphicPreviews.lua` and `NoteSkinPreviews.lua` are left in place but are no longer loaded: the panel states a profile's modifiers as text and no longer previews its noteskin and judgment graphic.
- The one-player layout is chosen when `PreferredStyle` is `single` or `double` and a second side cannot join. Any other setting keeps both halves on screen so a second player can still press `START` to join, which is the behaviour the screen had before.
- Verified: Lua syntax on every changed file (`luac5.1 -p`), and that every `THEME:GetString` key these screens ask for exists in `en.ini`. Not verified: anything visual or interactive -- neither screen has been run in ITGmania.

### Verification

- Solo/pack follow-up (`codex/song-select-solo-and-pack-preview`): all Song Select Lua files compiled with Lua 5.1. An actor harness checked leaderboard alignment, adaptive panel heights, full-column score spacing, the separate personal row, and request guards; pack checks covered empty/small/large lists, 1,200 scrolling updates, row recycling, movie fallback, modal pause, song/course/sort transitions, and a stalled frame. In-game visual verification remains pending.
- Centered-panel follow-up (codex/center-sort-menu-panel): geometry checks passed at 1920x1080, 1280x720, 1024x768, and 2560x1080; nine rows, preview cards, and the current-selection block fit inside the panel. In-game visual verification remains pending.

- Lua 5.1 compilation passed for all seven Sort Menu files.
- A standalone harness checked the layout figures against the band they have to fit (15 checks, all passing): nine rows inside the content band, the list and panel not overlapping, the panel ending on the right margin, the preview cards clearing the selection block, the selection block clearing the footer, the cap-height zoom, the label floor, accented uppercasing in both directions, and a 40-step scroll in each direction over a 14-item list asserting the cursor never leaves the visible page and the page never runs past either end.
- A second harness ran `Descriptors.Describe` over 21 option shapes -- every sort family, categories open and empty, styles, both playlist kinds, favorites, each action, and an unknown option -- asserting each returns a complete descriptor, that the current pack leads the group preview, that the preview respects the card cap, and that a library with no genres greys `Genre` out.
- In-game visual and interactive verification was not performed.

## 0.1.1 - 2026-09-09

### Added

- Song Select's per-player chart card now shows the player's personal best for the hovered chart: an `ITG` row with the ITG percentage, the EX percentage in blue, and the grade badge, placed between the `STEP ARTIST` line and the density graph (`BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerChart.lua`). The density graph starts lower to make room and keeps the rest of the card's rhythm; the two-player card gives up graph height rather than pushing the tech and stats rows out of the panel.
- The grade badge is drawn from `Graphics/_grades/assets/` directly rather than by loading the evaluation grade actors, which spin, pulse and pull in their easter-egg layers. Tiers 00-04 render as a row of one to five stars; every other tier and `Grade_Failed` render as their letter graphic.
- Song Select's chart card now draws a beatmania IIDX-style notes radar in place of the `XO 5   FS 11` tech counter line (`BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerChart.lua`). Six axes, starting at the top vertex and running clockwise: `STREAM`, `XOVER`, `FOOTSWITCH`, `JACK`, `BRACKET`, `SIDESWITCH`. The polygon takes the difficulty colour, and an axis at half its cap or more colours its label the same way so the chart's defining trait is readable without counting rings. There is no heading: the axis labels already name the thing, and the line that used to say `NOTES RADAR` now appears only as `NO TECH DATA`, when there is nothing to draw.
- `VOLT26.ChartRadar` (`Scripts/VOLT26_ChartRadar.lua`): the axis definitions and the normalization behind that radar. Every axis is a fraction, so nothing on the radar depends on how long a chart is or what rate it is played at. The five tech axes are the category's count over the chart's total notes -- how much of this chart is that pattern -- each divided by a fixed per-axis cap (`Crossovers` and `Footswitches` 10%, `Jacks` and `Brackets` 6%, `Sideswitches` 3%), so two charts can be compared by shape rather than only against themselves. `STREAM` is the fraction of the charted span, first noted measure to last, that runs at 16ths or faster. `ChartRadar.Build` returns both the honest `Value` (0-1) and the `Scaled` value the polygon draws. Every cap and every display knob is a constant at the top of the module.
- Three display knobs shape what gets drawn between empty and full, because raw ratios compress badly at the bottom: real charts spend most of their axes in the first few percent, and drawn honestly the polygon collapsed into a dot that said less than the counter line it replaced. `displayGain` (1.35) multiplies the normalized reading, `displayGamma` (0.50) bends the curve so small readings lift hardest, and `baseRadius` (0.22) is the share of the radius every axis draws at even when it reads zero. The base exists because a chart whose only strong axis is `STREAM` -- which is most stamina charts -- otherwise draws as a single needle with no area at all; with it the shape always has a body and the peaks rise out of that. The cost is real and deliberate: an axis at zero is no longer distinguishable from a very low one. Only `Scaled` passes through these; `Value` stays the honest reading.
- `showRadarValues` in `PlayerChart.lua`, off by default: flip it to true and each axis prints its honest reading beside its label on the single-player card, so the caps can be retuned against real charts instead of by eye.
- `H.ChartData` (`BGAnimations/ScreenSelectMusic overlay/VOLT26/Layout.lua`) now collects raw tech counts (`data.techCounts`) and an availability flag (`data.techAvailable`) instead of pre-formatted `XO 5` strings, and adds `data.stream` and `data.radar`. The radar is built last, after the `RadarCategory` values, because the tech axes divide by `data.notes`. Course mode sums the tech counts and NPS data of every chart in the trail.
- `VOLT26.ScoreIndex` (`Scripts/VOLT26_ScoreIndex.lua`): a per-profile index of the best percent DP, grade, and EX percentage per chart, stored as `VOLT26-Scores/index.json` next to the exported score snapshots. `VOLT26.ScoreExport.WriteCurrent()` merges each snapshot it writes into the index, and the index rebuilds itself once from the snapshots already on disk when the file is missing or its schema version changed (capped at `MaxRebuildFiles` snapshots so a large profile cannot stall Song Select indefinitely).

### Changed

- Chart preview columns now use the gameplay style width scaled by note zoom, with larger note pools and a narrower background band.

- The single-player chart card is reorganised below the density graph, which now runs 92-160 at full width. Everything under it is one row: the note counts as a narrow left-hand column (`NOTES`, `JUMPS`, `HOLDS`, `MINES`, `ROLLS`, `HANDS`, one per line) and the radar filling the space to their right. `TAP + HOLD OBJECTS` is dropped, because it printed the same number as `NOTES`.
- The two-player card keeps its previous arrangement -- the counts on one line, a half-width density graph on the left, the radar on the right with two-letter axis labels -- because 152 units of height has no room for a six-row column, and dropping the density graph to make room would cost more than the consistency is worth. `graphVertices` now takes the graph's width as an argument rather than closing over a fixed one.

### Notes

- Stream detection approximates a chart with a single reference BPM, the fastest its timing data reports, because the engine's `GetNpsPerMeasure` gives NPS without the BPM in force at that measure. A slow section inside a fast chart therefore correctly reads as a break; a chart that plays 16ths only during its slowest section is the case this gets wrong. Courses and anything else without timing data fall back to the song's display BPM, and a chart with no BPM at all reports `STREAM` as 0 rather than guessing.
- The radar's caps are still tuned by eye rather than measured against a corpus. The first pass was far too generous -- in game the polygon was nearly invisible -- so the tech caps were halved and the display knobs added. They remain the first thing to revisit, and `showRadarValues` exists to make that a measurement rather than another guess.
- Measuring tech as a share of the chart's notes rather than as a rate per minute means a two-minute chart and a seven-minute one with the same patterns draw the same shape, and the music rate does not move the radar at all. What it cannot say is how *fast* that tech comes at the player: a 90 BPM chart that is one third crossovers reads exactly like a 190 BPM one. `STREAM` and the peak NPS above the radar are what carry speed.
- The radar hides itself and a `NO TECH DATA` line takes its place when `Steps:GetTechCounts` cannot answer at all. A chart the engine reports as having no tech still draws its hexagon, sitting at the base radius on every tech axis, because that is information too.
- Every radar shape is drawn as an `ActorMultiVertex` quad strip: filled areas are a fan of degenerate quads anchored on the centre, rings and outlines are a band between two radii, and the six spokes are rotated `Quad`s. Quad strips are the only draw mode this card already relied on, so the radar cannot fail in a way the density graph does not.
- The index is required because the engine cannot answer for EX. VOLT26 emulates the FA+ (W0) window from tap offsets during gameplay, and an engine `HighScore` stores only the aggregate W1 count, so the W0/W1 split needed for `VOLT26.Scoring.CalculateExScore` survives only in VOLT26's own exported snapshots. `VOLT26.ScoreIndex.GetBest()` therefore reads the ITG percentage and grade from the profile's engine high score list, and only the EX percentage from the index. A chart played before this change still shows its ITG percentage and grade, but shows `--` for EX until it is played again in VOLT26 with a persistent profile.

### Verification

- Release 0.1.1: Lua 5.1 compilation passed for all 11 Song Select VOLT26 modules and the radar, score index, and score export modules (14 files). Standalone radar checks passed for stream thresholds, internal breaks, empty input, chart-length normalization, and radius bounds. In-game visual verification was not performed for this release.

- `Scripts/VOLT26_ChartRadar.lua` was run against a standalone harness (50 checks, all passing) covering: the axis count and order, stream detection at, above and below the 16th threshold, empty leading and trailing measures being excluded from the span while an inner gap still counts as a break, a missing BPM and empty or non-table NPS data returning 0, tech counts read as a fraction of total notes, the same ratio at a different chart length giving the same reading, each axis using its own cap, clamping above a cap, the display curve only ever pushing a reading outwards and never past full, every axis including an untouched one drawing at no less than the base radius, a zero note count not dividing by zero, an empty or nil source still returning six axes, and a sweep asserting that no input -- empty, negative, or far over every cap -- can put a drawn radius outside the base ring or beyond the grid.
- The single-axis case was compared across four candidate treatments (polygon with vertex dots, per-axis wedges, a rounded polygon, and the base radius) on both a `STREAM`-only chart and a full one, drawn side by side. The rounded polygon was discarded on the evidence: a curve through five zeroes closes back onto the centre and vanishes in exactly the case it was meant to fix. The base radius was chosen, without the vertex dots.
- The tuning change was compared old against new on three hand-written chart profiles (a stamina stream chart, a tech chart, an easy chart) by drawing both polygons side by side. The three stay clearly distinguishable from each other under the new curve, which is the constraint that matters: lifting small readings must not saturate every chart into the same hexagon. The profiles are guesses, not measurements from real simfiles.
- The card layout was checked with an offline mock that reproduces the geometry of both card sizes and reports any text box that overlaps another or leaves the panel. Both sizes are clean with every axis at or near its cap, which is the widest the labels ever get. Text widths in that mock are estimated from the theme's own zoom and `maxwidth` values, not measured from the real font, so the margins it reports are approximate.
- Not verified in ITGmania: anything on screen. In particular the quad-strip radar shapes, `Steps:GetTechCounts` and `TimingData:GetActualBPM` behaving as assumed on the installed build, the real text metrics against the layout above, the two-player card, and course mode.
- Static Lua syntax checks completed (compiled with a Lua runtime) for `Scripts/VOLT26_ChartRadar.lua`, `BGAnimations/ScreenSelectMusic overlay/VOLT26/Layout.lua`, `Scripts/VOLT26_ScoreIndex.lua`, `Scripts/VOLT26_ScoreExport.lua`, and `BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerChart.lua`.
- `Scripts/VOLT26_ScoreIndex.lua` was additionally run against a standalone harness that stubs `PROFILEMAN`, `FILEMAN`, `RageFileUtil`, `lua.ReadFile` and the JSON helpers over an in-memory filesystem. 24 checks passed, covering: live and snapshot keys agreeing for the same chart, steps-type normalization, difficulties staying distinct, Edit descriptions being part of the key while other difficulties ignore them, a snapshot without a song directory producing no key, the rebuild reading every `.json` snapshot and skipping other files, best percent DP and best EX being tracked independently, the rebuilt index being written and reused instead of rescanning, a later worse run not lowering either best, `GetBest()` taking ITG percent and grade from the engine high score and EX from the index, the index fallback when the engine has no score (including short-to-full grade enum normalization), an unplayed chart returning nil, and a player without a persistent profile returning nil.
- Not verified in ITGmania: the on-screen row and badge, the index rebuild against a real profile directory, the snapshot merge after an actual play, course keys, the engine's own `JsonEncode`/`JsonDecode` round trip (the harness used its own JSON implementation), and the layout of the two-player card with its shorter density graph.

## 0.1.0 — 2026-09-07

### Added

- The title-screen tagline (`VOLT26.Brand.RandomTagline`) now sources player-submitted "name: message" lines from a local text file, `Other/PlayerMessages.txt` (one `Name: message` per line), via the new `VOLT26.PlayerMessages` module (`Scripts/VOLT26_PlayerMessages.lua`). The 4 built-in taglines remain only as a fallback for when that file is missing or empty.
- The file is re-read from disk from `BGAnimations/ScreenTitleMenu underlay/default.lua` on every title-screen visit, so an edit to `Other/PlayerMessages.txt` shows up the next time the tagline text is generated (taglines are chosen at ActorFrame construction time).
- A marquee/scroll effect for the title-screen tagline (`BGAnimations/ScreenTitleMenu underlay/default.lua`, the "EventPhrase" actor): a tagline whose natural (unzoomed) `GetWidth()` fits within the 405-unit box behaves exactly as before (static, centered, `maxwidth`-safeguarded). A tagline wider than that left-aligns, renders as a single unwrapped line (skips `maxwidth`, which word-wraps rather than scales -- see Fixed below), and scrolls left with `:linear(scrollTime):addx(-overflowPx):cropleft(f):cropright(f)` to reveal the tail, holds 1.6s at each end, then resets.

### Rejected approach

- Initially implemented as a live fetch from a public Google Sheet over `NETWORK:HttpRequest` (CSV export, then the `/gviz/tq?tqx=out:csv` endpoint after the `/export?format=csv` endpoint's 302-redirect turned out not to be followed by the engine). This does not work: ITGmania blocks outbound Lua HTTP requests to any host not listed in the `HttpAllowHosts` preference in `Preferences.ini` (default `*.groovestats.com,*.itgmania.com`), which is only editable by hand by the player/operator, not by a theme. Requests came back as `HttpErrorCode_Blocked` (confirmed in `Logs/log.txt`). Replaced with the local-file approach above; the Google Sheet can still serve as an editing "master copy" that gets copy/pasted into `Other/PlayerMessages.txt`.

### Fixed

- First marquee attempt made every tagline (even short ones) render blank. Root cause, found in `Logs/log.txt`: `SetUpdateFunction` was called on the tagline's `BitmapText` actor to recompute crop every frame, but that method only exists on `ActorFrame` -- the call threw and aborted the InitCommand before any positioning ran.
- Confirmed via a logged test message that `BitmapText:GetWidth()` is zoom-independent (identical value at zoom 1 and at 0.82) and that `maxwidth()` word-wraps onto multiple lines rather than auto-shrinking zoom (a wide test string left `GetZoomX()` unchanged after `maxwidth()` was applied) -- the marquee path measures width before calling `maxwidth()` and skips calling it at all once scrolling is chosen.
- Second attempt (`cropleft`/`cropright` tweened alongside the position) fixed the blank-render bug but produced a visibly wrong mask in-game: the "hidden" tail rendered anyway, spilling well past the box. `BitmapText` renders as separate glyph quads rather than one rectangle, and cropping it does not behave like masking a single sprite. Replaced with a crop-free approach: only the currently-visible **substring** of the message is ever passed to `settext()` (same technique `VOLT26.Text.WrapWidth` in `Scripts/VOLT26_Text.lua` already uses for incremental width measurement), sized to the box using the message's own average character width. A shared per-frame hook -- reused from the countdown ActorFrame's existing day-counter timer, since `BitmapText` doesn't support `SetUpdateFunction` but `ActorFrame` does -- steps the visible window forward to reveal the tail, holds, then slides back, holds, and repeats. Verified the hold/scroll/reverse state machine in isolation (a standalone Lua run) before this rewrite; not yet re-verified visually in ITGmania.
- The marquee's left-aligned anchor reused `EVENTPHRASE_HOME_X`, which was calibrated as the CENTER of the box for the original center-aligned static text. Left-aligning at that same x therefore started the visible text about half a box-width too far right ("starts from the center" -- seen in-game). Added `EVENTPHRASE_MARQUEE_LEFT_X` (home X minus half the box's rendered width) as the correct left-aligned anchor.
- The character-window size was first estimated from the message's average character width (`textWidth / #text`), which badly underestimated how many characters fit for this (non-monospace) font -- confirmed visually as unused room on the right of the box. Replaced with the same incremental `settext()` + `GetWidth()` measurement `VOLT26.Text.WrapWidth` already uses in `Scripts/VOLT26_Text.lua`, run once at Init.
- A fixed character-count window (even one measured precisely at the starting substring) could still overflow the box once the scroll reached a differently-shaped stretch of text -- confirmed visually: an all-"A" run in the test message was wider per character than the message's opening words, so the same window size overflowed there. The window is no longer a fixed length: `VOLT26_FitSubstring` (shared helper, declared once for both the countdown ActorFrame's update loop and `EventPhrase`'s InitCommand) recomputes, at every character step, the longest substring starting at the current position that still fits the box. Verified in isolation with a mock non-monospace font (wide vs. narrow characters) that the shown substring never exceeds the box across the full scroll range, and that the final position reaches exactly the end of the message.
- Song Select's song-search overlay reused the inherited Simply Love layout, whose spacing and zoom values are sized for `Common Normal`, while VOLT26 renders it with `Helvetica Normal`/`Helvetica Bold` (roughly 2.4x taller per zoom unit). The header, the search string, the result count, the result rows, the `Exit` label and the Pack/Song/Subtitle/BPMs/Difficulties column now apply the same `helveticaScale` (0.42) factor the sort menu already used, so the text no longer overlaps (`BGAnimations/ScreenSelectMusic overlay/SongSearch/default.lua`, `.../SongSearch/CandidateItemMT.lua`).
- The Song Select chart preview (`ChartPreviewLayer`, i.e. the preview backdrop plus the preview notefield) kept drawing on top of the sort menu, song search, leaderboard and input-test overlays, so receptors and quantized notes bled over those panels. The layer now stops drawing entirely while a modal overlay is open, driven by the new `VOLT26ModalOverlayOpened`/`VOLT26ModalOverlayClosed` broadcasts sent by the sort menu's shared enter/exit paths and by the song-search results, rather than depending on draw order. Those overlays also received an explicit draw order as a secondary guard (`.../VOLT26/Layout.lua`, `.../SortMenu/default.lua`, `.../SongSearch/default.lua`, `.../Leaderboard.lua`).

### Verification

- Static Lua syntax checks completed (compiled with a Lua runtime) for the changed/added files.
- Confirmed via `Logs/log.txt` that the rejected network approach was blocked by `HttpAllowHosts` (`WARNING: blocked access to https://docs.google.com/...`).
- Interactive verification in ITGmania of the local-file tagline AND the marquee effect (title screen render, file edit + revisit, a message long enough to trigger scrolling) not yet performed.
- Static Lua and metrics reference checks completed for the `0.1.0-rc.4` warm-up/`PerformanceMode` work; interactive verification on the target low-end arcade computer remains pending (no later note in this repository confirms that test occurred).
- The project owner verified both Song Select fixes interactively in ITGmania on 2026-09-08: the song-search overlay text no longer overlaps, and the chart preview no longer draws over the sort menu or the search results.

### Known follow-up

- The marquee's timing constants (hold time 1.6s, 0.12s per character step) are first-pass guesses, not yet tuned against real long messages by eye in ITGmania.
- `PerformanceMode` is not yet confirmed engine-verified on the target low-end arcade hardware.

## 0.1.0-rc.4 — 2026-09-02

### Added

- An incremental pre-intro warm-up screen for the shared VOLT26 presentation assets.
- `PerformanceMode`, an arcade-oriented presentation path that uses bounded texture preparation and lightweight opaque transitions.
- A first-run setup screen that explains and saves the choice between Performance and Enhanced before warm-up and intro loading begins.
- A Claude-ready project handoff and working guide.

### Changed

- VOLT26 now owns its presentation directly instead of selecting inherited visual styles at runtime.
- Title and Song Select prepare only their likely next screen groups while idle; song banners and jackets remain demand-loaded.
- The title presentation includes the VOLT26 letterbox/train composition and the Performance path avoids Full HD image-sequence handoffs.
- Hidden title-menu calendar actors are no longer constructed, idle warm-up is paced after Home settles, and non-visual engine polling is rate-limited without changing the visible design.
- The profile-loading transition keeps its black shade and diagonal red wipe but no longer renders loading text; Performance-mode Home exits reuse the same text-free wipe.

### Removed

- Inherited visual-style selection, style-specific assets, fallback banners, legacy presentation screens, and their associated menu music.

### Verification

- Static Lua and metrics reference checks completed.
- Interactive verification on the target low-end arcade computer remains pending.

## 0.1.0-rc.1 — 2026-08-25

### Added

- Standalone VOLT26 startup, navigation, profiles, options, song selection, gameplay, Evaluation, and Game Over routes.
- VOLT26-owned scoring, telemetry, chart analysis, result, session, failure, input-diagnostic, tournament, custom-song, and download-viewer boundaries.
- Optional bounded GrooveStats profile, leaderboard, QR-score, and eligible submission integration.
- Tournament Mode with EX/ITG display selection and safe `no cmod` CMod-to-MMod enforcement.
- USB-profile custom-song operator settings and setup documentation.

### Changed

- Difficulty graphs, names, and meters use the original Simply Love difficulty palette rather than player colors.
- Evaluation, summary, name-entry, and Game Over behavior no longer depend on the Simply Love visual-style bootstrap.
- Event result and download presentation remain available behind dormant provider-neutral boundaries.

### Removed or disabled

- Runtime dependency on an installed Simply Love theme.
- Casual Mode and Mementos Dash.
- QR login, automatic event archives, online lobbies, and hard-coded annual ITL persistence pending separate security and provider reviews.

### Compatibility

- Requires ITGmania 1.3.0 or newer.
- Designed for 16:9. Other aspect ratios retain functionality but may have visual alignment issues.
