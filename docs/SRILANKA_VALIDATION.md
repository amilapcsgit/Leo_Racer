# Sri Lanka v1.3.0 validation

Verified locally on 18 October 2026 with Godot 4.7.2 .NET, SDK 8.0.426,
Blender 4.5.1 LTS, Intel i7-13700H and NVIDIA RTX A1000 6GB Laptop GPU.

## Automated checks

**153 checks passed**: wheel 39, driving 11, visual regression 22, presentation 24,
Sri Lanka assets/HUD 24, smoke 19, full race 8, and layout 6.

All four chassis retain authored wheel transforms, stationary contact behavior,
reverse spin and recovery reset. All 16 driver/kart combinations load. Six racers
finish three laps with ordered checkpoints. Boost/drift, repeated sequences,
impacts, recovery, pause, restart and menu return pass the existing regressions.

The added checks cover the supplied tower, ACES/exposure 1.1, both concrete
boundaries and curbs, national flags, all eight campaign artworks, correctly
populated front/back advertising faces, and five parked transport props outside
the racing boundary. Measured-speed lines stay off below 150 km/h and ramp through
180 km/h without stacking on boost. Nitro reads real fuel, HUD animation freezes
during pause, and Reduced Motion suppresses the new motion effects.

All **34 original model GLBs** match the prior release byte for byte. Driving
and circuit scripts and `track.json` are unchanged. The filtered world retains
the road vertex/index data; see `qa-srilanka/world-split.json`. All 17 new GLB
headers validate, and each near palm stays below 25,000 triangles.

## Performance

A complete warmed-up six-racer race was measured with the real Vulkan Forward+
renderer at **1920 x 1080**, VSync off, a 120 FPS profiling cap, and no dynamic
resolution or headless rendering:

- Average: **98.82 FPS**.
- Median: **10.08 ms**; p95: **11.57 ms**; p99: **12.28 ms**.
- Lowest one-second window: **82.42 FPS**.
- Sampled wall time: **78.72 seconds**; all six racers finished.
- Peak reported video memory: **1.58 GiB**.

The 60 FPS average / 18 ms p95 target is met. Raw frame data and hardware details
are in [render-profile.json](qa-srilanka/render-profile.json). Shared plant
materials, spatial batches, distant LODs and disabled distant shadows bound cost.

## Standalone package and captures

The Windows ZIP was CRC-tested and extracted into a separate folder. The bundled
.NET runtime and Terrain3D native library load with `DOTNET_ROOT` removed. Packaged
smoke checks and a complete race pass; the independent race finished in 72.057s
with 25 checkpoint crossings and 16 boosts. Vulkan and OpenGL compatibility
gameplay were rendered independently of the editor.

HUD layouts passed at exact 1280x720, 1920x1080 and 2560x1080 viewport sizes.
Matching coast, Fort, Lotus Plaza and garden views, every menu, national flags,
posters, transport and representative effects are retained in `qa-srilanka/`.
See [before/after comparison](SRILANKA_COMPARISON.md).

## Known limitations and release identity

Godot .NET / Terrain3D still report a deprecated interpolation binding at startup
and managed-resource/ObjectDB cleanup notices on diagnostic shutdown. Vulkan
reports seven texture RIDs at exit; compatibility rendering has its existing
texture-cleanup messages. The optional EZ Tree demo also has a case-mismatch
editor warning; runtime uses baked tree meshes. These remain documented engine /
addon cleanup limitations. Final gameplay checks have no script or shader errors.

The supplied archives without bundled license metadata are identified explicitly
in `assets/models/srilanka/source-manifest.json` and `licenses/SRILANKA_ASSETS.md`.
No unsupported license grant is asserted for those inputs.

- ZIP: `LeoRacer-Windows-v1.3-SriLanka.zip`, **459,235,914 bytes**.
- ZIP SHA-256: `cbfa2041e02618fae2c2e63380a7225792f049a10d0dbb99556ddb2f8d98a3b3`.
- EXE SHA-256: `f80638f8aa595fb55b7a79a2d05f0d7bad594452c9947b3365ca3288482638b5`.

Extract the entire ZIP and run **Play Leo Racer.cmd**. Keep the data/runtime
directory and Terrain3D DLL beside the EXE. The v1.2 Colombo release and branch
are retained for rollback. See [source setup](SRILANKA_SETUP.md) and
[machine-readable summary](qa-srilanka/summary.json).
