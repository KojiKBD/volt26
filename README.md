# VOLT26

VOLT26 is a standalone theme for ITGmania. It began as a Simply Love visual style and is being developed into an independently installable theme with its own identity, screen flow, runtime services, and selected inherited behavior.

> [!IMPORTANT]
> VOLT26 `0.1.0-rc.2` is a release candidate intended for final installation and compatibility testing before the first stable release.

## Requirements

- ITGmania 1.3.0 or newer
- A standard ITGmania installation with a writable `Save/` directory
- Simply Love is not required at runtime

## Installation for testing

1. Place this repository in `Themes/VOLT26` inside the ITGmania installation.
2. Start ITGmania.
3. Open the service options and select VOLT26 as the theme.
4. Restart the game if requested.

Do not merge a newer checkout into an older VOLT26 directory. Replace the old theme directory so removed files cannot remain in the installation.

See the [testing installation guide](Other/Documentation/InstallingVOLT26-README.md) for the complete procedure and troubleshooting notes.

## Current status

The primary standalone route is implemented:

- startup and title menu;
- profile selection;
- music selection;
- player options;
- gameplay scoring, telemetry, and failure handling;
- stage evaluation, performance graphs, and screenshots;
- evaluation summary, name entry, and game-over session statistics;
- curated service options.

The inherited Simply Love functionality has been reviewed capability by capability. Retained behavior now uses VOLT26-owned boundaries, while intentionally omitted or dormant integrations are documented explicitly. Extended verification coverage is tracked in the [functional inventory](docs/simply-love-functional-inventory.md).

GrooveStats is available as an optional integration for persistent profiles. See the [GrooveStats setup and security notes](docs/groovestats.md).

Tournament Mode is available from the service options and can enforce scoring display and `no cmod` chart rules before the NoteField is constructed, without overriding the player's gameplay-statistics layout. A temporarily forced MMod is restored to the previous CMod after the song. Annual ITL event records are not currently enabled.

Custom songs stored in USB profiles are supported through **USB Profile Options** when the installed ITGmania build exposes the required engine preferences. ITGmania remains responsible for removable-media discovery, validation, loading, limits, and cleanup. See the [custom songs from USB profiles guide](Other/Documentation/CustomSongsFromUSB-README.md) for setup details.

## Supported languages

VOLT26 currently inherits translations for English, German, Spanish, French, Italian, Japanese, Polish, Brazilian Portuguese, and Russian. Translation completeness varies by language, and VOLT26-specific wording is still being reviewed.

## Display support

VOLT26 is designed specifically for a 16:9 display and this is the recommended aspect ratio. The theme remains functional at other aspect ratios, but graphics and layouts may not scale or align correctly; compatibility outside 16:9 currently applies to behavior rather than visual presentation.

## Development documentation

- [AI handoff](docs/ai-handoff.md) — current context and safe continuation guide for a new coding assistant
- [Standalone migration plan](docs/standalone-theme-migration-plan.md)
- [Standalone architecture](docs/standalone-architecture.md)
- [Simply Love functional inventory](docs/simply-love-functional-inventory.md)

## Upstream and attribution

VOLT26 is derived from [Simply Love](https://github.com/Simply-Love/Simply-Love-SM5). Retained upstream code, translations, and assets remain subject to their original copyright and attribution requirements. See [LICENSE](LICENSE) and the attribution files distributed with individual assets.

## License

See [LICENSE](LICENSE) for the repository license and retained upstream notices.
