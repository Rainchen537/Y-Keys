# Changelog

All notable Y-Keys release changes are tracked here.

## v0.1.6 - 2026-07-22

- Prepared separate Apple Silicon (`arm64`) and Intel (`x86_64`) thin builds, with isolated paths, per-build temporary icon generation, parallel-build safety, and strict architecture checks.
- Updated the release flow to independently build, stage, sign, notarize, staple, mount, and verify both architecture-specific DMGs, then publish them as a checked pair through staging and `.new` files; failed finalization restores the prior complete asset pair instead of leaving partial output.
- Hardened the DMG wrapper against directory or symlink outputs and stale staged files.
- Clarified in Settings and the README that update checks still open GitHub Releases and users must manually choose the matching Apple Silicon or Intel download.

## v0.1.5 - 2026-07-20

- Rebuilt the drag-to-install DMG with a light high-contrast 2x Retina background, keeping Finder's black app labels crisp and readable in light and dark system appearances.
- Removed visible `.background` and `.fseventsd` folders from the final image, hid Finder's toolbar, status bar, path bar, and tab bar, and aligned the installation arrow from the saved Y-Keys and Applications icon coordinates.

## v0.1.4 - 2026-07-20

- Redesigned the app icon as a compact shortcut deck with modifier keys, a wide Command key, and an offset layer that communicates the double-Command trigger while matching the Y-Project visual family.
- Replaced the menu bar mark with a transparent template icon built from two offset keycap outlines and a Command symbol for clearer light/dark menu bar rendering.
- Made modifier highlighting exact: pressing Command still shows both Command-Z and Command-Shift-Z candidates, while adding Shift immediately dims combinations that do not include Shift; matching shortcut names and subtitles now highlight with their keycaps.
- Fixed dense application shortcut lists so calculated lane widths cannot expand and push the System group off the right side of the overlay.
- Added safe Escape dismissal: overlays with an Escape shortcut require a second press within 1.2 seconds, show a first-press hint, and consume both Escape key-down and key-up events so the underlying app is unaffected.
- Regenerates icon assets before each build, verifies a strict metadata-free copy in File Provider-managed workspaces, retries busy DMG detach operations, and verifies the stapled app again from the final mounted DMG.

## v0.1.3 - 2026-07-19

- Unified first-launch and later Accessibility, Input Monitoring, and keyboard-listener guidance through the shared Y-Project permission prompt framework, with sequential state progression and duplicate suppression.
- Replaced the project-specific DMG layout code with the shared Y-Project DMG framework, which dynamically renders the product name and validates the saved Finder background, Applications link, and icon layout.
- Relaunches now use LaunchServices without forcing a second app instance.

## v0.1.2 - 2026-07-18

- Fixed “显示快捷键” in Settings so it tracks the most recently activated external app, never scans Y-Keys itself, and discards terminated targets.
- Added a real manual GitHub Release update check, numeric comparison for suffix-bearing tags, visible failure details, and clearer product identity in About.
- Split Accessibility and Input Monitoring into separate status and action rows, retried the keyboard listener when the app becomes active after permission changes, and allowed the warning to advance when only one missing permission was granted without duplicating identical alerts.
- Added runtime diagnostics that distinguish the verified signed `/Applications` copy from development copies and can switch directly to the installed app.
- Added a separate keyboard-listener runtime status, scoped TCC refreshes to Y-Keys' bundle identifier for Accessibility and Input Monitoring, moved reset work off the main thread, and refreshed permission status before reporting a partial reset failure.
- Removed continuous permission polling, validated preview section identifiers, and constrained settings windows to the active display.

## v0.1.1 - 2026-06-28

- Added an independent sidebar settings window using the shared Y-Project settings shell.
- Simplified the menu bar item to open settings, reserve a More Y-Project entry, and quit the app.
- Added settings pages for trigger information, Accessibility permission checks, app version, and GitHub entry.
- Vendored the shared Y-Project settings framework so the repository can be built independently from GitHub source checkouts.
- Added the first signed and notarized DMG release flow.

## v0.1.0 - 2026-06-27

- Added the initial Y-Keys menu bar app.
- Added double-left-Command detection, shortcut scanning through Accessibility, system shortcut data, and the single-screen shortcut overlay.
