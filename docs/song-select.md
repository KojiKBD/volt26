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

- Same backdrop (`_volt26 music backdrop.lua`) and the same header and footer bands (`K.Chrome` in `_volt26 music kit.lua`): title, play mode and button hints sit in the same places, and only their words cross-fade.
- The chosen pack's jacket is shared.  Opening a pack shrinks the focused carousel jacket into the song wheel header badge (`K.Badge`: 72 units at 1036, 48) while the other jackets slide out to their side; the song wheel then slides in from the right and the details column from the left.  Back reverses it: the wheel and details leave, and the pack step grows the jacket out of the badge back into the carousel.  The badge is the pack step's own `Tile.lua` zoomed down, so both ends of the motion are the same picture.
- The screen being left records the direction with `VOLT26.PackSelection.SetHandoff` (`"ToSongWheel"`, `"FromSongWheel"`); the screen being entered takes it once with `TakeHandoff` to choose its entrance.  Any other entry (profile load, returning from gameplay) has no hand-off and enters without that motion.
- `ScreenVOLT26SelectPack out.lua` and `ScreenSelectMusic cancel.lua` draw nothing and only hold for `K.HandoffHold` (0.36 s) so the motion finishes before the next screen replaces the current one.  The course wheel's cancel keeps the `_fade out normal` fade.
- Back on the song wheel is taken by an input callback in the overlay so the motion and the screen change start together; it is ignored while a modal overlay has the input (`SCREENMAN:get_input_redirected`, `VOLT26ModalOverlayOpened`) and once the selection is final.

## Pack step — `ScreenVOLT26SelectPack`

- `Scripts/VOLT26_PackSelection.lua` — CORE: `List`, `InitialIndex`, `Artwork`, `Summary`, `Choose`. No actors.
- `BGAnimations/ScreenVOLT26SelectPack overlay/default.lua` — carousel, details, input, menu timer.
- `BGAnimations/ScreenVOLT26SelectPack overlay/Tile.lua` — one square jacket (`SetPack`, `LoadPackArt`), also used as the song wheel header badge.

Input: Left/Right one pack, Up/Down five packs, Start opens, Back leaves. The carousel recycles nine tiles; only a tile that wraps from one end to the other gets a new pack. Artwork loads only once the carousel has been still for 0.08 s, nearest tiles first, and never for off-screen tiles.

Pack artwork, in order: a jacket the engine reports for the pack (when the build has `SONGMAN:GetSongGroupJacketPath`), an image in the pack folder named `jacket`, `cover`, `folder`, `jk`, `*jacket` or `* jk`/`*_jk`/`*-jk`, then the pack banner (drawn whole over a dimmed, cropped copy of itself). Movies are never used. A pack with none shows its initials.

## Song wheel — `ScreenSelectMusic`

- Wheel type `[VOLT26SongWheel]` (falls back to `[VOLT26MusicWheel]`): `OnlyShowActiveSection=true`, `HideActiveSectionTitle=true`, so only the chosen pack's songs are listed.
- Geometry: `VOLT26.MusicSelection.Wheel` in `Scripts/SL_Init.lua` (design units, 1920x1080).
- Rows: `Graphics/VOLT26/SongWheel/Row.lua`, loaded by the `MusicWheelItem * NormalPart` graphics. Highlight: `Graphics/MusicWheel highlight.lua`.
- Overlay: `BGAnimations/ScreenSelectMusic overlay/default.lua` with `SongWheel/State.lua` (engine reads), `Header.lua` (pack badge, pack name, position), `SongInfo.lua`, `Charts.lua`, `PlayerPane.lua`.
- Shared by both screens: `BGAnimations/_volt26 music kit.lua` (palette, text factories, artwork fitting, strings) and `BGAnimations/_volt26 music backdrop.lua`.
- Strings: `[VOLT26MusicSelect]` in `Languages/en.ini` and `Languages/it.ini`.

The Sort Menu, Quick Mods, input test, leaderboard and song search overlays and the behaviour actors (menu-timer preservation, modifier reapplication, AutoSetStyle) are loaded unchanged.

## Known limits

- Changing the sort from the Sort Menu keeps `OnlyShowActiveSection`, so a non-group sort shows only the open bucket (one letter, one BPM range, ...).
- The menu theme restarts each time the pack step is entered, and stops on the song wheel for the sample music.
- The pack step runs its own menu-timer countdown from the Song Select timer value; time spent there is not deducted from the song wheel.
- The previous composition (`BGAnimations/ScreenSelectMusic overlay/VOLT26/`, `Graphics/VOLT26/SongSelection/MusicWheelItem*.lua`) is no longer loaded and can be removed once the rewrite is accepted.
