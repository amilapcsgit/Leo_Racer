# local2player validation

Base: published v1.6.0 (`8654b6e`). Development branch only; no stable release/tag/installer was changed.

## Implemented behavior

P1 left / P2 right, one physics world, two humans plus four AI and three laps. Each human owns their name, driver, car, control provider, race/lap statistics, boost, recovery and camera feedback. The first finisher waits while the other races; retirement is explicit and completed cars are non-blocking. Shared pause can edit either player's car; those races are excluded from records.

Keyboard, Xbox-style pads and raw joystick/wheel profiles support remapping and saved calibration. Only one keyboard player is permitted. Identical devices remain unassigned after restart unless their identity is unambiguous; selecting an ambiguous device requires a button confirmation. Disconnect clears inputs and pauses the race until reassignment or retirement.

All standard cars including Duster use 165/198 km/h; Bigster uses 180/225 km/h. Acceleration is 18 m/s² and handling is 1.0 for humans and AI. Bigster regeneration, 130% scale and wheel pivots remain intact.

SQLite stores eligible named results transactionally once per session, with separate mode/performance-class and optional vehicle filters. Race and lap rankings are independent. DNF, modified and diagnostic times are excluded. Original v1.6 personal bests remain separately labelled legacy data. Database errors retain the file and leave racing available. Editor and export dependencies have separate locked manifests; the Windows native SQLite DLL is bundled.

CABIN was appended as enum 3. All six selected drivers have cabin poses for both Dacias. Front, side and pose contact sheets plus actual garage/driving captures were inspected. Open-kart assets remain unchanged; Bigster fit scale is applied once.

## Automated verification

| Suite | Checks | Result |
| --- | ---: | --- |
| Input ownership, calibration, remapping, persistence, unplug and identity ambiguity | 35 | PASS |
| Independent two-human state, launch, slipstream, wrong-way, finish/retire and P2 swap | 21 | PASS |
| Split presentation at 1280×720, 1920×1080 and 2560×1080 | 21 | PASS |
| SQLite ordering, filters, atomicity, duplicates, exclusions and persistence | 26 | PASS |
| Twelve Dacia driver identities, fit bounds and scale | 63 | PASS |
| Spawn/contact/barrier/recovery and complete shared-world three-lap race | 10 | PASS |
| Bigster geometry and tire-center regression | 229 | PASS |
| All 96 vehicle/driver combinations | 2687 | PASS |
| Single-player drive | 11 | PASS |
| Legacy visual/gameplay presentation | 24 | PASS |
| Garage, vehicle speed, regeneration and pause-car-change acceptance | 37 | PASS |
| Actual garage/driving screenshots and controls/rankings UI | 18 | PASS |

Full-race integration completed all 24 ordered sectors for all six racers. Source-preservation checks pass for the supplied source assets and existing track geometry. Evidence is in `docs/qa-local2player/`.

## Measured performance

NVIDIA RTX A1000 6GB Laptop GPU, real windowed rendering at 1920×1080. Both human cars were auto-driven for repeatability alongside four AI; they retained separate human race state and cameras. Each renderer used six seconds of warmup and 45 seconds of sampling. VSync disabled, frame cap 120. Left/right views are 958×1080 and 959×1080 with a three-pixel divider; resolution was not reduced.

| Renderer | Mean FPS | p95 frame | p99 frame |
| --- | ---: | ---: | ---: |
| Vulkan / Forward+ | 99.7 | 11.91 ms | 12.81 ms |
| Compatibility / OpenGL | 82.9 | 15.29 ms | 18.02 ms |

Both mean rates exceed the 60 FPS target. Compatibility has occasional frames above 16.67 ms; these measurements do not promise a locked minimum. The benchmark samples moving racing for 45 seconds; full three-lap completion is verified separately by the integration test.

## Offline development package

`build/LeoRacer-local2player-development.zip` contains the complete `Local2Player` folder, self-contained .NET runtime, native SQLite, terrain library and licenses. A new unique extraction was tested without DOTNET_ROOT or a database server. Packaged smoke checks cover single-player recovery/pause/garage, all 96 asset combinations, two shared-world views and a native SQLite write/read transaction. See `offline-package.json` for hash, size and result. Extract the whole folder before running the executable.

Development CI runs source/feature checks, rejects missing assemblies/native SQLite, validates the extracted ZIP and uploads an unpublished artifact. It creates no release or tag.

## Physical testing and limits

Device checks use synthetic Godot keyboard/joystick events and saved profiles. Logitech Formula Force EX hardware is unavailable: physical wheel compatibility remains unverified. No wheel force feedback is implemented. Colombo HDRI and the broader collision overhaul remain outside this milestone. Known engine/resource cleanup warnings at process exit remain visible in logs; no script failures are accepted by the validation scripts.

## Reproduce

1. `./tools/setup_windows.ps1`
2. `./tools/check_local2player.ps1`
3. `./tools/package_local2player.ps1`
4. For GPU evidence, run `tests/local_render_profile.gd` with the real renderer and `-- --drive-test`; repeat with `--rendering-method gl_compatibility --rendering-driver opengl3`.
5. `tests/local_driver_test.gd -- --drive-test --visual-test` captures all cabin combinations; `tests/local_visual_acceptance.gd` captures the actual garage and driving UI.
