# Colombo v1.2.0 validation

Verified locally on 18 October 2026 using Godot 4.7.2 .NET, .NET SDK 8.0.426, Blender 4.5.1 LTS, an Intel i7-13700H, and NVIDIA RTX A1000 6GB Laptop GPU.

## Automated checks

**129 checks passed.**

| Suite | Checks | Result |
| --- | ---: | --- |
| wheel-test | 39 | PASS |
| drive-test | 11 | PASS |
| visual-regression | 22 | PASS |
| presentation-test | 24 | PASS |
| smoke-test | 19 | PASS |
| race-test | 8 | PASS |
| layout-test | 6 | PASS |

Wheel checks cover all four chassis, authored bind transforms, bounded spin, frame-rate agreement, stationary wall contact, reverse, and recovery. Driving checks cover input, braking, drift, nitro, pause, and restart. Visual checks cover readable sign faces, boost direction, and city clearance. Presentation checks cover Rokojori sequence replacement, actual measured speed, smoke, pooled impacts, trace height, recovery, pause, and Reduced Motion. Smoke checks include all 16 driver/kart combinations. Full-race checks finish all six racers with three laps, 25 ordered gate crossings, and 16 player boosts.

## Performance

The real Vulkan Forward+ renderer was measured at **1920 x 1080** over a complete warmed-up six-racer race. VSync was disabled and the profiling cap was 120 FPS; no dynamic resolution or headless renderer was used.

- Average: **113.81 FPS**.
- Median: **8.47 ms**; 95th percentile: **10.67 ms**; 99th percentile: **11.92 ms**.
- Lowest one-second window: **94.94 FPS**.
- All six racers completed; sampled wall time: **78.83 seconds**.
- Peak video memory reported by Godot: **1.25 GiB**.

The target of 60 FPS average and at most 18 ms at the 95th percentile was met. Raw frame data is in [render-profile.json](qa-colombo/render-profile.json).

## Package and visual verification

The Windows ZIP was CRC-tested, extracted into a different folder, and run without the SDK path. Its bundled .NET runtime and Terrain3D library loaded; smoke and full-race checks passed. Both the Vulkan Forward+ and OpenGL 3.3 compatibility renderers produced gameplay captures. The fallback uses simple particles instead of unsupported ribbon trails.

All menus, the four circuit districts, boost, drift, pause, and results were captured and inspected. Exact 1280x720, 1920x1080, and 2560x1080 offscreen viewports verify the HUD safe area without desktop window-size clamping. Standalone and compatibility captures are also retained under `qa-colombo/`.

All **34 original model GLBs** match v1.1 byte for byte. The truncated published world GLB and Blender source were restored from the working v1.1 copy. Native Terrain3D collision is explicitly disabled; track, barriers, checkpoint data, and driving equations remain unchanged. Existing personal settings were protected by diagnostic flags.

## Known engine cleanup messages

Godot .NET/Terrain3D currently reports a deprecated interpolation binding at terrain startup. Editor shutdown reports cached ObjectDB/resource cleanup notices; Vulkan shutdown reports seven texture RIDs, and OpenGL reports two texture cleanup allocations. Headless packaged checks report remaining managed-resource references at shutdown. These messages are retained in local logs and are an unresolved cleanup limitation. No gameplay script errors, shader compilation failures, or test assertion failures occurred in the final checks. This release is locally verified rather than a claim that every possible bug has been eliminated.

## Release identity

- ZIP: `LeoRacer-Windows-v1.2-Colombo.zip` (140,145,421 bytes).
- EXE SHA-256: `1985b39ffeaa60166140120b1468ab518604e932c51ef3a98a698c72cb0cb5a2`.
- ZIP SHA-256: `0d3a3a784751c292aeb346ebdf2d0152ef7f3d0d71a969b567b685999d40c667`.
- Complete runtime/data folder is required beside the EXE.

See [build-manifest.json](qa-colombo/build-manifest.json) and [COLOMBO_SETUP.md](COLOMBO_SETUP.md).
