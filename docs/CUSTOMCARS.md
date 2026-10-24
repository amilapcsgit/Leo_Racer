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
- `content_refresh_test.gd`: PASS, 14 checks (pointer delivery, not signal emit).
- `customcars_boost_test.gd`: PASS, 9 checks using actual game assembly/effects.
- Physical Windows DPI/native-dialog interaction still needs visual verification.
- Existing renderer-resource teardown warnings occur in headless game tests.

## Remaining checkpoints

2. Separate-process Vehicle Workshop and replaceable tool PCK; guided wheel
   detection/correction, material-preserving conversion, local private test,
   staged portable folder export. Original GLBs stay untouched.
3. Exported offline package, both-track/split-screen regressions and contributor
   instructions. Development delivery only; public release is separate.

After user acceptance, a separate opt-in, unranked arcade suspension preview
may be developed on `physics-v2`. Rendering and audio improvements follow.
Online systems are excluded from this roadmap.

## Verification commands

Run from the repository with the bundled Godot/.NET runtime:

```powershell
./tools/run_godot.ps1 --headless --script res://tests/content_refresh_test.gd -- --drive-test --track=astra_coast
./tools/run_godot.ps1 --headless --script res://tests/customcars_boost_test.gd -- --drive-test --track=astra_coast
./tools/run_godot.ps1 --headless --script res://tests/vehicle_workshop_test.gd -- --drive-test --track=astra_coast
```

Tests use `build/test-userdata`, separate from player settings and rankings.
