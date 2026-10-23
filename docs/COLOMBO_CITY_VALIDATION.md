# Leo Racer 1.8 / Colombo City validation

The new circuit measures **5,499.995 m**, with 2,750 route samples, 18–24 m road widths, 22 Road Generator authoring points, no route crossings and a minimum measured radius of 54.9 m. The original **1,905.072 m Astra Lotus Coast** remains selectable. Both support six racers and three laps in single player and vertical split screen.

## Preserved content and scenery

Fourteen protected source hashes pass, including the original Astra route, Lotus Tower, Bigster model, scale definition and wheel configuration. Vehicle/driver regression evidence is consolidated in `qa-colombo-city/legacy-regressions.json`. All 96 combinations load; Bigster's 229 replacement/wheel checks pass.

The licensed building library contains 34 reusable buildings and four infrastructure pieces. The layout uses 295 street buildings, 176 skyline buildings, 416 palms and 250 railing sections, with 9.09 m minimum building clearance from the raceable road edge. Galle Face Green, the lake, custom pavilion/pool and Lotus Tower have exclusion areas. Pavilion/pool mesh subsets preserve the original triangle attributes; obsolete original track furniture is excluded. The nine-view reviewed contact sheet is `qa-colombo-city/city-contact-sheet.jpg`.

There are **53 occupied 200 m scenery cells**, with 14 initially resident. Detail follows the combined demand of both humans, with 600 m loading / 850 m unloading hysteresis. Roads, barriers, checkpoints and landmark silhouettes remain resident. Three repeated track changes retain 928 nodes and approximately 351.5 MB of CPU allocations, with a 12-resource cache; the last two memory samples differ by under 3 KB. See `streaming.json`.

## Gameplay, loading and records

- Three-lap city runs complete in both modes. Two-player finishing is independent; the recorded split run finishes all six racers. Original-track race, input, driver, presentation, garage and collision regressions pass.
- Left/right layout, separate names and shared physics pass at 1280×720, 1920×1080 and 2560×1080. Inputs, disconnect handling, safe swaps and non-blocking finished cars retain their earlier regression coverage. Physical Logitech wheel compatibility remains unverified because hardware is unavailable.
- Sixteen asset-contract checks cover catalog failures, pack checksums, safe override paths, loose GLB/PNG/SVG loading, lazy model metadata and Retry/Back recovery. Twenty-seven track/ranking checks and 26 legacy ranking checks cover course revisions, transaction persistence, duplicate prevention and modified-run exclusion.
- Loading was measured with a rendered 1080p window. Cold city loading spans 167 animated frames, with p95 10.05 ms and maximum 138.99 ms. Warm city loading has p95 25.70 ms; selected preview and racer insertion peaks are 127.45 / 94.01 ms. Brief insertion hitches remain visible; these are recorded separately from warmed race performance.
- The user reports extensive manual play of both tracks without crashes and approves publication, with further visual refinement deferred.

## Performance

RTX A1000 6 GB Laptop GPU, 1920×1080, six racers, two humans starting on opposite sides of the city, 45-second samples after warm-up, 120 FPS cap. Original source measurements: Vulkan 120.01 FPS / p99 10.96 ms; Compatibility 119.97 FPS / p99 10.70 ms. Final exported-template measurements are stored in `performance-*-separated.json`, marked `exported_checked_template` when collected. Both exceed the 60 FPS target. The reports include physics time, draw calls and both players' route positions.

## Offline delivery and sizes

The installer and a fresh portable extraction pass with SDK environment variables removed and separate test user data. The native SQLite engine works offline. Missing shared packs, damaged checksums and missing track scenery fail with readable errors. An additional compatible track folder is discovered and raced without rebuilding the executable. Installer content tests use `/CONTENTTEST` to avoid changing an existing installation's registry entries or shortcuts; the test installation is then uninstalled.

Local pre-release sizes (decimal MB; CI artifacts have their own SHA-256 values):

| Component | MB |
|---|---:|
| Executable | 103.485 |
| Core package | 10.693 |
| Shared content packs | 253.519 |
| Astra track folder | 0.052 |
| Colombo track folder | 41.216 |
| Complete installation, including bundled .NET runtime | 496.749 |
| Portable ZIP download | 362.019 |
| Installer download | 360.720 |

The separate WinForms launcher and duplicate runtime are omitted. Launch `LeoRacer.exe` or `Play Compatibility.cmd`. Packed resources retain Godot import remaps and texture compression, with no duplicate raw building sources shipped. Licensing and the offline OSM reference/attribution are included under `GameAssets/licenses`.

## Checked template and remaining engine issue

The optimized Godot 4.7.2 Windows template intermittently exits with native heap/access violations after the automated Colombo smoke report has already passed. Reproductions cover both renderers, unsplit official and categorized PCKs, and a run without the unused Terrain3D native extension. Source/editor and the checked debug template exit cleanly. This does **not** establish the underlying engine defect's cause.

Version 1.8 therefore uses a standard **ExportDebug / checked Godot template**, with locked non-editor .NET dependencies and stripped PDB files. This is the tested distributed binary. Cleanup RID/resource warnings remain in diagnostic logs and are not treated as functional passes. The optimized-template issue remains a follow-up; no crash exit code is suppressed or retried into a pass. Terrain3D remains available for legacy editor authoring, but is unnecessary for either playable track and is omitted from installed native extensions.

## Reproduce

```powershell
./tools/setup_windows.ps1
python -m pip install -r tools/requirements-city.txt
./tools/check_city.ps1
./tools/build_city_release.ps1
python tools/package_city.py --version 1.8.0 --public-release
./tools/build_installer.ps1 -Version 1.8.0 -BuildFolder build/ColomboCity -CityAssets
./tools/verify_city_installer.ps1 -Version 1.8.0
python tools/city_checksums.py --version 1.8.0
```

The city workflow builds branch artifacts. `release/1.8.0` additionally publishes the verified artifacts as `v1.8.0`; existing public tags/assets are never overwritten. Stable 1.7 remains available.
