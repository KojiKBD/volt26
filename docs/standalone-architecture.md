# VOLT26 Standalone Architecture

## Dependency rule

VOLT26 is divided into CORE behavior and SCREEN presentation. SCREEN code may call public CORE interfaces. CORE code must not load actors, reference screen coordinates, or select presentation assets.

## CORE domains

- `VOLT26.Core`: bootstrap, lifecycle, and access to runtime state.
- `VOLT26.Util`: deterministic table, range, mapping, formatting, lookup, and system-message primitives.
- `VOLT26.Text`: UTF-8-aware emoji attributes, wrapping, and truncation behavior for text actors.
- `VOLT26.Compatibility`: engine/game policy, version parsing, theme metadata, and renderer capability checks.
- `VOLT26.State`: global, per-player, per-stage, and per-session state.
- `VOLT26.ThemePrefs`: persistent theme configuration.
- `VOLT26.Profile`: guest/profile lifecycle, persistence callbacks, avatar lookup, and profile-flow state.
- `VOLT26.MusicSelection`: music-screen initialization, active-rate access, and player refresh behavior.
- `VOLT26.SongBrowsing`: search parsing, song filtering, result selection, and the accepted Sort Menu action policy.
- `VOLT26.Favorites`: legacy import, VOLT26-owned favorite persistence, normalized membership state, and toggling.
- `VOLT26.ChartData`: immutable snapshots of engine-backed density, NPS, technique counts, and column cues.
- `VOLT26.ChartAnalysis`: pure stream-sequence, breakdown-text, and measure-total derivation over chart snapshots.
- `VOLT26.ChartHash`: explicit access to cached GrooveStats-compatible hashing for optional online consumers; ordinary song browsing must not invoke it.
- `VOLT26.GrooveStats`: optional HTTPS service capability state, bounded response decoding, normalized per-profile identity persistence, and score-service eligibility policy. QR login, automatic downloads, online lobbies, and event payloads remain outside this boundary.
- `VOLT26.Events`: provider-neutral normalization of optional RPG and ITL memberships returned by GrooveStats score submission. Event presentation remains dormant without validated data and does not authorize downloads or annual local persistence.
- `VOLT26.Tournament`: operator-selected tournament policy for scoring display and `no cmod` metadata. A disallowed CMod is synchronized to MMod across theme and engine state before the NoteField is constructed, then the previous CMod is restored on return to music selection. Player-selected gameplay-statistics layout is preserved; annual ITL persistence remains outside the active boundary.
- `VOLT26.CustomSongs`: engine-capability boundary for profile-hosted custom songs. ITGmania owns removable-media discovery, validation, loading, limits, and cleanup; VOLT26 only exposes supported operator preferences and preserves valid engine-defined values.
- `VOLT26.Gameplay`: explicit active-stage lifecycle, reload state, and player-stage storage.
- `VOLT26.GameplayStats`: peak-density normalization, immutable measure segments, stream/rest counters, rate-aware timing, and graph interpolation.
- `VOLT26.TargetScore`: target resolution, pacemaker progress, reachability, and missed-target action policy.
- `VOLT26.CourseSpeed`: bounded X/M/C adjustment and engine-command formatting between course songs.
- `VOLT26.Versus`: compatible scoring-mode checks, precise DP ratios, and isolated two-player leader state.
- `VOLT26.Session`: monotonic gameplay timing, pause accounting, completed-stage state, normalized tap totals, Game Over summaries, and profile-summary snapshots.
- `VOLT26.Telemetry`: normalized EX, timing-offset, and per-column judgment capture for the current stage.
- `VOLT26.Scoring`: score calculations over telemetry snapshots and chart radar data.
- `VOLT26.Results`: normalized Evaluation snapshots, grade policy, record eligibility, and name-entry decisions.
- `VOLT26.Analysis`: timing statistics, histogram smoothing, bounded scatter batches, and shared song/course timeline coordinates.
- `VOLT26.EvaluationInput`: available-pane selection, callback ownership, replay/practice policy, and screenshot capture state.
- `VOLT26.InputDiagnostics`: supported-game capability, event filtering, player/controller routing, physical-source identity, and reference-counted held-input state shared by Service, Song Select, and Evaluation diagnostics.
- `VOLT26.Failure`: failure-position records and gameplay-exit reconciliation policy.
- `VOLT26.Evaluation`: versioned song/course contexts, immutable per-player result snapshots, profile history, and idempotent completed-stage lifecycle.
- `VOLT26.Options`: player-modifier access, player/options-screen routing, curated operator-menu policy, and active operator-row state.
- `VOLT26.OperatorOptions`: validated engine-preference rows for editor noteskins, fail behavior, song thresholds, renderer order, offsets, memory cards, and removable-media limits.
- `VOLT26.TitleMenu`: title-menu behavior and inactivity policy.
- `VOLT26.Navigation`: route decisions and supported-mode policy.
- `VOLT26.Brand`: theme identity, colors, and presentation-neutral brand data.

Additional optional-service APIs will be added as their feature groups are migrated.

## SCREEN groups

1. startup and title;
2. profile and mode selection;
3. music and course selection;
4. player and operator options;
5. gameplay;
6. evaluation and game over;
7. maintenance and optional online/event screens.

Each screen group owns its actors, input callbacks, layout, animation, graphics, and sound. Shared behavior belongs in a CORE domain and should be exposed through a narrow public function or state query.

## Compatibility boundary

The inherited `SL` namespace, `InitializeSimplyLove`, `SL_CustomPrefs`, and remaining `SL-*` source names are temporary migration adapters. This includes the inherited `VOLT26.Preferences` game-mode scoring table exposed through the `SL` alias. New or migrated preference code must use `VOLT26.ThemePrefs`. An adapter may be removed only after repository scans and runtime verification show that no remaining consumer depends on it.

The `VisualStyle` preference is retained temporarily as a fixed compatibility value for inherited screens. It is not user-selectable and must not be read by new VOLT26 code.

## Integration order

The implementation proceeds in vertical slices:

1. CORE foundation plus startup and title;
2. profile selection;
3. music selection;
4. minimal gameplay and evaluation;
5. options and advanced gameplay behavior;
6. optional services and events;
7. compatibility-adapter removal and clean-install verification.

Every slice is implemented on a dedicated branch, updates the functional inventory, and requires project-owner verification before integration into `main`.
