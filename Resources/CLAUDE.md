# Resources/

Reserved for build-time resource organisation if/when needed. Currently empty.

The canonical default b0t markdown ships from `default-bot/` at the repo root, added to the app target as a folder reference. Raw design assets ship from `assets/` at the repo root.

Adding a file to `default-bot/` lands it in the bundle on next build **and** reaches existing installs on next launch: `BotProvisioner.syncMissingFiles` copies any bundled file missing from the user's active bot dir (additive only; never overwrites user-edited files). So a new shipped module/file propagates to users on update without a reinstall. See `docs/plans/botprovisioner-bundle-sync.md`.

If a future need arises (e.g., codegen output, intermediate sprite atlases that don't belong in `assets/`), they belong here, not under the source folders.

Do not put runtime user state here — that lives in `~/Documents/b0ts/` per ADR 0004.
