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
| CORE-02 | ITGmania compatibility validation and startup failure handling | `BGAnimations/ScreenInit overlay/CompatibilityChecks.lua`, `BGAnimations/ScreenInit overlay/default.lua` | Assess | Not started |
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

