# VOLT26 Repository Map

## Purpose

This file is the compact starting point for repository work. Consult it before scanning the tree. It identifies every tracked workspace directory, explains where responsibilities live, and points to the smallest likely search area for common tasks.

Keep this map current whenever directories are added, removed, or given a materially different responsibility. File names in StepMania theme directories are part of the engine's lookup convention; a screen name followed by `background`, `underlay`, `overlay`, `decorations`, `in`, `out`, or `cancel` identifies that screen's corresponding actor or transition.

## Read First

- `AGENTS.md` and `.agents/`: authoritative project rules. The modules cover communication, development workflow, documentation, and security.
- `README.md`: requirements, installation, project status, language/display support, and documentation links.
- `docs/ai-handoff.md`: current architecture, active worktree cautions, working conventions, and testing constraints.
- `docs/simply-love-functional-inventory.md`: living map of inherited non-visual Simply Love behavior and migration decisions.
- `docs/standalone-architecture.md`: target dependency boundaries, core domains, screen groups, and integration order.
- `docs/standalone-theme-migration-plan.md`: phased migration and verification plan.
- `CHANGELOG.md`: user-visible history.
- `metrics.ini`: StepMania screen classes, flow, metrics, commands, and theme-wide engine configuration.
- `ThemeInfo.ini`: theme identity and metadata.

## Fast Lookup by Task

| Task | Start here | Then inspect |
| --- | --- | --- |
| Change screen flow or engine behavior | `metrics.ini` | The matching `BGAnimations/Screen...` path and shared code in `Scripts/` |
| Change shared theme behavior | `Scripts/` | `SL_Init.lua`, `SL-*.lua`, and `VOLT26_*.lua`; check the functional inventory |
| Change song selection | `BGAnimations/ScreenSelectMusic overlay/` | `Scripts/SL-SelectMusicHelpers.lua`, `Graphics/VOLT26/SongSelection/` |
| Change gameplay HUD or tracking | `BGAnimations/ScreenGameplay underlay/` and `BGAnimations/ScreenGameplay overlay/` | `Scripts/VOLT26_ScoreExport.lua` and relevant shared helpers |
| Change results/evaluation | `BGAnimations/ScreenEvaluation common/` | `ScreenEvaluationStage...`, `ScreenEvaluationSummary overlay/`, `Graphics/VOLT26/Eval/` |
| Change player or operator options | `BGAnimations/ScreenPlayerOptions...` or `ScreenOptionsService...` | `Scripts/SL-PlayerOptions.lua`, `Scripts/VOLT26_OperatorOptions.lua`, `metrics.ini` |
| Change profiles or name entry | `BGAnimations/ScreenSelectProfile...` or `ScreenNameEntryTraditional...` | `Scripts/SL-PlayerProfiles.lua` |
| Change title/menu presentation | `BGAnimations/ScreenTitleMenu...` | `Graphics/_logos/`, `Graphics/VOLT26/TransMenu*/` |
| Change translations | `Languages/<locale>.ini` | `Languages/en.ini` as the reference key set |
| Change fonts | `Fonts/` | Font `.ini` definitions, redirects, and source/licence notes |
| Change images or actor graphics | `Graphics/` | The Lua actor sharing the same StepMania element name |
| Change music or sound effects | `Sounds/` | `.redir` targets and screen-specific Lua selectors |
| Change documentation | `docs/` or `Other/Documentation/` | Developer docs go in `docs/`; end-user/operator guides go in `Other/Documentation/` |
| Build a distributable release | `tools/build-release.ps1` | `dist/` output and release instructions/history |

## Root Directories

- `.agents/`: authoritative instruction modules incorporated by `AGENTS.md`.
- `BGAnimations/`: screen actors, transitions, overlays, underlays, backgrounds, input handlers, and reusable actor modules. This is the main UI and screen-behavior tree.
- `dist/`: generated release/package output; do not treat it as source.
- `docs/`: developer-facing architecture, migration, integration, handoff, and repository-map documentation.
- `Fonts/`: bitmap/font definitions, redirects, bundled font families, character maps, and licence information.
- `Graphics/`: theme graphics and Lua-based graphical actors, including judgments, grades, cursors, wheel items, logos, and VOLT26 assets.
- `Languages/`: localized theme strings (`en`, `de`, `es`, `fr`, `it`, `ja`, `pl`, `pt-br`, and `ru`).
- `Modules/`: legacy/shared Simply Love module area; its current documentation is `Modules/README.md`.
- `Other/`: ancillary files that do not participate directly in theme lookup.
- `Scripts/`: globally loaded Lua runtime, preferences, helpers, navigation, online integrations, chart parsing, scoring, text/UTF-8 support, and VOLT26 utilities.
- `Sounds/`: screen music, sound effects, redirects, silence targets, and Lua sound selectors.
- `tools/`: maintainer tooling; currently release packaging.

## BGAnimations Directory Index

### Shared and reusable actors

- `BGAnimations/_modules/`: reusable UI modules; currently QR code generation, note-skin preview, high-score list, and test-input pad actors.
  - `_modules/QR Code/`: QR encoder and Simply Love QR actor.
  - `_modules/TestInput Pad/`: reusable pad-input display.
- `BGAnimations/_shared background/`: shared animated background implementation, shaders/models/textures, and rainbow mode.
- `BGAnimations/_fade in fast/`, `_fade in normal/`, `_fade out fast/`, `_fade out normal/`: standard transition actors.
- Root `_black.lua`, `_dark bg.lua`, `_prompt...`, `_volt26...`, `_wait.lua`, and `Screen in.lua`: generic backgrounds, prompt transitions, initialization handoff, backdrop, and wait/transition utilities.

### Startup, menus, profiles, and service screens

- `ScreenInit overlay/`: compatibility checks and initial theme startup.
- `ScreenTitleMenu underlay/`: title logo and user-content notice; adjacent root files handle title transitions/background.
- `ScreenTitleJoin`, `ScreenSelectStyle`, `ScreenSelectPlayMode`, `ScreenSelectPlayMode2`: joining and play-mode/style selection. Their `underlay/` directories contain the main layouts.
- `ScreenSelectProfile underlay/`: profile frames, player data, preview assets, scroller items, and input.
- `ScreenNameEntryTraditional underlay/`: name-entry UI, alphabet items, scores, player decoration, and input.
- `ScreenPlayerOptions overlay/`: main player options and row previews; adjacent PlayerOptions files cover common logic and transitions.
  - `OptionRowPreviews/`: previews for combo fonts, hold/judgment graphics, music rate, note skins, and variants.
- `ScreenOptionsService overlay/`: service menu layout, support information, and active-row behavior.
- `ScreenCRTTestPatterns underlay/`: CRT test-pattern UI; `patterns/` holds pattern assets.
- `ScreenEditMenu underlay/`: edit-menu layout and last-song state.
- `ScreenMemoryCard overlay/`, `ScreenMapControllers...`, `ScreenTestInput...`, `ScreenViewDownloads overlay/`: memory-card, controller mapping, input diagnosis, and download-status screens.
- `ScreenPrompt...`, `ScreenMiniMenu...`, `ScreenTextEntry...`: prompts, compact menus, and text entry.
- `ScreenVOLT26Warmup overlay/`: VOLT26 warm-up screen.

### Song selection

- `ScreenSelectMusic overlay/`: main song-selection UI and behavior: banner, leaderboard, pane display, modifiers, animation, input, and the default composition.
  - `PerPlayer/`: cursor, density graph, step artist, and per-player composition.
  - `SongDescription/`: song descriptions and group-duration information.
  - `SongSearch/`: search settings, candidate rows, input, and search UI.
  - `SortMenu/`: sort/test/leaderboard input handlers and wheel item actor.
  - `StepsDisplayList/`: chart list, grid, course contents, and chart-selection logic.
    - `TabbedStepchartList/`: tabbed chart list implementation.
  - `VOLT26/`: VOLT26-specific selection layout: frame, banner, group preview, difficulty strip, chart preview, player chart/name, song info, and preview backdrop.
- Adjacent `ScreenSelectMusic background.lua`, `out.lua`, `cancel.redir`, and casual-mode redirect provide screen lifecycle pieces.
- `ScreenSelectColor...`: theme color selection.

### Gameplay

- `ScreenGameplay in/`: entry transition and measure-counter/mod-level preparation.
- `ScreenGameplay underlay/`: gameplay HUD composition.
  - `Shared/`: header, song info, BPM display, and versus statistics.
  - `PerPlayer/`: per-player HUD, difficulty, danger, background filter, score, graphs, tournament mode, and note-field/statistics components.
    - `LifeMeter/`: standard, surround, and vertical life meters.
    - `NoteField/`: note-field decoration, column cues, miss flash, mod display, measure counter, and subtractive scoring.
      - `ErrorBar/`: colorful, monochrome, default, and text error-bar variants.
    - `StepStatistics/`: judgments, scorebox, time, banner, holds/mines/rolls, density graph, and background.
    - `TargetScore/`: target setup, pacemaker, graphs, background, and missed-target action.
- `ScreenGameplay overlay/`: runtime tracking and control: offsets, per-column judgments, EX score, fail time, winner, play time, hold-start failure, and overlay composition.
- `ScreenGameplay next course song/`: course transition and speed-mod changes.
- Adjacent gameplay files provide background, cancellation, exit, and toasty actors.
- `ScreenPractice...`: practice-mode overlay and underlay.

### Evaluation and session end

- `ScreenEvaluation common/`: shared results-screen composition and input.
  - `Panes/`: pane controller and eight pane implementations for judgments, percentages, arrows, calculations, and GrooveStats URL data.
  - `PerPlayer/Lower/`: graphs, scatter plot, modifiers, and disqualification state.
  - `PerPlayer/Upper/`: grade, records, difficulty, step artist, stream breakdown, event progress, and player composition.
  - `PerPlayer/Storage.lua`: per-player evaluation state.
  - `Shared/`: score submission, favorites, screenshots, global storage, diagnostics, events, song features, banner/title, and help text.
- `ScreenEvaluationStage in/`: STANDARD/VOLT26 evaluation entry variants.
- `ScreenEvaluationSummary overlay/`: summary rows, player stats, and grades.
- Adjacent `ScreenEvaluation...` files cover stage, nonstop, background, decorations, and exit.
- `ScreenGameOver overlay/`: game-over profile avatars and player statistics; adjacent file provides background.
- `ScreenPlayAgain...`: replay/continue screen.
- `ScreenProfileLoad...` and `ScreenProfileSave...`: profile lifecycle feedback.

### Online and secondary screens

- `ScreenGrooveStatsLogin underlay/`: GrooveStats login screen.
- `ScreenOnlineLobbies overlay/`: lobby list and lobby information.
- `ScreenAttackMenu`, `ScreenBookkeeping`, `ScreenDemonstration`, `ScreenEdit`, `ScreenEditOptions`, `ScreenHeartEntry`, `ScreenLogo`, `ScreenOverscanConfig`, `ScreenRankingSingle/Double`, `ScreenRainbow`, `ScreenReloadSongs/SSM`, `ScreenSetBGFit`, and `ScreenSystemLayer`: self-contained or redirected secondary StepMania screens named by their engine screen.

## Graphics Directory Index

- `Graphics/_FallbackBanners/VOLT26/`: fallback banner artwork for VOLT26.
- `Graphics/_grades/`: Lua grade actors; `assets/` contains their supporting images.
- `Graphics/_HoldJudgments/`: hold-judgment image variants.
- `Graphics/_judgments/`: tap-judgment image variants.
- `Graphics/_logos/kb7/`: KB7 logo actor/assets.
- `Graphics/Combo 100milestone/` and `Combo 1000milestone/`: combo milestone actors/assets.
- `Graphics/MusicWheelItem Grades/`: grade display inside wheel items.
- `Graphics/MusicWheelItem Song NormalPart/`: normal song wheel item plus favorites/unlock indicators.
- `Graphics/VOLT26/`: VOLT26-specific visual assets.
  - `Calendar/Days/` and `Calendar/ToD/`: calendar and time-of-day assets.
  - `Eval/`: evaluation artwork; `defeat_animation_res/`, `tyt_res/`, and `victory_animation_res/` contain animation resources.
  - `Fonts/Helvetica Bold/`: graphics-local font assets.
  - `Song_Select_Animation/`: song-selection animation resources.
  - `SongSelection/`: native/custom music-wheel actor implementations and song-selection assets.
  - `Stars/`: star/rating assets.
  - `TransMenu/` and `TransMenu2/`: menu transition resources.
- Root `Graphics/` files named after StepMania elements supply headers, footers, option rows/cursors/underlines, banners, player judgments/combo, ranking rows, prompts, and wheel highlights.

## Fonts Directory Index

- `Fonts/_Combo Fonts/`: selectable combo-font families: Arial Rounded, Asap, Bebas Neue, Source Code, VOLT26, Wendy, Wendy (Cursed), and Work. Each family contains its definition and usually a source note.
- `Fonts/16px fonts/`: common 16-pixel UI, game-character, miscellaneous, and emoji font definitions.
- `Fonts/CJK/Japanese/`: Japanese character font definition.
- `Fonts/Miso/`: Miso definitions, notes, and `Licenses/`.
- `Fonts/P5hatty/`, `Fonts/Persona/`, and `Fonts/Wendy/`: named display/UI font definitions.
- Root `Fonts/` files define common, Helvetica, menu timer, screen-specific, fallback, Eurostile, and redirect mappings.

## Other Directory Index

- `Other/Documentation/`: operator/end-user guides for installation, USB custom songs, profile avatars, StepMania troubleshooting, and USB polling issues.

## Scripts File Index

- `SL_Init.lua`: shared initialization entry point.
- `99 SL-ThemePrefs.lua`: theme preference definitions and persistence.
- `SL-Colors.lua`, `SL-Layout.lua`: shared colors and layout constants/helpers.
- `SL-Helpers.lua`, `SL-Helpers-GrooveStats.lua`, `06 VOLT26-Utilities.lua`: general and integration-specific utilities.
- `SL-PlayerProfiles.lua`, `SL-PlayerOptions.lua`: profile and player-option behavior.
- `SL-SelectMusicHelpers.lua`, `Consensual-sick_wheel.lua`: music-selection and wheel behavior.
- `SL-ChartParser.lua`, `SL-BPMDisplayHelpers.lua`, `SL-Histogram.lua`: chart metadata, BPM display, and density/histogram calculations.
- `SL-OnlineHelpers.lua`, `SL_ITL.lua`: online and ITL/tournament behavior.
- `VOLT26_Brand.lua`, `VOLT26_Navigation.lua`, `VOLT26_OperatorOptions.lua`: branding, screen routing, and operator settings.
- `VOLT26_ScoreExport.lua`: score collection/export responsibilities.
- `VOLT26_Text.lua`, `VOLT26_UTF8.lua`: text handling and UTF-8 support.
- `VOLT26_Warmup.lua`: warm-up feature logic.

## Sounds Directory Index

- `Sounds/_common menu music/`: default common menu-music selector.
- `Sounds/ScreenEvaluationMusic/`: evaluation-music configuration and instructions.
- `Sounds/VOLT26/`: VOLT26-specific audio assets.
- Root `Sounds/` files are StepMania screen/element sound lookups. Most `.redir` files point to shared audio; `.lua` files choose or generate sound behavior.

## Maintenance Notes

- Search by exact StepMania screen or element name before scanning a whole asset tree.
- A `.redir` file is an indirection: inspect its target before changing or duplicating an asset.
- Keep behavior documentation separate from presentation. Update `docs/simply-love-functional-inventory.md` when inherited functionality is assessed, adopted, replaced, omitted, or synchronized.
- Verify generated `dist/` contents through the release tool; edit source directories instead of generated output.
- This map intentionally describes locations and responsibilities, not implementation details. Open only the listed target files needed for the current task.

## Exhaustive Directory Manifest

This is the literal directory inventory at the time of this map's last update. `.git/` is intentionally excluded because it is Git's internal database, not project content.

```text
.agents/
BGAnimations/
  _modules/
    QR Code/
    TestInput Pad/
  _shared background/
  ScreenCRTTestPatterns underlay/
    patterns/
  ScreenEditMenu underlay/
  ScreenEvaluation common/
    Panes/
      Pane1/
      Pane2/
      Pane3/
      Pane4/
      Pane5/
      Pane6/
      Pane7/
      Pane8/
    PerPlayer/
      Lower/
      Upper/
    Shared/
  ScreenEvaluationStage in/
  ScreenEvaluationSummary overlay/
  ScreenGameOver overlay/
  ScreenGameplay in/
  ScreenGameplay next course song/
  ScreenGameplay overlay/
  ScreenGameplay underlay/
    PerPlayer/
      LifeMeter/
      NoteField/
        ErrorBar/
      StepStatistics/
      TargetScore/
    Shared/
  ScreenGrooveStatsLogin underlay/
  ScreenInit overlay/
  ScreenMemoryCard overlay/
  ScreenNameEntryTraditional underlay/
  ScreenOnlineLobbies overlay/
  ScreenOptionsService overlay/
  ScreenPlayerOptions overlay/
    OptionRowPreviews/
  ScreenSelectMusic overlay/
    PerPlayer/
    SongDescription/
    SongSearch/
    SortMenu/
    StepsDisplayList/
      TabbedStepchartList/
    VOLT26/
  ScreenSelectPlayMode underlay/
  ScreenSelectProfile underlay/
  ScreenSelectStyle underlay/
  ScreenTitleMenu underlay/
  ScreenViewDownloads overlay/
  ScreenVOLT26Warmup overlay/
dist/
docs/
Fonts/
  _Combo Fonts/
    Arial Rounded/
    Asap/
    Bebas Neue/
    Source Code/
    VOLT26/
    Wendy/
    Wendy (Cursed)/
    Work/
  16px fonts/
  CJK/
    Japanese/
  Miso/
    Licenses/
  P5hatty/
  Persona/
  Wendy/
Graphics/
  _FallbackBanners/
    VOLT26/
  _grades/
    assets/
  _HoldJudgments/
  _judgments/
  _logos/
    kb7/
  Combo 1000milestone/
  Combo 100milestone/
  MusicWheelItem Grades/
  MusicWheelItem Song NormalPart/
  VOLT26/
    Calendar/
      Days/
      ToD/
    Eval/
      defeat_animation_res/
      tyt_res/
      victory_animation_res/
    Fonts/
      Helvetica Bold/
    Song_Select_Animation/
    SongSelection/
    Stars/
    TransMenu/
    TransMenu2/
Languages/
Modules/
Other/
  Documentation/
Scripts/
Sounds/
  _common menu music/
  ScreenEvaluationMusic/
  VOLT26/
tools/
```
