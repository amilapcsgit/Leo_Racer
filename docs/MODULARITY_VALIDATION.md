# Modularity validation / v2.2.0

Based on released v2.1.0 (`70961b6`), developed on `modularity`. The user playtested the development build and authorized publication as v2.2.0. Refresh Content was repaired and tested through its actual button before the final export.

## Content and gameplay

- Full migration: **1,205 checks**, sixteen cars × six drivers (96 assemblies). Measured wheel travel/centers, Bigster scale, cabin identities and legacy selections retained.
- Codec round-trip, 40 discovery/cache cases, 21 player-state cases, 35 input cases, 26 ranking cases, 22 workshop cases, six Refresh button/workshop-return cases and a three-lap six-racer integration race passed.
- Extracted development build: raw GLB detection, malformed-model isolation, official fingerprints, cold/warm imports, DDS textures in the exported template, a contributor vehicle and an SDK track. Executable/core hashes stayed unchanged. Cache deletion and read-only vehicle-file attributes tested; this is not a Windows directory-ACL test.
- Full sixteen-car package validated separately. Every vehicle folder has GLB, JSON, thumbnail and license. Twelve packs audited with zero shipped vehicle model entries, including compiled aliases. Shared drivers remain separate.
- Both stock tracks completed three-lap, six-racer races in single-player and two-player modes (four automated races). No premature results; all six racers finished. Custom 754 m track: six racers completed three ordered laps. Separated-player scenery retains collision/landmarks. Three repeated track changes settled at 1,380 nodes and about 388.3 MB static memory without accumulating growth.
- Twelve Dacia/driver garage combinations and six split-screen driving pairs captured after awaiting asynchronous previews. Reviewed sheets are in qa-modularity.
- Isolated installer install/update/uninstall preserve an unknown community vehicle folder and remove the obsolete roster pack. Real user installation/settings/records are untouched by these tests.

## Performance

RTX A1000 6 GB, 1920×1080, two cameras, six automated Bigster/Duster racers on Colombo; 45-second sample after warm-up, 120 FPS cap. Baseline uses v2.1's original imported-model loading path; final uses loose GLBs with the same physics and route. These are local GPU measurements, not hosted-CI results.

| Renderer | Baseline FPS | Loose FPS | p95 ms baseline → loose | p95 change | Loose p99 ms | Worst frame ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| forward_plus | 119.65 | 119.94 | 10.910 → 10.755 | -1.42% | 11.049 | 37.714 |
| gl_compatibility | 116.46 | 119.42 | 10.737 → 10.515 | -2.07% | 10.840 | 71.032 |

Both exceed 60 FPS and stay within the +5% steady-state frame-time budget. Isolated spikes are reported separately. Godot static-memory peaks: 194.8 MB Forward+ / 118.3 MB Compatibility; video allocations: 1,081.4 MB / 578.8 MB. These counters are not Windows process RSS. Cold/warm imports and final sizes are recorded in package evidence.

## Limits

Third-party GLBs still need optimized geometry/materials/textures. Animated wheels require separate mesh groups. Track API 2 currently supports flat circuits; the core owns gameplay scripts/physics. Replacing an already mounted track pack requires restart. Cache deletion is safe; source GLBs remain untouched. Existing Godot teardown resource/RID warnings persist. Physical Logitech-wheel compatibility remains unverified.

The build uses the same checked/debug Godot 4.7.2 template as v2.1. Contributor source and AGPL/third-party notices ship with the game and SDK.

## Final v2.2.0 packages

Sizes use decimal MB (1,000,000 bytes). Installed totals exclude diagnostic outputs and user caches. Category totals separate texture, track and vehicle folders from other shared content.

| Component | MB |
| --- | ---: |
| Executable | 103.485 |
| Core PCK | 15.978 |
| Runtime/support files | 86.364 |
| Shared external assets (excluding textures/tracks/cars) | 39.228 |
| External texture packs | 175.009 |
| 16 loose vehicle folders | 66.223 |
| Astra track | 0.052 |
| Colombo track | 49.658 |
| Full installed distribution | 535.998 |
| Full portable ZIP | 360.633 |
| Two-car installed profile | 477.963 |
| Two-car portable ZIP | 324.625 |
| Core-only ZIP | 84.976 |
| Full Windows installer | 359.810 |
| Contributor SDK ZIP | 0.023 |

The extracted two-car build measured Bigster/Duster cold CPU imports at 0.929 / 0.915 seconds and warm cached scene loads at 0.016 / 0.010 seconds. These are importer/cache timings in the headless exported template, not total loading-screen time or GPU upload measurements. Cache keys include renderer and engine/importer identity. Final offline validation also ran against the installed sixteen-car payload, including the repaired Refresh action.

Artifact CRC, source-model hashes and server upload hashes are verified independently. GitHub release v2.2.0 carries the full installer/ZIP, two-car profile, core-only ZIP, contributor SDK, selected independent content ZIPs and SHA256SUMS. Prior releases remain unchanged.

Hosted Windows CI passed for the release gameplay commit `3a0bf5b`: https://github.com/amilapcsgit/Leo_Racer/actions/runs/40080959268. It validated the full roster, built the modular core/development package and ran exported offline checks. GPU measurements remain the local hardware results above.
