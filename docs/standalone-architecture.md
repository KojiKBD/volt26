# VOLT26 Standalone Architecture

## Dependency rule

VOLT26 is divided into CORE behavior and SCREEN presentation. SCREEN code may call public CORE interfaces. CORE code must not load actors, reference screen coordinates, or select presentation assets.

## CORE domains

- `VOLT26.Core`: bootstrap, lifecycle, and access to runtime state.
- `VOLT26.State`: global, per-player, per-stage, and per-session state.
- `VOLT26.ThemePrefs`: persistent theme configuration.
- `VOLT26.Profile`: guest/profile lifecycle, persistence callbacks, avatar lookup, and profile-flow state.
- `VOLT26.MusicSelection`: music-screen initialization, active-rate access, and player refresh behavior.
- `VOLT26.SongBrowsing`: search parsing, song filtering, result selection, and the accepted Sort Menu action policy.
- `VOLT26.Favorites`: legacy import, VOLT26-owned favorite persistence, normalized membership state, and toggling.
- `VOLT26.ChartData`: immutable snapshots of engine-backed density, NPS, technique counts, and column cues.
- `VOLT26.ChartAnalysis`: pure stream-sequence, breakdown-text, and measure-total derivation over chart snapshots.
- `VOLT26.ChartHash`: explicit access to cached GrooveStats-compatible hashing for optional online consumers; ordinary song browsing must not invoke it.
- `VOLT26.Gameplay`: stage lifecycle, reload state, player-stage storage, and gameplay duration.
- `VOLT26.Telemetry`: normalized EX, timing-offset, and per-column judgment capture for the current stage.
- `VOLT26.Scoring`: score calculations over telemetry snapshots and chart radar data.
- `VOLT26.Failure`: failure-position records and gameplay-exit reconciliation policy.
- `VOLT26.Evaluation`: result-context storage and completed-stage lifecycle.
- `VOLT26.Options`: player-modifier access, options-screen routing, and return policy.
- `VOLT26.TitleMenu`: title-menu behavior and inactivity policy.
- `VOLT26.Navigation`: route decisions and supported-mode policy.
- `VOLT26.Brand`: theme identity, colors, and presentation-neutral brand data.

Additional result-analysis and optional-service APIs will be added as their feature groups are migrated.

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
