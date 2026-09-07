# Changelog

All notable VOLT26 changes are documented here. Versions follow Semantic Versioning; release candidates use the `-rc.N` suffix.

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

### Verification

- Static Lua syntax checks completed (compiled with a Lua runtime) for the changed/added files.
- Confirmed via `Logs/log.txt` that the rejected network approach was blocked by `HttpAllowHosts` (`WARNING: blocked access to https://docs.google.com/...`).
- Interactive verification in ITGmania of the local-file tagline AND the marquee effect (title screen render, file edit + revisit, a message long enough to trigger scrolling) not yet performed.
- Static Lua and metrics reference checks completed for the `0.1.0-rc.4` warm-up/`PerformanceMode` work; interactive verification on the target low-end arcade computer remains pending (no later note in this repository confirms that test occurred).

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
