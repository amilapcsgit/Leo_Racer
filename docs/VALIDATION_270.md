# Leo Racer 2.7 Ultra — validation report

The release has 21 cars, six drivers and three tracks. Functional checks pass; performance limits and unavailable physical controller testing are stated separately below. Exact artifact hashes are in SHA256SUMS.txt and the evidence archive's delivery.json.

## Environment and preservation

Windows; NVIDIA RTX A1000 6 GB Laptop GPU; NVIDIA driver 566.14; Godot 4.7.2 .NET. All profiles, database fixtures and installation targets are isolated from the player's settings and installed 2.6 game. The application name and user-data location remain Leo Racer.

The reproducible content baseline is the published LeoRacer-2.6.0-win64.zip, SHA256 `7c2df4a81e4931da8b7039c4ae9c49eafbe7255126ed2dd9181b26fa5087ec5e`, from release commit `87ba2906cde0d9e8f2cb07a87d3d5fd347ce2ce3`. Only LeoRacer/GameAssets is staged; its 21 vehicle packages and three tracks are validated. The benchmark's 2.6 core matches the published ZIP byte for byte (`94b74de373d52051e923f4a7e29b3ab7d7a1a2c9ae5e59f5ed27463e97c6d572`). Original-model preservation checks passed for nine audited sources and 78 inherited Astra geometry/track files. Synced sources, the installed 2.6 build and existing untracked sidecars were preserved.

## Functional evidence

| Check | Result |
|---|---|
| Input / rankings / multiplayer suites | 35 / 26 / 21 checks passed |
| Core laps, records, haptic envelopes and twin-pad routing | 54 checks passed in source and native Windows builds |
| Legacy SQLite compatibility | Actual C# worker passed old-schema and simulated 2.6-writer fixtures; timestamps/results retained, existing sessions backfilled as three laps; user_version remains 1 |
| Collision solver / vehicle audit | 226 / 153 checks passed |
| Native complete content and driver/car presentation | 449 checks passed |
| Native pointer, keyboard, injected controller, focus and typography checks | 1,023 checks per renderer passed |
| Native polish and camera checks | 255 checks per renderer passed |
| Transparent previews, transitions, rapid selection and custom capture | 101 checks per renderer passed |
| Native screen captures and responsive settings | 12 checks per renderer passed |
| Production-controller physics matrix | 2,228 checks passed in source and native export |

All six racers finished 1, 3 and 10 laps on Astra (1,905.072 m), Colombo (5,499.995 m) and Kandy (2,827.517 m): 54 racer completions, with next gates 9, 25 and 81. The physics matrix uses actual track collision and vehicle dimensions, omitting rendering/audio for repeatability. Stationary, drop, landing, recovery, normal-speed and boost stability cover all 21 cars. The native matrix exited without shutdown warnings. Later changes affected responsive settings, preview cache identity and diagnostics; driving code remained unchanged.

There are 84 renderer-specific RGBA PNGs: full 1600×900 hero canvases and cropped transparent thumbnails. Every official-car silhouette had zero-pixel bound difference against the corresponding live render. Screenshots retain loading, half-dissolve and live views. Custom-car fixtures exercise automatic capture, transparency, matching live framing, and invalidation of PNGs and prepared assemblies after a version change. The missing-image fallback and Reduced Motion paths pass.

Screens were inspected at 1280×720, 1920×1080, 2560×1440 and 2560×1080. Settings also pass a 900×900 one-column check and live resize back to two columns. Long names, scrolling, focus restoration, keyboard/pointer routing and injected controller input are covered. Leaderboard names and records in screenshots are isolated fixtures.

Clean Windows CI stages content before tests, exports and builds both packages, verifies native operation with SDK paths removed, tests fresh install and reinstall backup, and checks uninstall preservation of custom content and modified managed files. It also extracts and runs the portable ZIP. The local delivery verifier repeats this protocol before publication; delivery.json records the tested installer and portable hashes. The evidence archive's github-ci.json identifies a successful clean-runner commit and run. See [Windows validation history](https://github.com/amilapcsgit/Leo_Racer/actions/workflows/windows-release.yml).

## Garage timings

Milliseconds, native Medium-quality 1920×1080 runs without another game test running. These representative selected-car tests measure Duster cold loading and Duster 2024 warm switching; they are not an all-model latency guarantee.

| Renderer | UI open | Cold preview | Warm switch | Worst sampled frame | Result |
|---|---:|---:|---:|---:|---|
| forward | 99.264 | 717.687 | 51.624 | 124.471 | MISS: frame peak |
| compatibility | 43.708 | 732.739 | 51.987 | 144.441 | MISS: frame peak |

Targets: UI ≤250 ms; cold preview ≤3,000 ms; warm switch ≤250 ms; sampled frame ≤50 ms. UI/load/switch targets pass. Both renderer frame-peak targets miss: short cold resource/shader stalls remain, despite the immediate aligned PNG. Selected/neighbor preparation retains a three-entry, 512 MiB estimated budget; this is not an exact GPU-memory cap.

## First-impact preparation

Two-player, full-night runs after loading-screen warmup. Values are the two human cars' first contact callbacks in milliseconds. The 2 ms callback target passes in all six cases; the maximum is 1.740 ms. Core checks verify warmup leaves cars undamaged.

| Track / renderer | Callback ms | 2 ms target |
|---|---:|---|
| compatibility-astra_coast | 1.652 / 1.213 | PASS |
| compatibility-colombo_city | 1.676 / 1.147 | PASS |
| compatibility-kandy_lake | 1.645 / 1.142 | PASS |
| forward-astra_coast | 1.740 / 1.161 | PASS |
| forward-colombo_city | 1.709 / 1.149 | PASS |
| forward-kandy_lake | 1.670 / 1.285 | PASS |

## Race frame times and remaining limits

The matched matrix has 48 samples: three actual tracks × solo/split-screen × static/dusk transition × two renderers × 2.6/2.7. Four additional Kandy split-screen samples hold full night for both builds/renderers. Each sample uses a six-second warmup followed by 30 seconds of wall-clock frame times at Medium quality, 1920×1080, VSync disabled and a 120 FPS ceiling. Native windows render outside the visible desktop; these are not headless or minimized runs. Launcher normal priority and execution-speed throttling overrides were requested and accepted. Tests ran sequentially without competing Godot test workloads.

All 13 2.7 Forward+ samples meet the 16.7 ms p95 target. Three 2.7 Compatibility Kandy split-screen samples miss it:

- 2.7-compatibility-dusk: **17.790 ms p95** (MISS).
- 2.7-compatibility-dusk-full-night-kandy_lake-2p: **16.744 ms p95** (MISS).
- 2.7-compatibility-static: **17.434 ms p95** (MISS).

Brief streaming/shader spikes remain: the largest sampled 2.7 frame was 91.746 ms. These samples do not certify a universal locked 60 FPS, all vehicles, all camera positions or every machine. Auto-drive trajectories change with the intentional 2.7 handling changes, and single-run/cache variation limits interpretation of small differences. Godot release static-memory counters returned zero and should be treated as unavailable; GPU timer fields were not sampled, so wall-clock frame times are the performance result.

Rendered Forward+ runs commonly retain seven texture-RID shutdown warnings; Compatibility reports several texture cleanup warnings. Related warnings reproduce in the published 2.6 baseline and editor/headless-import paths. They are retained in raw logs. This establishes a pre-existing teardown symptom, not proof that every warning is engine-only; an isolated minimal engine reproduction was not established. No corresponding native crash occurred in the final functional matrix.

An earlier diagnostic probe put its map-switch side effect inside an assertion, which release templates omit. Those measurements are archived under invalid-map-probe and excluded from the tables. The corrected probe explicitly switches maps and verifies actual track identity/length. A local temporary-file export failure was caught by native boot checks; exports now use workspace temporary paths and reject missing/corrupt ECFG settings. Clean-runner issues involving shallow history, a PowerShell hashing helper and an untracked installer selection include were corrected.

## Physical controller limitation

Godot detected no connected gamepads, and the user confirmed that no controllers are available. Twin-Xbox labels, ownership, assignment input consumption, ambiguous reconnect confirmation, pause/disconnect behavior and bounded rumble envelopes are covered with injected events/output. Physical two-Xbox identification, wireless reconnect and rumble sensation remain **UNVERIFIED**. Wheel force feedback is outside this release.

## Full timing table

| Build / renderer / lighting | Track | Humans | p50 ms | p95 ms | p99 ms | 16.7 ms p95 goal |
|---|---|---:|---:|---:|---:|---|
| 2.6-compatibility-dusk | kandy_lake | 1 | 7.86 | 11.31 | 15.00 | PASS |
| 2.6-compatibility-dusk | kandy_lake | 2 | 10.74 | 18.61 | 25.23 | MISS |
| 2.6-compatibility-dusk | astra_coast | 1 | 7.75 | 9.83 | 10.08 | PASS |
| 2.6-compatibility-dusk | astra_coast | 2 | 8.61 | 10.24 | 11.98 | PASS |
| 2.6-compatibility-dusk | colombo_city | 1 | 7.40 | 10.93 | 11.42 | PASS |
| 2.6-compatibility-dusk | colombo_city | 2 | 8.96 | 11.18 | 12.27 | PASS |
| 2.6-compatibility-dusk-full-night-kandy_lake-2p | kandy_lake | 2 | 9.99 | 17.14 | 24.43 | MISS |
| 2.6-compatibility-static | kandy_lake | 1 | 7.65 | 11.31 | 16.03 | PASS |
| 2.6-compatibility-static | kandy_lake | 2 | 10.15 | 17.49 | 26.02 | MISS |
| 2.6-compatibility-static | astra_coast | 1 | 7.92 | 9.85 | 10.12 | PASS |
| 2.6-compatibility-static | astra_coast | 2 | 8.37 | 9.95 | 10.81 | PASS |
| 2.6-compatibility-static | colombo_city | 1 | 8.33 | 10.90 | 11.49 | PASS |
| 2.6-compatibility-static | colombo_city | 2 | 8.74 | 11.01 | 12.35 | PASS |
| 2.6-forward-dusk | kandy_lake | 1 | 8.79 | 11.62 | 15.49 | PASS |
| 2.6-forward-dusk | kandy_lake | 2 | 10.54 | 14.04 | 23.41 | PASS |
| 2.6-forward-dusk | astra_coast | 1 | 8.59 | 10.09 | 10.52 | PASS |
| 2.6-forward-dusk | astra_coast | 2 | 10.16 | 11.99 | 12.71 | PASS |
| 2.6-forward-dusk | colombo_city | 1 | 9.26 | 10.96 | 11.59 | PASS |
| 2.6-forward-dusk | colombo_city | 2 | 8.96 | 11.40 | 12.26 | PASS |
| 2.6-forward-dusk-full-night-kandy_lake-2p | kandy_lake | 2 | 9.94 | 12.13 | 21.24 | PASS |
| 2.6-forward-static | kandy_lake | 1 | 8.57 | 11.11 | 12.34 | PASS |
| 2.6-forward-static | kandy_lake | 2 | 8.83 | 12.15 | 20.70 | PASS |
| 2.6-forward-static | astra_coast | 1 | 9.01 | 10.37 | 10.99 | PASS |
| 2.6-forward-static | astra_coast | 2 | 8.64 | 10.05 | 10.48 | PASS |
| 2.6-forward-static | colombo_city | 1 | 9.30 | 10.92 | 11.43 | PASS |
| 2.6-forward-static | colombo_city | 2 | 8.17 | 11.11 | 11.63 | PASS |
| 2.7-compatibility-dusk | kandy_lake | 1 | 7.65 | 11.31 | 15.08 | PASS |
| 2.7-compatibility-dusk | kandy_lake | 2 | 10.54 | 17.79 | 24.87 | MISS |
| 2.7-compatibility-dusk | astra_coast | 1 | 7.79 | 9.87 | 10.12 | PASS |
| 2.7-compatibility-dusk | astra_coast | 2 | 8.45 | 10.10 | 11.55 | PASS |
| 2.7-compatibility-dusk | colombo_city | 1 | 8.05 | 11.93 | 12.66 | PASS |
| 2.7-compatibility-dusk | colombo_city | 2 | 9.79 | 13.28 | 14.84 | PASS |
| 2.7-compatibility-dusk-full-night-kandy_lake-2p | kandy_lake | 2 | 10.57 | 16.74 | 23.05 | MISS |
| 2.7-compatibility-static | kandy_lake | 1 | 7.68 | 11.30 | 14.58 | PASS |
| 2.7-compatibility-static | kandy_lake | 2 | 9.99 | 17.43 | 24.05 | MISS |
| 2.7-compatibility-static | astra_coast | 1 | 7.85 | 9.89 | 10.14 | PASS |
| 2.7-compatibility-static | astra_coast | 2 | 8.28 | 9.95 | 10.60 | PASS |
| 2.7-compatibility-static | colombo_city | 1 | 8.12 | 11.00 | 11.70 | PASS |
| 2.7-compatibility-static | colombo_city | 2 | 8.98 | 12.67 | 14.45 | PASS |
| 2.7-forward-dusk | kandy_lake | 1 | 8.83 | 11.63 | 16.10 | PASS |
| 2.7-forward-dusk | kandy_lake | 2 | 10.54 | 13.86 | 23.61 | PASS |
| 2.7-forward-dusk | astra_coast | 1 | 8.86 | 10.05 | 10.51 | PASS |
| 2.7-forward-dusk | astra_coast | 2 | 10.16 | 11.95 | 12.73 | PASS |
| 2.7-forward-dusk | colombo_city | 1 | 8.35 | 11.86 | 13.04 | PASS |
| 2.7-forward-dusk | colombo_city | 2 | 9.12 | 11.91 | 12.92 | PASS |
| 2.7-forward-dusk-full-night-kandy_lake-2p | kandy_lake | 2 | 10.06 | 12.36 | 21.68 | PASS |
| 2.7-forward-static | kandy_lake | 1 | 8.70 | 11.33 | 15.90 | PASS |
| 2.7-forward-static | kandy_lake | 2 | 8.95 | 12.20 | 20.16 | PASS |
| 2.7-forward-static | astra_coast | 1 | 9.14 | 10.70 | 11.42 | PASS |
| 2.7-forward-static | astra_coast | 2 | 8.79 | 10.15 | 10.62 | PASS |
| 2.7-forward-static | colombo_city | 1 | 8.63 | 11.97 | 12.98 | PASS |
| 2.7-forward-static | colombo_city | 2 | 8.49 | 11.26 | 12.09 | PASS |
