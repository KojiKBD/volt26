# Simply Love Functional Inventory for VOLT26

## Purpose

This living document tracks non-visual Simply Love behavior that may need to be retained, adapted, replaced, or omitted as VOLT26 becomes a standalone ITGmania theme. It deliberately excludes purely decorative assets and styling. Mixed features are included when their source combines behavior and presentation.

## Status and decision vocabulary

**Decision**

- `Assess`: investigation or project-owner decision is still required.
- `Adopt`: retain the behavior with minimal semantic change.
- `Adapt`: retain the behavior but integrate it into VOLT26 architecture or UX.
- `Replace`: implement the same user need differently.
- `Omit`: intentionally exclude it and document the rationale.

**Implementation status**

- `Not started`
- `In progress`
- `Implemented`
- `Verified`

## Inventory entry requirements

Before an item is considered complete, record:

- the upstream Simply Love tag or commit reviewed;
- behavioral responsibility and user-visible result;
- source landmarks and important dependencies;
- persisted preferences or profile data;
- the VOLT26 decision and rationale;
- the implementation branch and VOLT26 destination;
- automated checks, manual verification steps, and result.

## Initial capability map

This is a first-pass map based on the current inherited tree. Source-level dependency tracing and owner decisions remain Phase 1 work.

| ID | Non-visual capability | Primary source landmarks | Decision | Status |
| --- | --- | --- | --- | --- |
| CORE-01 | Theme initialization and shared runtime state | `Scripts/SL_Init.lua`, `Scripts/06 SL-Utilities.lua` | Assess | Not started |
| CORE-02 | ITGmania compatibility validation and startup failure handling | `Scripts/SL-SupportHelpers.lua`, `BGAnimations/ScreenInit overlay/CompatibilityChecks.lua`, `BGAnimations/ScreenInit overlay/default.lua` | Assess | Not started |
| CORE-03 | Theme preference definitions, defaults, loading, and saving | `Scripts/99 SL-ThemePrefs.lua` | Assess | Not started |
| CORE-04 | Screen branching and navigation decisions | `Scripts/SL-Branches.lua`, screen metrics in `metrics.ini` | Assess | Not started |
| CORE-05 | Shared helper, text, UTF-8, and support utilities | `Scripts/SL-Helpers.lua`, `Scripts/SL-Helpers-Text.lua`, `Scripts/utf8.lua`, `Scripts/SL-SupportHelpers.lua` | Assess | Not started |
| PROFILE-01 | Player profile discovery, selection, and profile-derived state | `Scripts/SL-PlayerProfiles.lua`, `BGAnimations/ScreenSelectProfile underlay/` | Assess | Not started |
| OPTIONS-01 | Player option construction and persistence | `Scripts/SL-PlayerOptions.lua`, `BGAnimations/ScreenPlayerOptions*` | Assess | Not started |
| OPTIONS-02 | Operator/service options and active option-row behavior | `Scripts/SL-OperatorMenuOptions.lua`, `BGAnimations/ScreenOptionsService overlay/` | Assess | Not started |
| SELECT-01 | Music selection state and helper logic | `Scripts/SL-SelectMusicHelpers.lua`, `BGAnimations/ScreenSelectMusic overlay/` | Assess | Not started |
| SELECT-02 | Song search, filtering, sorting, and wheel behavior | `BGAnimations/ScreenSelectMusic overlay/SongSearch/`, `SortMenu/`, `Scripts/Consensual-sick_wheel.lua` | Assess | Not started |
| SELECT-03 | Favorite-song persistence and handling | `Scripts/SL-FavoritesHandler.lua` | Assess | Not started |
| SELECT-04 | Chart metadata parsing and derived chart information | `Scripts/SL-ChartParser.lua`, `Scripts/SL-ChartParserHelpers.lua` | Assess | Not started |
| SELECT-05 | Casual mode group, song, and option selection | `BGAnimations/ScreenSelectMusicCasual overlay/`, `Other/CasualMode-*.txt` | Assess | Not started |
| GAME-01 | Custom score calculation and score-state management | `Scripts/SL-CustomScores.lua` | Assess | Not started |
| GAME-02 | Judgment-offset and per-column judgment tracking | `BGAnimations/ScreenGameplay overlay/JudgmentOffsetTracking.lua`, `PerColumnJudgmentTracking.lua` | Assess | Not started |
| GAME-03 | EX judgment tracking and subtractive scoring | `BGAnimations/ScreenGameplay overlay/TrackExScoreJudgments.lua`, `BGAnimations/ScreenGameplay underlay/PerPlayer/NoteField/SubtractiveScoring.lua` | Assess | Not started |
| GAME-04 | Failure behavior, fail timing, and hold-start failure rules | `BGAnimations/ScreenGameplay overlay/TrackFailTime.lua`, `FailOnHoldStart.lua` | Assess | Not started |
| GAME-05 | Gameplay statistics, density, measure counters, and timing data | `BGAnimations/ScreenGameplay underlay/PerPlayer/StepStatistics/`, `NoteField/MeasureCounter.lua`, `Scripts/SL-Histogram.lua` | Assess | Not started |
| GAME-06 | Target-score, pacemaker, and missed-target actions | `BGAnimations/ScreenGameplay underlay/PerPlayer/TargetScore/` | Assess | Not started |
| GAME-07 | Course-song speed changes and inter-song behavior | `BGAnimations/ScreenGameplay next course song/` | Assess | Not started |
| GAME-08 | Two-player comparison and current-winner calculation | `BGAnimations/ScreenGameplay overlay/WhoIsCurrentlyWinning.lua`, `underlay/Shared/VersusStepStatistics.lua` | Assess | Not started |
| EVAL-01 | Evaluation state aggregation and cross-screen storage | `BGAnimations/ScreenEvaluation common/PerPlayer/Storage.lua`, `Shared/GlobalStorage.lua` | Assess | Not started |
| EVAL-02 | Records, grade, percentage, judgment, and stream calculations | `BGAnimations/ScreenEvaluation common/Panes/`, `PerPlayer/Upper/`, `Scripts/SL-CustomScores.lua` | Assess | Not started |
| EVAL-03 | Evaluation graphs, scatter plots, and derived performance analysis | `BGAnimations/ScreenEvaluation common/PerPlayer/Lower/`, `Scripts/SL-Histogram.lua` | Assess | Not started |
| EVAL-04 | Screenshot capture and evaluation exit/input handling | `BGAnimations/ScreenEvaluation common/Shared/ScreenshotHandler.lua`, `ExitHandler.lua`, `EventInputHandler.lua` | Assess | Not started |
| ONLINE-01 | GrooveStats helpers, URLs, QR codes, and score submission | `Scripts/SL-Helpers-GrooveStats.lua`, `SL-OnlineHelpers.lua`, `BGAnimations/_modules/QR Code/`, `ScreenEvaluation common/Shared/AutoSubmitScore.lua` | Assess | Not started |
| EVENT-01 | Event progress and event-mode evaluation behavior | `BGAnimations/ScreenEvaluation common/Shared/EventOverlay.lua`, `PerPlayer/Upper/EventProgress.lua` | Assess | Not started |
| EVENT-02 | Tournament and ITL-specific behavior/files | `BGAnimations/ScreenGameplay underlay/PerPlayer/TournamentMode.lua`, `Scripts/SL_ITL.lua`, `ScreenEvaluation common/PerPlayer/ItlFile.lua` | Assess | Not started |
| CONTENT-01 | Custom-song loading and removable-media workflow | `Other/Documentation/CustomSongsFromUSB-README.md`, related screen and metric configuration | Assess | Not started |
| SERVICE-01 | Input diagnostics and pad testing | `BGAnimations/_modules/TestInput Pad/`, related service screens | Assess | Not started |
| SERVICE-02 | Download-view navigation and item handling | `BGAnimations/ScreenViewDownloads overlay/` | Assess | Not started |
| SESSION-01 | Gameplay/session duration and game-over player statistics | `BGAnimations/ScreenGameplay overlay/TrackTimeSpentInGameplay.lua`, `BGAnimations/ScreenGameOver overlay/` | Assess | Not started |

## Phase 1 source scan progress

The source scan records what the inherited implementation does before the project owner makes a retention decision. A completed source scan does not change an item's implementation status.

| Scan group | Upstream baseline | Coverage | Result |
| --- | --- | --- | --- |
| Core runtime | `dd06138b15492f4136796dfe4b6708ced0f7b9eb` | `CORE-01` through `CORE-05` | Source scan complete; owner decisions and runtime verification pending |
| Profiles and options | `dd06138b15492f4136796dfe4b6708ced0f7b9eb` | `PROFILE-01`, `OPTIONS-01`, and `OPTIONS-02` | Source scan complete; owner decisions and runtime verification pending |

## Core runtime assessment

### CORE-01 — Theme initialization and shared runtime state

- **Behavioral responsibility:** creates the global `SL` namespace, per-player state, per-game-cycle state, timing/scoring/life constants, EX weights, GrooveStats service state, request/download caches, and reset behavior. `InitializeSimplyLove()` resets both players and the game-cycle globals at script load and again when the title menu is entered.
- **Important dependencies:** `ThemePrefs`; `PREFSMAN`; `Branch.GameplayScreen()`; `CreateGrooveStatsPlayerOptionKeys()` from the GrooveStats helper; `LoadUnlocksCache()` from the GrooveStats helper; engine globals and enum helpers. Script load order is therefore part of the contract.
- **State boundaries:** player option selections, parsed chart caches, evaluation pane choices, API-session data, favorites, stage statistics, active rate, stage/continue counters, screen-return targets, timers, screenshot texture, and session timing are held in memory. Theme preferences and the GrooveStats unlock cache are read from persistent storage by dependencies; `SL_Init.lua` does not save them directly.
- **VOLT26 delta:** `Scripts/SL_Init.lua` is source-identical to the reviewed upstream baseline. VOLT26 currently consumes this broad shared object without an owned interface.
- **Mixed responsibilities:** visual color tables live beside scoring constants, online state, navigation state, and player/session data. These responsibilities should be separated during the standalone foundation work even if compatibility aliases are temporarily retained.
- **Recommended decision:** `Adapt` — retain reset semantics and the state required by accepted features, move it behind VOLT26-owned runtime modules, and remove state belonging to omitted features.
- **Verification pending:** start the theme, return to the title menu after a completed game cycle, and confirm that transient player/session/stage state resets while persistent theme/profile settings remain intact; repeat for one and two players.

### CORE-02 — Compatibility validation and startup failure handling

- **Behavioral responsibility:** parses the engine version, accepts only ITGmania `1.3.0` or newer, accepts the `dance`, `pump`, `techno`, `para`, and `kb7` game types, and redirects unsupported configurations to `ScreenSystemOptions` with a localized system message. It also prevents the Thonk visual style from running under the Windows D3D render path that lacks render-to-texture support.
- **Important dependencies:** `ProductFamily()`, `ProductVersion()`, `GAMESTATE`, `HOOKS`, `PREFSMAN`, `SCREENMAN`, localized `ScreenInit`/theme-option strings, the `SM()` system-message utility, and `ScreenSystemOptions`/`ScreenThemeOptions` metrics.
- **State and persistence:** no direct persistence. The result depends on engine preferences such as the active game and video renderer.
- **VOLT26 delta:** `SL-SupportHelpers.lua` and `CompatibilityChecks.lua` are source-equivalent to upstream. The VOLT26 `ScreenInit` intro is presentation-specific but still loads the upstream compatibility actor. Its `_G.Volt26InitHandoff` flag is a separate transient navigation/presentation handoff and is not part of the compatibility behavior.
- **Mixed responsibilities:** the Thonk render-to-texture guard is visual-style-specific and should not move into standalone VOLT26 unless VOLT26 adopts a feature with the same renderer requirement. Theme-version and author readers in `SL-SupportHelpers.lua` are metadata helpers, not compatibility checks.
- **Recommended decision:** `Adapt` — retain the early engine/game guard, replace Simply Love wording and supported-version policy with a VOLT26-owned compatibility contract, and omit the Thonk-only branch unless independently required.
- **Verification pending:** boot on the minimum supported ITGmania version and one newer version; simulate an older version and unsupported game; confirm one actionable message and a safe redirect without a Lua error.

### CORE-03 — Theme preferences

- **Behavioral responsibility:** defines theme-wide defaults and option-row values, initializes fallback `ThemePrefs`/`ThemePrefsRows`, validates saved values by type and allowed-value membership, removes unknown keys, and saves the current theme section to `Save/ThemePrefs.ini`.
- **Important dependencies:** fallback-theme `ThemePrefs.InitAll()`, `ThemePrefsRows`, `IniFile`, date functions, localized strings, `range()`, `map()`, and `FindInTable()` from `06 SL-Utilities.lua`.
- **Persistent data:** navigation toggles; game/style/sort defaults; menu timers; color and visual-style choices; sampling, banner, keyboard, scoring, tournament, GrooveStats, unlock, QR-login, and lobby settings; edit-mode history; event state. VOLT26 adds `VOLT26MementosDashHighScore` and the `VOLT26` visual-style choice.
- **VOLT26 delta:** the current file differs from upstream only by registering the VOLT26 visual style and persisting the Mementos Dash high score. The current storage section is derived from `THEME:GetCurThemeName()`, so changing standalone theme identity also changes preference ownership.
- **Mixed responsibilities:** a single registry couples core navigation and timing preferences to visual styles, optional online services, tournament behavior, an event unlock, and a minigame score. `VisualStyle` becomes obsolete when VOLT26 is no longer a Simply Love visual style.
- **Recommended decision:** `Adapt` — create a VOLT26-owned preference registry, preserve accepted keys with an explicit migration/default policy, split optional-feature preferences by domain, and retire `VisualStyle` checks from runtime branching.
- **Verification pending:** load valid legacy values, invalid types, invalid enum values, and unknown keys; restart ITGmania; verify accepted values persist under the VOLT26 section and invalid/retired values migrate or reset as documented.

### CORE-04 — Screen branching and navigation decisions

- **Behavioral responsibility:** selects profile/login/color/style/play-mode screens; applies game-mode preferences and reloads metrics; routes music/course selection, options, gameplay, evaluation, profile save, name entry, continues, game over, and title return; reconciles stage cost with music rate; and checks available credits for continues.
- **Important dependencies:** `ThemePrefs`, `SL.Global`, `GAMESTATE`, `PREFSMAN`, `PROFILEMAN`, `STATSMAN`, `SCREENMAN`, `THEME`, `MESSAGEMAN`, `GetCredits()`, `SetGameModePreferences()`, and fallback `Branch.AfterInit()`, `Branch.TitleMenu()`, and `Branch.GameplayScreen()` functions. Corresponding `metrics.ini` `PrevScreen`/`NextScreen` values form part of the route graph.
- **State and persistence:** mutates joined players/current style, `SL.Global.GameMode`, stage and continue counters, and player-option return targets. It reads persistent theme and engine preferences but does not save them.
- **VOLT26 delta:** VOLT26 adds one branch: when `VisualStyle == "VOLT26"`, Casual/ITG selection is skipped, `SL.Global.GameMode` is forced to `ITG`, and normal post-selection preference/metric setup continues. All other branch behavior is upstream.
- **Mixed responsibilities:** optional-screen UX, coin-op policy, online login, stage accounting, profile persistence, gameplay mode selection, and end-of-session policy are combined in one module. Stage accounting belongs with session/gameplay behavior even though it currently controls navigation.
- **Recommended decision:** `Adapt` — define a VOLT26 route graph and explicit supported modes, retain only accepted coin/profile/session policies, and replace the temporary `VisualStyle` condition with standalone defaults.
- **Verification pending:** exercise the complete startup-to-title-to-profile-to-music-to-options-to-gameplay-to-evaluation route for one and two players, plus course, event, cancel, fail, continue, name-entry, and game-over branches.

### CORE-05 — Shared helpers, text, UTF-8, and support utilities

- **Behavioral responsibility:** provides generic table/system-message helpers (`TableToString`, `SM`, `range`, `map`, `deduplicate`, and lookup/string conversion), UTF-8 string primitives, emoji diffusion, multilingual wrapping/truncation, engine/metadata support helpers, and a large inherited `SL-Helpers.lua` collection.
- **Important dependencies:** Lua string/table APIs; StepMania actor types and global managers; fallback utility functions; `SL`, `ThemePrefs`, `Branch`, and theme asset/metric lookup. `SL-Helpers-Text.lua` monkey-patches `BitmapText`, so its load order and global effect are part of the contract.
- **State and persistence:** generic utilities are stateless. Several functions in `SL-Helpers.lua` read or mutate engine preferences and runtime player state; `ResetPreferencesToStockSM5()` is state-changing and must not be treated as a harmless formatting helper.
- **VOLT26 delta:** `SL-Helpers.lua` and `SL-SupportHelpers.lua` are source-identical to upstream. Utility, text, and UTF-8 files are source-equivalent apart from line-ending differences.
- **Mixed responsibilities and inventory routing:** timing-window and worst-judgment helpers belong with `GAME-02`; EX counts and score calculation with `GAME-01`/`GAME-03`; game-mode preference application and stock-reset behavior with `CORE-03`; notefield geometry and asset lookup with implementation/presentation; course duration and stage helpers with `GAME-05`/session behavior. CORE-05 should retain only genuinely cross-cutting primitives.
- **Recommended decision:** `Adapt` — keep proven UTF-8/text behavior where needed, replace broad globals with namespaced VOLT26 helpers, and assign domain-specific functions to their owning inventory items before pruning.
- **Verification pending:** run Lua syntax/loading checks in the target engine; cover UTF-8 length/substrings, emoji attributes, Japanese wrapping, truncation, ranges in both directions, table lookup/deduplication, and system-message formatting.

## Profiles and options assessment

### PROFILE-01 — Player profile discovery, selection, and profile-derived state

- **Behavioral responsibility:** enumerates local profiles and their display metadata, reads recent theme modifiers for profile previews, discovers profile avatars, and coordinates guest, local-profile, and memory-card selection. The profile screen also handles joining and unjoining, coin consumption and refunds, duplicate-profile prevention for two players, default-profile selection, and the fast profile switch used from music selection.
- **Load and save contract:** the engine calls `LoadProfileCustom()` and `SaveProfileCustom()` through the `[Profile]` metrics. Loading resets player options and transient `SL[pn]` state while preserving the current session's stage history, validates stored keys by datatype and valid option-row values, restores engine modifiers, resets disabled timing windows, and reapplies the operator-defined fail type. Saving writes the permitted custom modifiers and the engine `PlayerOptionsString`.
- **Important dependencies:** `PROFILEMAN`, `GAMESTATE`, `MEMCARDMAN`, `FILEMAN`, `PREFSMAN`, `IniFile`, `ActorUtil`, `ThemePrefs`, `CustomOptionRow()`, `GetDefaultFailType()`, `SL[pn]`, profile-screen engine index conventions, corresponding `metrics.ini` routes, and the GrooveStats and ITL read/write helpers.
- **Persistent data:** each persistent profile receives `<theme display name> UserPrefs.ini`, with a section also named from the theme display name. GrooveStats and ITL data are read and written as side effects of the same lifecycle. Engine-level default local-profile IDs and coin preferences also affect selection behavior. Guest state is transient, although stage history is deliberately retained across an in-session profile switch.
- **VOLT26 delta:** the reviewed scripts and behavioral profile actors are source-equivalent to the upstream baseline apart from line-ending differences. The current storage filename and section still inherit the Simply Love theme identity, and the profile UI dynamically loads the selected visual-style assets rather than a VOLT26-owned profile contract.
- **Mixed responsibilities:** profile persistence is coupled to online-service and tournament files; profile selection is coupled to arcade credit policy, player joining, visual previews, and music-screen fast switching. These need explicit boundaries even if the existing screen behavior is retained initially.
- **Recommended decision:** `Adapt` — retain local, guest, and memory-card profile support plus validated per-profile modifiers, move persistence to an explicit VOLT26 schema with a documented Simply Love migration path, and make GrooveStats/ITL hooks optional integrations rather than mandatory profile side effects.
- **Verification pending:** select guest, local, default, and memory-card profiles; test one and two players, duplicate selection, late join, fast switching, coin consumption/refund, and cancel paths; restart the engine and verify valid modifiers persist while invalid keys, types, and unavailable assets fail safely.

### OPTIONS-01 — Player option construction and persistence

- **Behavioral responsibility:** builds custom option rows for speed, noteskin and variant, judgments, combo and hold graphics, notefield placement, music rate, chart selection, visibility, life display, score targets, timing feedback, gameplay statistics, and edit/attack modifiers. It translates selections between localized choices, `SL[pn].ActiveModifiers`, and the engine's preferred or stage `PlayerOptions`, then chooses the next options, music, or gameplay screen.
- **Application contract:** `CustomOptionRow()` exposes Lua option-row definitions to `metrics.ini`; generic load/save behavior is overridden where an option must mutate engine state or broadcast a preview/update message. `ApplyMods()` replays all rows after profile loading and on late join so saved settings apply even when the player never opens the options screen.
- **Important dependencies:** `SL[pn].ActiveModifiers`, `SL.Global.ScreenAfter`, `GAMESTATE`, `SCREENMAN`, `NOTESKIN`, `ThemePrefs`, `MESSAGEMAN`, chart/course APIs, gameplay-layout helpers, GrooveStats availability, localized strings, the three `ScreenPlayerOptions` metric groups, preview actors, and `PROFILE-01` for persistence.
- **State and persistence:** option changes update engine preferred/stage modifiers and in-memory theme state. Per-profile persistence is performed later by `SaveProfileCustom()`; music rate, current steps/trail, evaluation-pane defaults, and next-screen targets also mutate shared game-cycle state.
- **VOLT26 delta:** `SL-PlayerOptions.lua` is source-identical to the reviewed upstream baseline. VOLT26 assets are discovered through existing noteskin, judgment, hold-judgment, and combo-font enumeration, but the behavior remains owned by Simply Love names, shared state, metrics, and screen actors.
- **Mixed responsibilities and inventory routing:** the option framework currently embeds policy for tournament restrictions, online scoreboxes, chart selection, gameplay scoring displays, timing windows, course behavior, and screen navigation. The underlying feature decisions belong to their respective `GAME-*`, `ONLINE-01`, `EVENT-02`, `SELECT-*`, and `CORE-04` inventory items rather than being decided implicitly by the options UI.
- **Recommended decision:** `Adapt` — retain the proven per-player option lifecycle and profile application behavior, define a VOLT26-owned option registry, and include rows only for features accepted elsewhere in the inventory. Replace screen-specific actor manipulation with explicit update messages or interfaces where practical.
- **Verification pending:** load saved options without visiting the screen, change every retained row on all three pages, test localized values and unavailable assets, confirm live previews and engine modifiers, and repeat for one player, two players, routine, course, edit, late-join, and restart scenarios.

### OPTIONS-02 — Operator/service options and active option-row behavior

- **Behavioral responsibility:** defines the service-menu hierarchy and helper rows for theme selection, editor noteskin, default fail type, long/marathon thresholds, wheel speed, video renderer, global and visual offsets, memory cards, and custom-song limits. The service overlay supplies contextual help, remembers the active row when returning from child screens, saves theme preferences, rebuilds localized preference rows, and revalidates engine/game compatibility when leaving.
- **Important dependencies:** `PREFSMAN`, `ThemePrefs`, `ThemePrefsRows`, `SL_CustomPrefs`, `SL.Global.PrevScreenOptionsServiceRow`, `SCREENMAN`, `GAMESTATE`, `IniFile`, theme and engine metadata, compatibility helpers, localized strings, and the `ScreenOptionsService*` hierarchy in `metrics.ini`.
- **Persistent data:** engine preferences include default modifiers/fail type, editor noteskins, song-length thresholds, wheel speed, renderer order, timing offsets, memory-card behavior, and custom-song limits. Theme-owned rows persist through `ThemePrefs.Save()`. The remembered active option row is transient session state.
- **VOLT26 delta:** `SL-OperatorMenuOptions.lua` and the assessed service actors are source-equivalent to the upstream baseline. The inherited hierarchy still exposes Simply Love visual-style and optional-feature preferences; VOLT26 currently enters it as one selectable visual style rather than owning a curated operator menu.
- **Mixed responsibilities:** engine-wide configuration, VOLT26 preferences, optional online/tournament features, theme switching, compatibility validation, and service-menu presentation share one hierarchy. Theme switching and renderer changes also have wider installation or restart consequences than ordinary theme preferences.
- **Recommended decision:** `Adapt` — keep the engine settings that VOLT26 operators need, create a smaller VOLT26-owned service hierarchy, separate machine preferences from theme and optional-integration settings, and remove visual-style selection from the standalone runtime.
- **Verification pending:** enter every retained child screen, change and persist each custom row, return and confirm active-row restoration, restart where required for renderer/theme changes, and verify invalid compatibility choices redirect safely with an actionable message.

## Explicitly out of scope for this inventory

The following are tracked elsewhere unless they contain behavior required by an item above:

- colors, fonts, logos, backgrounds, decorative animation, and sound selection;
- actor coordinates, sizing, tweening, and aspect-ratio-specific layout;
- judgment and hold graphics as image assets;
- visual-style themes that do not affect navigation, state, scoring, persistence, or integration behavior.

## Upstream review log

| Review date | Simply Love tag/commit | VOLT26 branch | Result |
| --- | --- | --- | --- |
| Pending | Pending baseline identification | `codex/standalone-migration-plan` | Initial inventory structure created; detailed audit not started |
| 2026-08-24 | Pending baseline identification | `codex/baseline-runtime-stabilization` | Reviewed mixed runtime/presentation blockers in the local prototype; no standalone feature-adoption decision finalized |
| 2026-08-24 | `dd06138b15492f4136796dfe4b6708ced0f7b9eb` | `codex/simply-love-functional-scan-core` | Completed the source-level scan for `CORE-01` through `CORE-05`; retention decisions and runtime verification remain pending |
| 2026-08-24 | `dd06138b15492f4136796dfe4b6708ced0f7b9eb` | `codex/simply-love-functional-scan-profile-options` | Completed the source-level scan for `PROFILE-01`, `OPTIONS-01`, and `OPTIONS-02`; retention decisions and runtime verification remain pending |
