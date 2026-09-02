# Changelog

All notable VOLT26 changes are documented here. Versions follow Semantic Versioning; release candidates use the `-rc.N` suffix.

## 0.1.0-rc.4 — 2026-09-02

### Added

- An incremental pre-intro warm-up screen for the shared VOLT26 presentation assets.
- `PerformanceMode`, an arcade-oriented presentation path that uses bounded texture preparation and lightweight opaque transitions.
- A Claude-ready project handoff and working guide.

### Changed

- VOLT26 now owns its presentation directly instead of selecting inherited visual styles at runtime.
- Title and Song Select prepare only their likely next screen groups while idle; song banners and jackets remain demand-loaded.
- The title presentation includes the VOLT26 letterbox/train composition and the Performance path avoids Full HD image-sequence handoffs.

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
