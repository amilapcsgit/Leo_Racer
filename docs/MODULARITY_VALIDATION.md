# Modularity validation / v2.2.0

Based on released v2.1.0 (`70961b6`), developed on `modularity`. The user playtested the development build and authorized publication as v2.2.0. Refresh Content was repaired and tested through its actual button before the final export.

## Content and gameplay

- Full migration: **1,205 checks**, sixteen cars × six drivers (96 assemblies). Measured wheel travel/centers, Bigster scale, cabin identities and legacy selections retained.
- Codec round-trip, 40 discovery/cache cases, 21 player-state cases, 35 input cases, 26 ranking cases, 22 workshop cases, six Refresh button/workshop-return cases and a three-lap six-racer integration race passed.
- Extracted development build: raw GLB detection, malformed-model isolation, official fingerprints, cold/warm imports, DDS textures in the exported template, a contributor vehicle and an SDK track. Executable/core hashes stayed unchanged. Cache deletion and read-only vehicle-file attributes tested; this is not a Windows directory-ACL test.
- Full sixteen-car package validated separately. Every vehicle folder has GLB, JSON, thumbnail and license. Twelve packs audited with zero shipped vehicle model entries, including compiled aliases. Shared drivers remain separate.
- Both stock tracks loaded in both modes. Custom 754 m track: six racers completed three ordered laps. Separated-player scenery retains collision/landmarks. Three repeated track changes settled at 1,380 nodes and about 388.3 MB static memory without accumulating growth.
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
