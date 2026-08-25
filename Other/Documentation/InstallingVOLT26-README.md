# Installing VOLT26

These instructions apply to release archives and test builds of VOLT26.

## Requirements

- ITGmania 1.3.0 or newer
- A checkout or test archive of VOLT26

StepMania 5, OutFox, and older ITGmania releases are not supported by the current compatibility check.

## Clean installation

1. Exit ITGmania.
2. Remove or rename any existing `Themes/VOLT26` directory after backing up local customizations.
3. Place the new theme directory at `Themes/VOLT26`.
4. Confirm that `ThemeInfo.ini`, `metrics.ini`, `Scripts/`, `BGAnimations/`, and `Graphics/` are directly inside `Themes/VOLT26` rather than inside another nested directory.
5. Start ITGmania and select VOLT26 from the theme setting in the service options.
6. Restart ITGmania if requested.

Simply Love does not need to be installed alongside VOLT26.

## Updating an installation

Replace the complete `Themes/VOLT26` directory. Do not merge the new files into an older copy because files removed by an update could otherwise remain active.

Back up intentional local assets or configuration before replacing the directory. Theme and profile preferences stored under ITGmania's `Save/` and profile directories are separate from the theme directory.

## Rollback

1. Exit ITGmania.
2. Rename or remove the current `Themes/VOLT26` directory.
3. Restore the complete directory from the previously working release archive.
4. Start ITGmania and verify the theme version in the service information.

Do not restore profile or machine `Save/` data unless the release notes explicitly describe an incompatible persistence change. VOLT26 `0.1.0-rc.1` does not require such a rollback.

## Troubleshooting

If the theme opens to a fallback screen or reports missing elements, check for an accidentally nested path such as:

```text
Themes/VOLT26/VOLT26/ThemeInfo.ini
```

The correct path is:

```text
Themes/VOLT26/ThemeInfo.ini
```

If VOLT26 reports an unsupported engine version, use ITGmania 1.3.0 or newer. For other startup failures, preserve the ITGmania log and report the exact route that produced the error.
