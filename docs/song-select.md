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

## Pack step — `ScreenVOLT26SelectPack`

- `Scripts/VOLT26_PackSelection.lua` — CORE: `List`, `InitialIndex`, `Artwork`, `Summary`, `Choose`. No actors.
- `BGAnimations/ScreenVOLT26SelectPack overlay/default.lua` — carousel, details, input, menu timer.
- `BGAnimations/ScreenVOLT26SelectPack overlay/Tile.lua` — one square tile.

Input: Left/Right one pack, Up/Down five packs, Start opens, Back leaves. The carousel recycles nine tiles; only a tile that wraps from one end to the other gets a new pack. Artwork loads only once the carousel has been still for 0.08 s, nearest tiles first, and never for off-screen tiles.

Pack artwork, in order: a jacket the engine reports for the pack (when the build has `SONGMAN:GetSongGroupJacketPath`), an image in the pack folder named `jacket`, `cover`, `folder`, `jk`, `*jacket` or `* jk`/`*_jk`/`*-jk`, then the pack banner (drawn whole over a dimmed, cropped copy of itself). Movies are never used. A pack with none shows its initials.

## Song wheel — `ScreenSelectMusic`

- Wheel type `[VOLT26SongWheel]` (falls back to `[VOLT26MusicWheel]`): `OnlyShowActiveSection=true`, `HideActiveSectionTitle=true`, so only the chosen pack's songs are listed.
- Geometry: `VOLT26.MusicSelection.Wheel` in `Scripts/SL_Init.lua` (design units, 1920x1080).
- Rows: `Graphics/VOLT26/SongWheel/Row.lua`, loaded by the `MusicWheelItem * NormalPart` graphics. Highlight: `Graphics/MusicWheel highlight.lua`.
- Overlay: `BGAnimations/ScreenSelectMusic overlay/default.lua` with `SongWheel/State.lua` (engine reads), `Header.lua`, `SongInfo.lua`, `Charts.lua`, `PlayerPane.lua`, `Footer.lua`.
- Shared by both screens: `BGAnimations/_volt26 music kit.lua` (palette, text factories, artwork fitting, strings) and `BGAnimations/_volt26 music backdrop.lua`.
- Strings: `[VOLT26MusicSelect]` in `Languages/en.ini` and `Languages/it.ini`.

The Sort Menu, Quick Mods, input test, leaderboard and song search overlays and the behaviour actors (menu-timer preservation, modifier reapplication, AutoSetStyle) are loaded unchanged.

## Known limits

- Changing the sort from the Sort Menu keeps `OnlyShowActiveSection`, so a non-group sort shows only the open bucket (one letter, one BPM range, ...).
- The pack step runs its own menu-timer countdown from the Song Select timer value; time spent there is not deducted from the song wheel.
- The previous composition (`BGAnimations/ScreenSelectMusic overlay/VOLT26/`, `Graphics/VOLT26/SongSelection/MusicWheelItem*.lua`) is no longer loaded and can be removed once the rewrite is accepted.
