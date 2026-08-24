# Installing VOLT26 for Testing

VOLT26 is currently a development theme rather than a packaged release. Use these instructions for a clean testing installation.

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

## Updating a test installation

Replace the complete `Themes/VOLT26` directory. Do not merge the new files into an older copy because files removed by an update could otherwise remain active.

Back up intentional local assets or configuration before replacing the directory. Theme and profile preferences stored under ITGmania's `Save/` and profile directories are separate from the theme checkout, but migration behavior is still under development.

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
