# Custom Songs from USB Profiles

VOLT26 exposes ITGmania's built-in support for loading songs stored inside a USB profile. ITGmania performs media discovery, song validation, loading, limit enforcement, and cleanup; the theme only exposes the corresponding operator preferences.

## Prerequisites

1. Use a supported [ITGmania release](https://github.com/itgmania/itgmania/releases).
2. Configure the operating system and ITGmania to recognize USB profiles through stable mount points.
3. Enable USB profiles in VOLT26's operator settings.

The original StepMania static-mount references remain useful for compatible installations:

- [Windows static mount points](https://github.com/stepmania/stepmania/wiki/Static-Mount-Points-for-USB-Profiles-(Windows))
- [Linux static mount points](https://github.com/stepmania/stepmania/wiki/Creating-Static-Mount-Points-For-USB-Profiles-%28Linux%29)

Mount configuration is installation-specific and is not performed by VOLT26.

## Profile layout

Place custom song folders in the `Songs` directory at the root of the USB profile. Each song folder must contain a simfile and its referenced assets in a format supported by ITGmania.

## Operator configuration

Open the ITGmania Service Menu, then select **USB Profile Options**. VOLT26 exposes these engine preferences when custom-song support is available:

- **USB Profiles** enables or disables memory-card profiles.
- **Custom Songs** enables or disables songs stored in those profiles.
- **Max Songs per USB** limits how many songs ITGmania loads from one profile.
- **Song Load Timeout** limits the load time allowed per song.
- **Song Duration Limit** excludes songs longer than the selected duration.
- **Song File Size Limit** excludes songs larger than the selected size.

VOLT26 preserves positive values already configured directly in ITGmania even when they are not part of the suggested lists shown by the theme.

## Applying and troubleshooting

Save the operator settings, then reconnect or reload the profile as required by the installed ITGmania version. If songs do not appear, verify the mount point, profile detection, `Songs` directory, simfile references, and configured limits first.

Loading errors, timeouts, unsupported files, disconnected media, and partial scans are reported and handled by ITGmania. VOLT26 does not copy, edit, delete, or independently scan files on removable media.
