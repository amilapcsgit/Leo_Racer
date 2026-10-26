# Leo Racer 2.3.2 — Orbit Camera and Vehicle Features

The accepted Windows candidate is promoted to the public release with Bigster
1.2.1, reverse/look-back/orbit cameras, remappable lights and vehicle actions,
the sliding sunroof and Workshop feature authoring. Track routes, physics,
checkpoints and course revisions are unchanged.

The complete offline installer contains three tracks, 16 default cars and 32
additional cars. Its component page offers Complete, Standard and Custom.
Custom permits individual tracks and additional cars; it requires at least one
track and retains the 16 default cars. Deselecting existing content preserves it.
The ownership ledger backs up replaced modifications and preserves user-added
cars and modified files during uninstall. Settings/input profiles/records live
outside the installation and keep their existing locations.

Kandy's unchanged route and scenery package are now registered in the official
core tables, alongside Astra and Colombo. The previous core omitted Kandy from
those tables. Content modifications still make races unranked.

## Reproduce and verify

Start from the accepted, extracted-package-verified candidate. Original downloads
and synced `sources/` are read-only. The local `build/a` contains the same 32
additional car packages and licenses from 2.3.1.

```powershell
python tools/release_232.py assemble
python tools/release_232.py installer
python tools/verify_release_232.py game
python tools/verify_release_232.py installers
python tools/release_232.py package
```

Use the bundled Python runtime if `python` is not on PATH. NSIS 3.13 is pinned in
`.tools/nsis`. Diagnostic installation destinations are isolated workspace
folders under `t232`; existing fixture directories are never overwritten.
`/CONTENTTEST` disables normal registry and shortcut changes and requires an
explicit matching `/TESTDIR=` destination. The test harness bounds command
length below NSIS's 1024-character limit; use `/CARS=all` for the complete set.

Silent install switches: `/PROFILE=complete`, `/PROFILE=standard`, or
`/PROFILE=custom /TRACKS=kandy_lake /CARS=<comma-separated additional-car IDs>`.
Use `/TRACKS=all` or `/CARS=all` where appropriate. `/D=<destination>` must be last.
The component page provides the same choices interactively.

Upload only after verification passes and the `orbitcamera` commit is pushed:

```powershell
python tools/release_232.py manifest
python tools/publish_content_release.py --manifest dist/release-2.3.2/release-manifest.json --notes dist/release-2.3.2/RELEASE_NOTES-2.3.2.md --title "Leo Racer 2.3.2 — Orbit Camera and Vehicle Features" --publish
```

The installer asset deliberately has the stable name `LeoRacer-Setup.exe`, so the
README button `/releases/latest/download/LeoRacer-Setup.exe` keeps working for
later releases. Future publishers should retain this asset name. SHA256 hashes
are verified locally and against GitHub's uploaded asset digests before the
release is made public. Existing releases are retained.

See [vehicle controls and metadata](VEHICLE_FEATURES.md), the
[accepted candidate report](qa-vehicle232/TEST_REPORT.md), and release-specific
installer/content reports in `docs/qa-vehicle232/`.
