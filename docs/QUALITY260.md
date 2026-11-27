# Leo Racer 2.6 preview validation

Gate status: **PASS**. Measured on the RTX A1000 6GB Laptop GPU at 1920 x 1080, Medium, Godot 4.7.2 .NET. NVIDIA driver 566.14. Each race case uses six racers, six seconds of warm-up and 30 seconds of sampled wall-clock frames. Split-screen places the players half a course apart.

The 2.5 comparison uses the unchanged released controller and runtime, with the same source vehicle packages, balance entries, roster order and six-car lineup. The candidate uses compiled scenes, LODs and prepared textures. This is a local preview; no public release has been published.

## Garage

| Renderer | UI ms | Cold preview ms | Warm switch ms | Worst garage frame ms |
|---|---:|---:|---:|---:|
| forward | 5.78 | 871.20 | 25.11 | 37.20 |
| compatibility | 6.80 | 750.39 | 25.00 | 29.99 |

All four garage targets apply: UI <=250 ms, cold preview <=3000 ms, warm switch <=250 ms and no sampled garage frame >50 ms. Instantiation, driver attachment and material preparation are timed separately from resource loading, GPU warm-up and first visibility. Official model preparation stages remain below the 4 ms CPU budget in the recorded Duster cases. The cache retains at most three previews and uses a 512 MiB estimate; that is not a total-process or measured-VRAM limit. Compatibility prewarms small shader representatives and driver styles during boot; its additional boot time is recorded in the logs.

## Native race frames

| Variant / renderer | Track | Players | p50 ms | p95 ms | p99 ms | Worst ms | Load ms | Static MB | VRAM MB |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| static-forward | kandy_lake | 1 | 8.14 | 11.17 | 11.92 | 22.03 | 2570 | 331.0 | 1582.7 |
| static-forward | kandy_lake | 2 | 10.14 | 12.23 | 14.31 | 119.60 | 789 | 338.9 | 1836.6 |
| static-forward | astra_coast | 1 | 8.68 | 10.39 | 11.02 | 16.46 | 539 | 332.6 | 1807.4 |
| static-forward | astra_coast | 2 | 9.75 | 11.66 | 12.31 | 14.12 | 342 | 307.5 | 1788.6 |
| static-forward | colombo_city | 1 | 7.76 | 11.15 | 11.75 | 15.98 | 366 | 357.9 | 1643.2 |
| static-forward | colombo_city | 2 | 8.31 | 11.13 | 11.72 | 14.98 | 315 | 345.6 | 1615.2 |
| dusk-forward | kandy_lake | 1 | 9.19 | 11.60 | 14.75 | 125.38 | 2938 | 331.9 | 1915.0 |
| dusk-forward | kandy_lake | 2 | 10.62 | 13.48 | 15.06 | 26.83 | 942 | 338.8 | 2216.1 |
| dusk-forward | astra_coast | 1 | 8.54 | 10.13 | 10.62 | 17.32 | 683 | 336.1 | 1818.0 |
| dusk-forward | astra_coast | 2 | 9.50 | 11.45 | 12.06 | 13.22 | 310 | 310.9 | 1785.4 |
| dusk-forward | colombo_city | 1 | 8.22 | 11.15 | 11.71 | 12.88 | 362 | 357.7 | 1640.0 |
| dusk-forward | colombo_city | 2 | 8.40 | 11.11 | 11.68 | 23.75 | 360 | 345.2 | 1625.8 |
| static-compatibility | kandy_lake | 1 | 9.20 | 11.83 | 12.98 | 93.90 | 1921 | 215.6 | 917.3 |
| static-compatibility | kandy_lake | 2 | 10.13 | 15.38 | 16.86 | 28.24 | 697 | 216.2 | 1038.9 |
| static-compatibility | astra_coast | 1 | 8.42 | 10.21 | 11.34 | 120.98 | 2434 | 205.7 | 959.2 |
| static-compatibility | astra_coast | 2 | 8.41 | 10.17 | 10.82 | 18.25 | 215 | 181.0 | 927.0 |
| static-compatibility | colombo_city | 1 | 8.58 | 10.66 | 11.48 | 18.03 | 735 | 227.1 | 840.8 |
| static-compatibility | colombo_city | 2 | 8.78 | 10.79 | 12.07 | 21.26 | 181 | 210.6 | 824.0 |
| dusk-compatibility | kandy_lake | 1 | 9.40 | 12.04 | 13.58 | 24.43 | 696 | 215.6 | 1261.3 |
| dusk-compatibility | kandy_lake | 2 | 10.45 | 16.04 | 17.89 | 197.57 | 375 | 216.3 | 1370.4 |
| dusk-compatibility | astra_coast | 1 | 8.41 | 10.02 | 10.60 | 15.77 | 250 | 209.5 | 955.0 |
| dusk-compatibility | astra_coast | 2 | 8.53 | 10.22 | 11.08 | 14.97 | 192 | 185.0 | 935.4 |
| dusk-compatibility | colombo_city | 1 | 8.68 | 10.81 | 11.80 | 19.47 | 253 | 226.9 | 849.2 |
| dusk-compatibility | colombo_city | 2 | 8.84 | 10.97 | 12.33 | 17.96 | 158 | 210.4 | 819.9 |

The p95 gate is 16.7 ms in every candidate case. p99 and worst-frame values are reported independently; occasional scenery-streaming spikes remain and are not presented as a stutter-free 60 FPS guarantee. Memory values are Godot monitors, not a Windows working-set measurement. Raw frame samples and matched 2.5 rows are included in the evidence archive.

## Functional evidence

- audit: 153 checks, PASS.
- contacts: 226 checks, PASS.
- replay: 2 checks, PASS.
- compiled content: 449 checks, PASS.
- ranking worker: 6 checks, PASS.
- standalone SDK / unsafe-pack rejection: 4 checks, PASS.
- forward environment, viewport isolation, reduced motion and cache checks: 137, PASS.
- compatibility environment, viewport isolation, reduced motion and cache checks: 137, PASS.

The paired 360-tick replay against release/2.5.0 @ 3d37854 has position error 0.0, speed error 0.0 and fuel error 0.0. ContactSolver, CosmeticDamage and the measured-speed race camera remain unchanged. Vehicle collision bounds and seating/bindings are adapted to the recovered geometry.

Content checks cover 21 official cars, Duster 2024 at position 21, retained `duster` selections, Bigster fallback, both Dusters with all six drivers, wheel paths/rolling/steering, independent lamp instances and partial/repeated action reversals. Environment checks cover all three tracks, neutral Kandy bakes, pause/photo freezing, restart, static restoration, night renders, reduced motion, per-player wind layers, exclusive decal/mesh backends, cache eviction and closing during a load. Source integrity verifies all 306 downloaded mod files and the supplied Blender master hashes. The SDK test validates a freshly extracted compiler export and rejects embedded scripts before mounting. Installer fixtures cover modified-file backups, superseded managed assets, reinstall and preservation on uninstall.

## Limits and shutdown warnings

- This is an arcade character-controller racer. Opening panels are cosmetic and retain the fixed driving collision envelope; damage remains the existing bounded cosmetic system.
- Color presets are brochure/screenshot approximations and metadata for a future garage selector. No color-selector code is included.
- Forward+ High solo uses pooled decals; effective Medium split-screen and Compatibility use the pooled mesh backend.
- Medium uses a smaller dynamic-sky radiance map and a nearer shadow budget. High retains larger maps. Kandy editor bake helpers are suppressed while original static lightmap files remain available.
- Native Godot shutdown logs still include leaked-RID/ObjectDB/resource warnings also observed in the 2.5 baseline. They occur during teardown; the validation report does not hide them.
- Frame and memory measurements apply to the recorded machine and workloads. Other hardware, drivers and custom content require their own measurements.

The exported Windows preview and archive-extraction smoke checks are recorded separately in `export-smoke.json` after export. Source files under `sources/`, downloaded mod assets, original Blender masters and the installed game are not modified by preparation.

The final exported executable passes all three tracks in solo and split-screen with SDK paths removed. Final metadata checks cover all 21 vehicles. The compiled installer passes fresh installation, reinstall backups and uninstall preservation in a workspace test target. All 12 Duster/driver assemblies have measured headroom; the final 2024 seating transforms also clear the sloping roof in the reviewed previews.
