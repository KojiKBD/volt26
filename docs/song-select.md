# Music selection: pack step and song wheel

Music selection runs in two screens (branch `codex/song-select-rewrite`).

## Flow

| From | To | Owner |
| --- | --- | --- |
| Profile load (first entry of a set) | `ScreenVOLT26SelectPack` | `VOLT26.Navigation.EnterMusicSelection` via `Branch.AfterSelectPlayMode` |
| Pack step, Start | `ScreenSelectMusic` | pack overlay, after `VOLT26.PackSelection.Choose` |
| Pack step, Back | title or evaluation summary | `VOLT26.Navigation.LeaveMusicSelection` (event mode: Back twice within 2 s) |
| Song wheel, Back or close-folder buttons (`ClosePack` code) | `ScreenVOLT26SelectPack` | `VOLT26.Navigation.CancelMusicSelection` |
| Evaluation, options, reloads | `ScreenSelectMusic` on the current pack (the pack step instead when there is no current or preferred song) | `SelectMusicOrCourse` |
| Course mode | `ScreenSelectCourse`, no pack step | unchanged |

## One screen in appearance

The two screens are drawn to read as one screen:

- The pack step keeps the shared backdrop (`_volt26 music backdrop.lua`); the song wheel has its own scenery from the Persona-style mockup (see below) and no longer draws the `K.Chrome` bands.
- The chosen pack's jacket is shared.  Opening a pack shrinks the focused carousel jacket (560 units) into the song wheel's jacket frame (`K.Badge`: 284 units at 1678, 193) while the other jackets slide out to their side; the song wheel then slides in from the left and the details fade in.  Back reverses it: the wheel and details leave, and the pack step grows the jacket out of the badge back into the carousel.  The badge is the pack step's own `Tile.lua` zoomed down, so both ends of the motion are the same picture.
- The screen being left records the direction with `VOLT26.PackSelection.SetHandoff` (`"ToSongWheel"`, `"FromSongWheel"`); the screen being entered takes it once with `TakeHandoff` to choose its entrance.  Any other entry (profile load, returning from gameplay) has no hand-off and enters without that motion.
- `ScreenVOLT26SelectPack out.lua` and `ScreenSelectMusic cancel.lua` draw nothing and only hold for `K.HandoffHold` (0.36 s) so the motion finishes before the next screen replaces the current one.  The course wheel's cancel keeps the `_fade out normal` fade.
- Back on the song wheel is taken by an input callback in the overlay so the motion and the screen change start together; it is ignored while a modal overlay has the input (`SCREENMAN:get_input_redirected`, `VOLT26ModalOverlayOpened`) and once the selection is final.

## Pack step — `ScreenVOLT26SelectPack`

- `Scripts/VOLT26_PackSelection.lua` — CORE: `List`, `InitialIndex`, `Artwork`, `Summary`, `Songs`, `HardestMeter`, `Choose`, `SetHandoff`/`TakeHandoff`. No actors.
- `BGAnimations/ScreenVOLT26SelectPack overlay/default.lua` — carousel, details, input, menu timer.
- `BGAnimations/ScreenVOLT26SelectPack overlay/SongList.lua` — the back of the focused jacket: the pack's song list.
- `BGAnimations/ScreenVOLT26SelectPack overlay/Tile.lua` — one square jacket (`SetPack`, `LoadPackArt`), also used as the song wheel header badge.

Jackets fill their square edge to edge (artwork is cropped to it, banners included) with no name plate; the focused pack's name, song count, level range and place in the list are written under the carousel.  The focused jacket is 560 units and the others 500, so three and a half fit across the screen: the focused one, one either side and a quarter of the next on each edge.

The focused pack's name is drawn in the same cutout lettering as the profile names (`VOLT26.Cutout`, two slots used alternately so the old name stays until the new one has rendered; names over 64 characters fall back to plain text).

Input: Left/Right one pack, Up/Down five packs.  Holding a direction repeats after 0.3 s at the operator's MusicWheel scroll speed (`MusicWheelSwitchSpeed`, set under the VOLT26 options as MusicWheel Scroll Speed), counted in packs per second; the engine's own repeat events are not used.  Start turns the focused jacket over (`SongList.lua`): its back lists the pack's songs in title order with each song's hardest meter, ten at a time.  On the back, Up/Down scroll the list, Start opens the pack on the song wheel (the jacket turns face up while it flies to the badge), Back turns the jacket face up again and Left/Right turn it face up and move on.  Back on the carousel leaves. The carousel recycles nine tiles; only a tile that wraps from one end to the other gets a new pack. Artwork loads only once the carousel has been still for 0.08 s, nearest tiles first, and never for off-screen tiles.

Pack artwork, in order: a jacket the engine reports for the pack (when the build has `SONGMAN:GetSongGroupJacketPath`), an image in the pack folder named `jacket`, `cover`, `folder`, `jk`, `*jacket` or `* jk`/`*_jk`/`*-jk`, then the pack banner (loaded at full resolution and cropped to the square). Movies are never used. A pack with none shows its initials.

## Song wheel — `ScreenSelectMusic`

- Wheel type `[VOLT26SongWheel]` (falls back to `[VOLT26MusicWheel]`): `OnlyShowActiveSection=true`, `HideActiveSectionTitle=true`, so only the chosen pack's songs are listed.
- Geometry: `VOLT26.MusicSelection.Wheel` in `Scripts/SL_Init.lua` (design units, 1920x1080): rows on a slant, see "Persona-style layout".
- Rows: `Graphics/VOLT26/SongWheel/Row.lua`, loaded by the `MusicWheelItem * NormalPart` graphics. No highlight (`Graphics/MusicWheel highlight.lua` is empty): the overlay draws the focused row.
- Overlay: `BGAnimations/ScreenSelectMusic overlay/default.lua` with `SongWheel/State.lua` (engine reads) and the parts listed below.
- Shared by both screens: `BGAnimations/_volt26 music kit.lua` (palette, text factories, artwork fitting, strings) and `BGAnimations/_volt26 music backdrop.lua`.
- Strings: `[VOLT26MusicSelect]` in `Languages/en.ini` and `Languages/it.ini`.

The Sort Menu, Quick Mods, input test, leaderboard and song search overlays and the behaviour actors (menu-timer preservation, modifier reapplication, AutoSetStyle) are loaded unchanged.

## Persona-style layout (`codex/song-select-p5`)

The song wheel step follows the owner's Persona-style Illustrator mockup.

### What draws what

| Part | Where |
| --- | --- |
| Red ground, light, black left panel, slashes, shards, SELECT logo | `BGAnimations/ScreenSelectMusic background.lua` -> `overlay/SongWheel/Scene.lua` ("Back"), under the engine wheel |
| Song rows: "ARTIST - BPM" + RANK on a black band, the title on a white band, the song's highest meter as a badge | `Graphics/VOLT26/SongWheel/Row.lua` (every MusicWheelItem NormalPart) |
| Row placement on the slant, the hidden focused copy, the last row tipping over | `VOLT26.MusicSelection.Wheel` / `PositionWheelItem` in `Scripts/SL_Init.lua` |
| The focused row (larger, red band, difference-blend flags) | `overlay/SongWheel/Focus.lua` |
| Stars beside the focus, the jacket's white frame | `overlay/SongWheel/Scene.lua` ("Front") |
| Pack tile under the jacket (pack-step hand-off target, fallback art) | `overlay/SongWheel/Header.lua`, at `K.Badge` |
| Jacket (upright) and the song length in cutout lettering | `overlay/SongWheel/Jacket.lua` |
| Difficulty column with the P1/P2 squares | `overlay/SongWheel/Difficulty.lua` |
| Info panel: names (cutout), chart facts, notes radar, density graphs, stream measures | `overlay/SongWheel/Panel.lua` |
| Shared pieces, condensed text, meter badge and its palettes | `overlay/SongWheel/P5.lua` |
| Chart readings (NPS per measure, tech, radar, stream) | `S.ChartData` in `overlay/SongWheel/State.lua` |

#### Difficulty squares

Each chart of the song is a badge on a black square, easiest at the top.  A
chart nobody chose is dimmed.  One player on a chart: the whole square in
that player's colour (P1 red, P2 blue).  Both players on the same chart: the
square splits, red half for P1, blue half for P2.  The badge is recoloured
as if seen through the square (the mockup's exclusion blend): white turns
cyan under red and orange under blue.

#### Notes radar

The owner's star (docs/notes-radar.md).  One player: the gold star.  Two
players: P1's red star with P2's blue star over it, see-through and edged.
It depends on the notes radar work (`Scripts/VOLT26_ChartRadar.lua`,
`overlay/VOLT26/RadarArt.lua`, `Graphics/VOLT26/SongSelection/NotesRadar/`).

### Rebuilding the art

With the mockup open in Illustrator and its song select artboard active, run
from File > Scripts > Other Script... (Ctrl+F12):

1. `tools/song-select/export_song_select_art.jsx` -> `art/item_NN.png`, `items.json`, `composite.png`
2. `tools/song-select/export_song_select_parts.jsx` -> `art/part_*.png`, `parts.json`
3. `tools/song-select/export_meter_digits.jsx` -> `art/digits_boxed.png`, `art/digits_plain.png`
   (Source Serif Black boxed digit, Futura Bold plain digits)

Then `python tools/song-select/build_song_select_art.py` (Pillow, numpy)
writes `Graphics/VOLT26/SongSelect/` and `overlay/SongWheel/Art.lua`.  The
piece list follows the mockup's stacking order (`PIECES` in the script).

### Verification status

Lua syntax of every changed file, and a mock-engine run of the real files
(stubbed actors and game state, rendered offline) in one- and two-player
layouts.  Not yet run in ITGmania: blend of the digit ink layers, cutout
slots inside the scaled layout, the AMV radar edge (`DrawMode_LineStrip`),
wheel scrolling on the slant, and the pack-step hand-off into the jacket
frame.  The animation pass is still to come.

## Known limits

- Changing the sort from the Sort Menu keeps `OnlyShowActiveSection`, so a non-group sort shows only the open bucket (one letter, one BPM range, ...).
- The menu theme restarts each time the pack step is entered, and stops on the song wheel for the sample music.
- The pack step runs its own menu-timer countdown from the Song Select timer value; time spent there is not deducted from the song wheel.
- The previous composition (`BGAnimations/ScreenSelectMusic overlay/VOLT26/`, `Graphics/VOLT26/SongSelection/MusicWheelItem*.lua`) is no longer loaded and can be removed once the rewrite is accepted, except `overlay/VOLT26/RadarArt.lua`, which the info panel's notes radar reads.  The Simply Love style parts it replaced (`SongInfo.lua`, `Charts.lua`, `PlayerPane.lua`) are in `_to_delete/song-select-p5/`.
