# Changelog

All notable VOLT26 changes are documented here. Versions follow Semantic Versioning; release candidates use the `-rc.N` suffix.

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
