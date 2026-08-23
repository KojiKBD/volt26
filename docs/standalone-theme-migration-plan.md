# VOLT26 Standalone Theme Migration Plan

## Purpose

VOLT26 began as a Simply Love visual style, but its intended behavior and structure now extend beyond presentation. The project will progressively become an independently installable ITGmania theme while retaining selected non-visual Simply Love functionality and providing a repeatable way to review future upstream features.

## Target outcome

VOLT26 is considered standalone when:

- it installs as its own directory under `Themes/` without requiring a Simply Love installation;
- its identity, metadata, metrics, scripts, screens, assets, preferences, and language strings are owned by VOLT26;
- no runtime path depends on `Graphics/_VisualStyles/VOLT26` or on files outside the VOLT26 theme directory;
- retained Simply Love behavior is explicitly recorded in the functional inventory;
- upstream synchronization can be performed feature by feature instead of by copying the complete Simply Love tree;
- installation and upgrade instructions have been verified on a clean supported ITGmania installation.

## Guiding principles

1. Separate behavior from presentation before replacing either one.
2. Preserve working behavior during the transition; migrate in small, reviewable branches.
3. Track provenance and licensing for retained upstream code and assets.
4. Prefer VOLT26-owned modules and stable interfaces over direct edits scattered across screen files.
5. Do not merge an activity branch into `main` until the project owner has verified and accepted it.

## Phase 0 — Establish a controlled baseline

**Goal:** make the current work reproducible before structural migration begins.

- Confirm which existing local changes belong to the intended VOLT26 baseline.
- Record the ITGmania version and Simply Love version/commit from which the current tree derives.
- Review repository identity: remote, default branch, `ThemeInfo.ini`, README, license, and attribution.
- Create a baseline checkpoint without discarding or silently combining unrelated work.
- Identify generated, temporary, and development-only files that should not ship.

**Exit criteria:** the baseline can be checked out on another machine, its ancestry is known, and the working tree has an intentional state.

## Phase 1 — Inventory Simply Love behavior

**Goal:** create a complete map of functionality that is independent of visual styling.

- Expand `docs/simply-love-functional-inventory.md` by tracing scripts, metrics, screen actors, preferences, and integrations.
- Classify each item as `Adopt`, `Adapt`, `Replace`, `Omit`, or `Assess`.
- Record dependencies, persistent data, engine APIs, affected screens, and a practical verification method.
- Identify mixed files that combine visual layout and business behavior; split their responsibilities in the inventory even if the source file is currently shared.

**Exit criteria:** every relevant non-visual feature has an owner decision and a verification approach.

## Phase 2 — Create the standalone foundation

**Goal:** remove the visual-style bootstrap and establish VOLT26-owned theme entry points.

- Change theme identity and metadata from Simply Love to VOLT26.
- Define VOLT26 initialization, preferences, shared state, colors, layout APIs, and navigation branches.
- Move required VOLT26 assets and screen implementations out of `_VisualStyles/VOLT26` into theme-owned locations.
- Replace visual-style selection checks with direct VOLT26 behavior.
- Add compatibility checks that describe supported ITGmania versions clearly.

**Exit criteria:** ITGmania recognizes VOLT26 as a separate theme and reaches its core screens without loading a visual style.

## Phase 3 — Migrate behavior by feature group

**Goal:** port only the behavior VOLT26 intends to support.

Recommended order:

1. startup, compatibility, preferences, and navigation;
2. player profiles and player/operator options;
3. music selection, chart metadata, favorites, and search;
4. gameplay scoring, judgment tracking, failure rules, and statistics;
5. evaluation, records, screenshots, and score submission;
6. online services, QR codes, tournament support, and optional modes;
7. maintenance and diagnostic screens.

Each feature group should be handled on its own branch. Update the functional inventory, implement or adapt the feature, test it, and request project-owner verification before merge.

**Exit criteria:** all items marked `Adopt`, `Adapt`, or `Replace` have an implementation and verification result; omitted items have a recorded rationale.

## Phase 4 — Remove Simply Love compatibility scaffolding

**Goal:** eliminate accidental coupling after the required functionality is owned by VOLT26.

- Remove obsolete `SL_` globals and naming where they no longer represent an upstream compatibility boundary.
- Remove unused screens, assets, languages, metrics, preferences, and redirects.
- Replace broad copied modules with smaller VOLT26-owned modules where practical.
- Confirm that no runtime reference points to Simply Love or its visual-style directories.
- Preserve required copyright and attribution notices for retained work.

**Exit criteria:** dependency scans and clean-install tests show no external Simply Love runtime requirement.

## Phase 5 — Establish ongoing upstream synchronization

**Goal:** make future Simply Love feature reviews predictable and selective.

For each upstream Simply Love release:

1. record the reviewed tag or commit in the functional inventory;
2. review upstream changes by functional area;
3. mark each relevant change as `Port`, `Adapt`, `Not applicable`, or `Deferred`;
4. implement each accepted group on a dedicated branch;
5. run focused verification plus a smoke test;
6. obtain project-owner acceptance before merging into `main`.

This is a semantic synchronization process: changes are evaluated by behavior, not copied wholesale by file path.

## Phase 6 — Package and release

**Goal:** ship VOLT26 as a reliable, independently installable theme.

- Write standalone installation, upgrade, configuration, and troubleshooting documentation.
- Test a clean install and an upgrade from the previous VOLT26 release.
- Verify supported resolutions, player counts, input devices, profiles, and optional online functionality.
- Audit distributable files, licenses, attribution, and package size.
- Define versioning, changelog, release archive, and rollback procedure.

**Exit criteria:** a release archive installs and runs without Simply Love, and its documented smoke test passes.

## Verification matrix

Every migration branch should select the relevant checks below and record the outcome:

| Area | Minimum verification |
| --- | --- |
| Startup | Theme loads without Lua errors and compatibility failures are actionable |
| Navigation | Title, profile, mode, music, options, gameplay, evaluation, and exit paths work |
| Persistence | Theme preferences and profile data survive a restart |
| Gameplay | One-player and two-player sessions track judgments, score, life, and failure correctly |
| Evaluation | Results, records, graphs, screenshots, and optional submission behave as intended |
| Content | Song groups, courses, custom songs, and missing optional assets fail safely |
| Display | Supported aspect ratios and low/high resolutions remain usable |
| Installation | A clean ITGmania setup needs only the VOLT26 theme directory |

## Immediate next activities

1. Review and checkpoint the current 347-file local baseline on a dedicated branch.
2. Complete the initial functional inventory with source-level dependencies and owner decisions.
3. Update VOLT26 identity and define its standalone bootstrap on a separate implementation branch.
4. Migrate the first vertical slice: startup → title → profile → music selection → gameplay → evaluation.

The current planning branch must remain unmerged until the project owner has reviewed these documents and explicitly accepted them.

