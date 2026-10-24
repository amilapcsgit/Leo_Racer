# Custom cars recovery notes

Base: v2.2.0 (`de266e52bf456fd991d4fc0f501d61710693478b`). Branch: `customcars`.

Leo Racer and Vehicle Workshop are completely offline. Import, conversion,
testing and installation use local files. No accounts, servers, network APIs,
online rankings or online multiplayer are planned. Existing local split screen
and SQLite rankings remain.

## Checkpoint 1: menu repair and imported boost

- Content owns input while open; the underlying menu cannot steal focus.
- Real pointer tests cover Refresh, Set Up, both Back buttons and Escape at
  1280x720, 1920x1080 and 2560x1080. Empty rosters can return safely.
- Browse GLB uses a filesystem dialog; closing an import invalidates its result.
- Custom cars with no exhaust metadata receive two blue rear boost emitters
  based on their normalized collision bounds. Explicit stock emitters and
  authoritative JSON remain unchanged.
- `content_refresh_test.gd`: PASS, 15 checks (pointer delivery, not signal emit).
- `customcars_boost_test.gd`: PASS, 9 checks using actual game assembly/effects.
- Physical Windows DPI/native-dialog interaction still needs visual verification.
- Existing renderer-resource teardown warnings occur in headless game tests.

## Checkpoint 2: offline companion and generic conversion

- Installed engine starts a separate Workshop window before race assets load.
  A namespaced, independently replaceable tool pack contains its UI/converter.
- Guided four-wheel setup, island/triangle-region correction, stationary
  calipers, wheel spin/steer, editable blue boost, collision/camera and private
  unranked test drive are implemented. New conversions omit visible drivers.
- Source GLBs remain unchanged. Metadata and GLB bindings are validated in a
  staging directory outside vehicle discovery before atomic folder installation.
- Raw BYD: PASS 63 checks; combined anonymous geometry: PASS 49 checks. Actual
  game wheel pivots, steering/calipers and material export/reimport are checked.
- Workshop UI: PASS 20, including detached-model cleanup on reinspection;
  menu/dialog input: PASS 13. Core regression checks:
  input 35, rankings 26, race state 21, old workshop 22, loose/cache content 40.
- Both tracks, 1/2 humans, six racers, three laps: all four matrix cases pass.
  Dummy renderer logs one nonfatal scenery-instantiation warning; GPU checks
  and package verification are recorded separately at integration checkpoint.
- Exported Workshop bootstrap and BYD private-drive probe pass. The private
  proving ground uses actual arcade physics and never constructs a ranking store.

## Checkpoint 3: development delivery complete

- Development ZIP: `dist/LeoRacer-2.2.0-customcars-dev-win64.zip`, Bigster/Duster
  profile, both tracks and shared drivers. Run `LeoRacer.exe` after extraction.
- Separate Workshop update: `dist/LeoRacer-VehicleWorkshop-dev.zip`. Runtime
  tool replacement passed in the extracted copy with identical EXE/core hashes.
- Optional locally prepared BYD: `dist/content/LeoRacer-vehicles-byd_yangwang_u8.zip`.
  It retains its author's CC-BY-NC-SA-4.0 attribution; not included in the default
  two-car distribution. Copied into the extracted build, all three cars validate,
  and the BYD private arcade drive passes with four wheels/two boost jets and
  no visible driver. EXE/core hashes stay unchanged. BYD cold import: 0.726 s;
  cached import: 0.029 s. Import timing is separate from steady driving performance.
- All eight extracted offline checks pass with SDK paths removed: boot artwork,
  content, cold/warm vehicles, actual pointer refresh/navigation, UI and both-track
  smoke tests. A diagnostic bootstrap loading overlay was discovered intercepting
  pointer events; it is hidden before the GUI test. The rebuilt package passes.
- Six-racer, two-human 1080p RTX A1000 measurements: Colombo Forward+ 119.84 FPS,
  p95 10.924 ms/p99 11.379 ms/max 36.634 ms; Astra Compatibility 116.11 FPS,
  p95 10.417 ms/p99 12.019 ms/max 137.191 ms. Astra Forward+ measured 92.09 FPS
  while the headless race matrix ran concurrently; do not use that sample to
  claim a baseline performance comparison. Colombo Forward+ cell transitions
  show no live renderer errors; resource warnings remain during engine teardown.
- Default distribution: EXE 103,484,928 bytes; core 16,011,120 bytes; installed
  478,050,990 bytes; compressed 324,673,455 bytes. Vehicle source folders total
  8,188,486 bytes. Workshop PCK 54,684 bytes; tool ZIP 16,228 bytes. Shared asset
  packs and both tracks remain external. Detailed evidence is in `qa-customcars/`.
- Local `check_customcars.ps1` passes. `customcars.yml` creates development-only
  artifacts; it does not publish a release. Physical native-dialog/per-monitor
  DPI interaction remains a user-playtest item. Public release is separate.

After user acceptance, a separate opt-in, unranked arcade suspension preview
may be developed on `physics-v2`. Rendering and audio improvements follow.
Online systems are excluded from this roadmap.

## Verification commands

Run from the repository with the bundled Godot/.NET runtime:

```powershell
./tools/run_godot.ps1 @('--headless','--script','res://tests/content_refresh_test.gd','--','--drive-test','--track=astra_coast')
./tools/run_godot.ps1 @('--headless','--script','res://tests/customcars_boost_test.gd','--','--drive-test','--track=astra_coast')
./tools/run_godot.ps1 @('--headless','--script','res://tests/vehicle_workshop_test.gd','--','--drive-test','--track=astra_coast')
./tools/run_godot.ps1 @('--headless','--script','res://tools/vehicle_workshop/test_workshop.gd','--','--drive-test')
```

Tests use `build/test-userdata`, separate from player settings and rankings.
