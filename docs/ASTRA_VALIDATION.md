# Astra v1.4.0 validation

Verified locally on 18 October 2026 with Godot 4.7.2 .NET, SDK 8.0.426, Blender 4.5 LTS, Intel i7-13700H and NVIDIA RTX A1000 6GB Laptop GPU.

## Goal completion audit

| Request | Delivered behavior and evidence |
| --- | --- |
| Longer, more exciting circuit | 758.24 m becomes **1,905.07 m** (2.51x), with eight boost pads, coastal run, north esses, harbor hairpin, lagoon causeway, gardens and Fort finish. `track-audit.json` and `route-runtime.json`: 953 samples, zero crossings, 16.29 m minimum radius and 65.02 m nonlocal segment clearance. |
| More poster-inspired cars and Shaven Leo | Nine vehicles and five drivers, independently selectable. Five original new Blender vehicles plus original seated human Shaven Leo; editable sources, geometry hashes and seat/collider/exhaust metadata included. `vehicles.json`: **1,264 checks, all 45 combinations**, 40,500 wheel stress frames and 540 recoveries. |
| Vibrant luminous advertising | 148 populated advertising faces use eight festival campaigns, unshaded HDR emission and neon frame materials. Mipmaps and anisotropic filtering keep artwork stable with distance. Final front/back captures confirm orientation and readability. |
| Playable tuk-tuk and bus | Racing Tuk-Tuk and Party Bus are garage choices and appear in each standard opponent lineup. Both have distinct handling, seating, colliders, engine tones, exhausts and horns. All nine vehicles finish three laps in `fleet-race.json`. |
| Generated road decals | Three transparent generated paint PNGs appear at seven route locations; prompts included. Forward-facing typography and transparent exterior checked. Final captures show correct orientation and clean asphalt around paint. |
| Terrain and water | Sculpted coastal dunes and garden hills span -3 to 12.91 m; animated Indian Ocean and Lotus Lagoon, causeway deck supports and rails are active. City footprints exclude the lagoon. Terrain remains separate from the flat driving collision. |
| Better playability | Timed final-beat launch boost, slipstream nitro recharge, drift retention through steering corrections, longer-charge SUPER DRIFT, automatic recovery after three seconds stuck under throttle, engine variation, arcade cues and horns. Expanded map/sector guidance, 5x9 garage focus navigation, Reduced Motion and restart-state resets verified. |
| Publish on astra | Editable source and delivery evidence are on branch `astra`, descending from completed `srilanka`. Prior branches and local Windows ZIPs remain available for rollback. |

## Engine checks

| Suite | Result |
| --- | --- |
| All driver/vehicle combinations and wheel/effect pools | 1,264 checks PASS |
| Route, terrain, water, advertising and flags | 33 checks PASS |
| Keyboard driving, brake/reverse, drift, nitro and checkpoints | 11 checks PASS |
| Launch, slipstream, drift retention, floor-impact filtering and unstuck recovery | 13 checks PASS |
| Rokojori/camera/VFX lifecycle, pause, restart and Reduced Motion | 24 checks PASS |
| Garage/layout/navigation at 720p, 1080p and ultrawide | **790 checks PASS** |
| Built-in smoke and complete six-racer race | PASS; player finishes 25 ordered gates, three laps, 32 boosts |
| Full fleet race | All nine vehicles finish 25 ordered gates / three laps, 156-189 simulated seconds |

Ordinary floor contact no longer emits impact sparks or camera shake. Restart clears F8 photo mode, prior callout timers and instrument smoothing. Preferences are preserved; the longer circuit uses a separate `best_time_astra` record.

The final road shader replaces a sine-based procedural hash with bounded four-corner interpolation. A targeted GPU probe isolated and removed the hard rectangular wetness seams while retaining AmbientCG color/normal/roughness maps, 0.35 profile roughness and wet highlights. See `road-surface.json`.

## Final performance

A warmed-up complete six-racer race used the real Vulkan Forward+ renderer at 1920x1080, with physics interpolation and an explicit 120 FPS cap. Five seconds warm-up preceded **188.60 seconds** of recorded racing. The final road shader, artwork mipmaps and HUD fixes were active.

| Metric | Measured |
| --- | --- |
| Average FPS | **111.77** |
| p95 frame time | **9.87 ms** |
| p99 frame time | 10.17 ms |
| Minimum one-second FPS | 98.13 |
| Full six-racer race completed | Yes |

The requested >=60 FPS average / p95 <=18 ms target is met on this laptop. Full frame series and hardware details are in `qa-astra/render-profile.json`. These measurements describe this local configuration.

## Windows delivery

**LeoRacer-Windows-v1.4-Astra.zip**: 478,260,203 bytes, with the complete .NET runtime, native Terrain3D library, launchers and license notices. The ZIP was integrity-tested, extracted to a fresh folder and run independently of the editor with `DOTNET_ROOT` unset.

- Vulkan smoke: PASS, including pause/settings/resume, recovery, restart, Reduced Motion, speed-line thresholds and all 45 garage combinations.
- OpenGL Compatibility smoke: PASS with simplified effects.
- Vulkan complete race: PASS; all six racers finish three ordered laps, player time 177.145 simulated seconds and 32 boosts.
- Independent ZIP/PCK audit confirms runtime files, route/spec JSON and artwork are bundled; development tests, source Blender files and conversion inputs are excluded from the Windows package.
- Original baseline GLBs and editable source are checked by `tools/verify_astra.py`; detailed outcome is in `qa-astra/delivery-audit.json`.

ZIP SHA-256: `adcab5e049a0d41bbabab4091a9e0a7ab897aed17992da25c4b6d6d4e67c2e20`

## Captures and practical limits

**39 final 1080p captures** cover every garage vehicle with Shaven Leo, all menus, coast/harbor/lagoon/gardens/Fort, flags, both advertising faces, road decals, nitro, high-speed lines, drift and Reduced Motion. `capture-manifest.json` records GPU, renderer, camera and staged HUD state. Tour/effect shots are staged for framing; the separate race and profiling reports verify actual driving.

The pinned engine retains existing shutdown diagnostics: Vulkan reports seven Texture RIDs; OpenGL reports two texture cleanup allocations; some headless/C# runs report ObjectDB/resource cleanup notices. The addon build reports upstream compiler warnings, with zero build errors. No runtime script/shader errors or race-test failures occurred in final checks. Fixed effect pools and repeated recovery/boost tests show no accumulating emitters or stale trails during play.

See [the visual tour](ASTRA_COMPARISON.md), [source/build instructions](ASTRA_SETUP.md) and individual JSON reports in `qa-astra/`.
