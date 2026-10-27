# Leo Racer 2.5 validation

This release builds on `Distinct-v3-final` and retains its driving and AI foundation. The default roster is locked by `assets/config/default-roster-v1.json`: twenty packages, 456 original files, SHA-256 verification. Seven cars are official and thirteen remain imported/modded. The remaining twenty-eight earlier packages are excluded from fresh builds; upgrades preserve installed content.

## Preserved behavior

The balance configuration and `scripts/local/race_ai.gd` are unchanged. The 600-tick unobstructed Bigster manual-input replay matched baseline with **maximum difference 0.0**. Corrected vehicle dimensions, professional finish, lamp/sunroof actions, acceleration, steering, braking, boost and regeneration are retained. Collision response intentionally changes for every vehicle, so new records use `distinct_v4` with the existing elevation suffix policy. Older records remain legacy entries.

The camera's speed-driven dolly coefficient changed from 0.012 to 0.006 metres per speed unit: **half the previous pull-back**. Rest distance, bounds-based clearance, FOV, orbit, reverse precedence and Reduced Motion remain intact. Five speed samples, including reverse and boost, verify the exact ratio; eighty fleet/mode/FOV framing cases pass.

## Driving, race and collision evidence

| Check | Result |
|---|---|
| Selected fleet acceleration / ceilings and Bigster free-space replay | 131 checks pass |
| Presentation, protected surfaces, damage limits, roster fallback | 146 checks pass |
| Contact solver and real barrier / vehicle contact fixtures | 226 checks pass |
| Clean-lap comparison | 60 car/track measurements |
| Bigster advantage over closest official rival | Duster aggregate laps 2.0649456% slower |
| Seeded three-lap AI races | 30 races, 180/180 racers finish (100%) |
| Legal checkpoint and seeded race assertions | 23,064 checks pass |
| Manually installed excluded-car fixture | Selectable; excluded from default AI grid |
| Protected material review | 1,136 checks in each renderer; twenty garage captures each |

The ordered-checkpoint/controller acceptance suite is retained and rerun. Contact fixtures cover low, normal and boost-speed head-on, rear-end and side impacts, static rails, tangent preservation and energy bounds. These fixtures are evidence of the tested scenarios, not proof of every possible collision.

The common contact event drives directional effects, scrape sound and owned gamepad vibration. Maximum budgets are eight body patches per car, 252 skid segments across six cars, and six impact emitters. Local contact sounds route through each player's bus; nearby opponent sounds are spatial and range-limited. Body damage uses only explicitly reviewed paint surfaces and leaves source materials untouched. Recovery retains damage; restarting creates pristine vehicles. Reduced Motion suppresses procedural body movement.

## Renderers and resources

Both Forward+ and Compatibility retain Low/Medium/High quality settings; split-screen caps at Medium. SSR and volumetric mist remain High Forward+ options. Material repair is instance-based. Track shader resources remain referenced until two process frames after geometry removal, preventing native RD null-material errors while allowing retired scenes to release their resources. Native validation rejects these errors as well as parse/script/shader failures.

Untouched gameplay screenshots and contact frame sequences accompany the local evidence. The README key art is AI-generated promotional illustration and is not visual-acceptance evidence.

## Final executable, installer and performance

Final native measurements and exact installer hashes are recorded in the release evidence and SHA256SUMS.txt. The release packaging gate requires native content/camera checks, three-lap races on all tracks in both human modes, a clean twenty-car install, reinstall/custom-content preservation, modified-file backup, uninstall preservation and matching warmed renderer benchmarks.

Matched native benchmarks use an SDK-free executable, the same selected fleet, RTX A1000, 1920×1080, Medium, six-second warm-up and thirty-second samples. Only the built-in diagnostic probe is replaced in disposable copies; game resources remain unchanged. Both renderer modes and separated split-screen are measured. Startup/load time and worst frame are reported separately from warmed p95.

| Renderer | Track | Players | RC p95 ms | 2.5 p95 ms | 2.5 p99 ms | Largest frame ms | Load ms |
|---|---|---:|---:|---:|---:|---:|---:|
| Forward+ | kandy_lake | 1 | 14.437 | 11.106 | 12.315 | 21.739 | 18974 |
| Forward+ | kandy_lake | 2 | 16.363 | 11.753 | 13.523 | 202.545 | 1290 |
| Forward+ | astra_coast | 1 | 10.098 | 10.697 | 11.343 | 17.133 | 1354 |
| Forward+ | astra_coast | 2 | 10.897 | 11.667 | 12.326 | 13.189 | 594 |
| Forward+ | colombo_city | 1 | 10.951 | 10.875 | 11.611 | 18.758 | 1234 |
| Forward+ | colombo_city | 2 | 10.993 | 11.023 | 11.731 | 30.456 | 1114 |
| Compatibility | kandy_lake | 1 | 20.680 | 13.070 | 15.000 | 71.170 | 13260 |
| Compatibility | kandy_lake | 2 | 22.661 | 16.052 | 17.558 | 746.422 | 1456 |
| Compatibility | astra_coast | 1 | 11.248 | 11.647 | 12.899 | 18.241 | 2182 |
| Compatibility | astra_coast | 2 | 9.938 | 10.244 | 11.277 | 23.186 | 430 |
| Compatibility | colombo_city | 1 | 11.513 | 11.953 | 13.214 | 42.458 | 953 |
| Compatibility | colombo_city | 2 | 10.918 | 11.592 | 13.443 | 94.374 | 791 |

All twelve candidate p95 cases meet 16.7 ms; every Compatibility case is within 10% of its matched RC baseline. The largest-frame column is reported separately: these outliers prevent a locked-60-FPS claim. Load time is excluded from the warmed samples. The initial launch/race can take longer while imported models are prepared.

Final tested game core SHA-256: `01035b6b5e7beb52fe0bdad0873a155234cfa850a13529fb5adf9e3dac6e6821`. Native public smoke: nine cases pass (content, both renderer camera suites, and six three-lap races). Clean installation validates all twenty packages and all 456 original files. Reinstall, backup and uninstall-preservation tests pass; an incomplete-payload fixture is rejected before any installation.

## Limits

Automated input assignment checks cannot substitute for a listening session or every physical multi-controller/disconnect combination. Existing engine/importer shutdown resource warnings are distinguished from runtime failures. Startup tracing was added, but the earlier reported stalls have not been established as fixed. Streaming and first-use spikes remain visible in raw results and must not be described as a locked frame rate.

Original reference sources are read-only and preserved. Original `Distinct-v3-final` core SHA-256: `e1f04102a925a4d08dad9476690e59593b74257e7074f04cd803bb41ac92c8b5`.
