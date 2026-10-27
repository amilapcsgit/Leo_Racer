# Leo Racer 2.4.1 — local acceptance report

This private Windows candidate completes the agreed race fixes, restored single-player HUD, realistic sizing, selective material repairs, spring camera, graphics presets, and layered audio. It includes 16 official vehicles, 32 personal imports, and Astra, Colombo, and Kandy. It has not been published.

## Race and controls

Recovery now lifts authored lap-local positions into the racer's completed-lap coordinate system, including collision-avoidance setbacks. Forward checkpoint crossings are validated against movement, road width, and elevation. Recovery and projection jumps cannot award checkpoints; lap/finish notifications are processed once. P1 and P2 retain independent progress and timing.

Late starts and exploration remain unrestricted by choice. Recover returns to the last validated checkpoint, and Pause/Retire/Leave remain available. Split-screen waits for both humans to finish or retire. New records use `distinct_v3` plus the existing elevation suffix; `distinct_v2` and `balanced_v1` records remain accessible as legacy records.

Selecting an occupied controller transfers it to the selecting player. The displaced player gets the next free controller, the former device, or keyboard, in that order. Assignments update together, held inputs clear, and Back cancels confirmation/capture. Independent shared-keyboard layouts remain supported.

The regression suite passed **638 checks**, including actual crossings after recovery on every lap for both slots across all tracks, package classification preservation, wheel scaling, generated-audio bounds, and menu cancellation. Existing input (35), rankings (26), local race (21), Bigster features (53), and copied-fixture Workshop (23) suites passed.

## Size, HUD, and materials

Bigster's runtime prepared-model scale is **1.0**, removing its former 1.3 multiplier. Its measured length is approximately **4.57 m**. Collision dimensions, wheel radii, driver fits, emitters, and camera framing follow the correction. Model-local wheel pivots, lamp anchors, and sunroof motion inherit the chassis transform once. The physics body remains unscaled.

All 48 models were measured. Recognizable real vehicles use length references in `assets/config/vehicle-presentation-v1.json`; the fantasy envelope is 4.4 × 2.0 × 1.8 m. Scaling is uniform, preserving authored proportions, mirrors, accessories, and widebody kits. Reference-generation approximations and the stylized MP4-25 derivative are identified in that manifest. This is a world-size correction, not a reconstruction of inaccurate source geometry. Garage cameras frame corrected bounds without resizing the model to fill the screen.

The original v1.4 instruments are restored for single-player: circular speedometer, curved nitro tube, position/lap/time panels, track/sector/progress banner, minimap, logo, drift feedback, and live binding hints. Compact independent split-screen HUDs remain. Screenshots cover 720p, 1080p, ultrawide, split-screen, and Reduced Motion.

An authored manifest covers every vehicle. It preserves professional PBR and intentional stylized finishes; only six explicitly reviewed surfaces use the shared paint/glass templates:

- `cyberpunk`: GL_basic_Glass_material (glass)
- `import_chevrolet_cruze_ltz`: cruze_window (glass), cruze_glass (glass)
- `import_future_car`: glass (glass)
- `import_toyota_landcruiser_v8_2022`: White (paint)
- `race_bus`: glass (glass)

Protected-surface and preview checks passed **3554 checks in Forward+** and **3554 in Compatibility**. Bigster's existing finish is preserved. Original models and all **1140 installed vehicle files** remain byte-for-byte unchanged; the corrections live in core runtime profiles. Synced `sources/` files were not modified.

## Driving and AI

The 600-tick Bigster manual-input replay has **0.0 maximum difference** against the original controller on the free-space fixture. Acceleration, steering, boost, braking regeneration, and drift mechanics remain unchanged. Collision contacts use the intentionally corrected footprint.

All **144 vehicle/track clean laps** passed. Bigster is fastest by equal-track aggregate; the closest rival is `import_dacia_duster_low_poly`, **2.078% behind**. No extra rival retuning was needed after resizing. The compact launch advantage and formula-car corner opportunities remain measured in the driving/pace evidence.

Ten seeded three-lap races per track completed **180/180 racers (100%)**, rotating all 48 cars, with ordered checkpoints and cached road-position checks. In the controlled obstruction comparison, the original AI accumulated **250 wall-contact frames**, versus **0** for the new AI. The comparison holds vehicle geometry constant to isolate controller decisions. No catch-up speed bonuses or weapons were added.

## Camera, rendering, and audio

The spring rig preserves orbit/look-back/reverse precedence, per-player state, and final collision sweeps after presentation offsets. Default FOV is 63° at rest, 73° at 180 km/h, capped at 85° with boost. Reduced Motion holds the selected base FOV and suppresses procedural movement, shake, and roll.

Chase aim and clearance use the resolved body's centre and length, including single-player long vehicles. The final framing suite passed **192 checks** across all 48 vehicles in both layouts, at the default 63° and selected 55° Reduced Motion setting. Conservative box failures are checked against actual mesh geometry before counting clipping.

Low/Medium/High checks cover all tracks and both player modes in both renderers: **18 quality views per renderer**. Medium is the default and split-screen ceiling. SSR and local volumetric atmosphere are High Forward+ features. Compatibility split-screen keeps sky reflections and two shadow cascades over at most 80 m; authored baked lighting is preserved. The exported executable passed all 10 startup/balance/camera/race cases without an installed .NET SDK.

Audio uses virtual gears, simulated RPM/load, crossfaded generated engine layers, five sound classes, speed-dependent wind/tires, bounded opponent voices, and overhead/zone reverb. Engine loops are periodic, sample bounds are checked, and local-player buses retain volume controls and split panning. Five generated idle examples accompany the evidence. Physical controller/wheel hardware and subjective speaker/headphone listening were not independently verified.

## RTX A1000 performance

Matched Windows 2.3.2 baseline and 2.4.1 candidate: NVIDIA RTX A1000 6 GB laptop GPU, Kandy, 1920×1080, Medium, two separated players, six identical official-roster selections. Each run uses a 6-second warm-up and 30-second sample. Other QA renderer processes are closed before sampling.

| Renderer | Baseline → candidate p95 | p99 | Maximum frame | Vehicle load |
|---|---:|---:|---:|---:|
| forward_plus | 10.527 → 10.787 ms | 10.687 → 11.453 ms | 11.548 → 21.967 ms | 2541 → 2429 ms |
| gl_compatibility | 13.511 → 13.266 ms | 14.638 → 14.400 ms | 73.433 → 696.590 ms | 1980 → 22811 ms |

Both gates passed: Forward+ p95 ≤16.7 ms and Compatibility p95 within 10% of its measured baseline. Maximum frame/loading spikes are reported separately; this update does not claim to eliminate streaming stalls. Measurements describe this benchmark and hardware, rather than guaranteeing every scene on every machine.

The original 2.3.2 build had one access-violation exit during its first Forward+ baseline attempt. That failed sample was discarded and repeated successfully. Successful baselines were retained while the final camera revision's candidate samples were repeated. Exported acceptance and performance reports identify the tested core PCK by SHA-256.

Two automated candidate launches also stalled before reporting game readiness: one headless Astra split-screen launch and one Compatibility benchmark launch. The isolated race retry and a fresh-profile Compatibility retry passed. Native race checks now run serially. The startup stalls' root cause remains unconfirmed; they are retained as a known diagnostic limitation, separate from completed-race correctness. The final Compatibility sample is under `performance-gl_compatibility-candidate-isolated-*` in the evidence.

## Acceptance index

| Suite | Status | Checks/cases |
|---|---|---:|
| race fix | PASS | 638 |
| driving | PASS | 273 |
| pace | PASS | 195 |
| ai | PASS | 22692 |
| comparison | PASS | 5 |
| visual forward | PASS | 3554 |
| visual compat | PASS | 3554 |
| quality forward | PASS | 72 |
| quality compat | PASS | 72 |
| framing | PASS | 192 |
| native | PASS | 10 |
| performance | PASS | — |

Final raw JSON, logs, screenshots, generated WAV examples, original-controller snapshots, and initial calibration results are retained under `build/distinct/` and in the private evidence archive. Development failure logs are historical; the acceptance index above identifies the final passing artifacts.

Godot/add-on shutdown diagnostics about render resources remain in some logs. They are not represented as warning-free teardown. Raycast suspension, airborne handling changes, motion blur, wet-weather conversion, and custom multilayer paint remain deferred.

## Fleet measurements

Dimensions below are measured runtime model bounds including mirrors/accessories. The multiplier is relative to the old assembled model; Bigster's 0.7692 correction restores its prepared-model scale to 1.0. Source references are in the presentation manifest and the fleet audit.

| Vehicle ID | W × H × L metres | Size correction | Normal / boost km/h | Aggregate lap time behind Bigster |
|---|---:|---:|---:|---:|
| aqua | 2.00 × 1.17 × 3.12 | 0.7435 | 163 / 204 | 3.91% |
| bigster | 2.07 × 1.65 × 4.57 | 0.7692 | 180 / 225 | 0.00% |
| blue | 2.00 × 1.17 × 3.12 | 0.7435 | 166 / 207 | 4.05% |
| byd_yangwang_u8 | 2.19 × 1.98 × 5.32 | 1.0408 | 164 / 207 | 5.34% |
| colombo_tuk | 1.38 × 1.80 × 2.79 | 1.0588 | 156 / 200 | 6.18% |
| coral | 2.00 × 1.17 × 3.12 | 0.7435 | 171 / 212 | 3.01% |
| cyberpunk | 1.96 × 1.31 × 4.40 | 0.8721 | 172 / 217 | 2.86% |
| duster | 2.00 × 1.68 × 4.32 | 1.0000 | 171 / 213 | 2.09% |
| formula_blue | 2.00 × 1.30 × 3.62 | 0.8767 | 167 / 212 | 2.75% |
| formula_red | 2.00 × 1.30 × 3.62 | 0.8767 | 169 / 213 | 2.60% |
| hover | 2.00 × 1.11 × 3.26 | 0.7143 | 168 / 210 | 2.47% |
| import_1937_auto_union_type_c_streamliner | 1.98 × 1.09 × 5.80 | 1.0029 | 169 / 213 | 2.17% |
| import_1968_volkswagen_beetle | 1.59 × 1.47 × 4.07 | 0.8848 | 162 / 204 | 4.42% |
| import_1985_delorean_dmc_12_time_machine_bttf | 1.91 × 1.24 × 4.27 | 0.9277 | 168 / 211 | 2.91% |
| import_1989_lamborghini_countach_25th_anniversary | 2.05 × 1.08 × 4.14 | 0.9000 | 169 / 213 | 2.19% |
| import_1999_nissan_skyline_gtr_r34_c_west_2f2f | 1.88 × 1.33 × 4.60 | 1.0000 | 169 / 212 | 2.31% |
| import_2004_porsche_carrera_gt | 2.00 × 1.16 × 4.61 | 1.0028 | 169 / 213 | 2.17% |
| import_2013_chevrolet_corvette_z06 | 2.08 × 1.23 × 4.46 | 0.9696 | 169 / 212 | 2.29% |
| import_2013_equipped_jeep_wrangler_unlimited_rubicon | 1.98 × 2.26 × 4.75 | 1.0328 | 164 / 207 | 5.31% |
| import_2019_ford_mustang_rtr_spec5_10th_anniversary | 2.06 × 1.34 × 4.79 | 1.0408 | 169 / 212 | 2.26% |
| import_2020_ferrari_roma | 2.11 × 1.28 × 4.66 | 1.0122 | 169 / 213 | 2.26% |
| import_2020_jeep_gladiator | 2.01 × 2.03 × 5.54 | 1.2037 | 164 / 207 | 5.37% |
| import_2020_lbworks_toyota_supra_a90_ver_2 | 2.01 × 1.25 × 4.38 | 0.9525 | 169 / 212 | 2.28% |
| import_2021_pininfarina_teorema_concept | 1.69 × 1.14 × 4.40 | 0.9565 | 168 / 211 | 2.82% |
| import_2022_bmw_g82_m4_adro_carbon_fiber_widebody_kit | 2.05 × 1.35 × 4.79 | 1.0422 | 169 / 212 | 2.25% |
| import_2022_mclaren_765lt | 2.16 × 1.20 × 4.60 | 1.0000 | 169 / 213 | 2.29% |
| import_2023_ferrari_sf90_xx_stradale | 2.31 × 1.22 × 4.85 | 1.0543 | 169 / 213 | 2.21% |
| import_2024_byd_atto_2 | 2.09 × 1.67 × 4.31 | 0.9370 | 162 / 204 | 4.40% |
| import_2024_byd_atto_3 | 2.09 × 1.64 × 4.45 | 0.9685 | 162 / 204 | 4.33% |
| import_2024_byd_seal | 2.13 × 1.48 × 4.80 | 1.0086 | 169 / 212 | 2.34% |
| import_chevrolet_cruze_ltz | 2.09 × 1.64 × 4.60 | 1.0048 | 162 / 204 | 4.30% |
| import_dacia_duster_low_poly | 2.02 × 1.92 × 4.34 | 1.0264 | 171 / 213 | 2.08% |
| import_dacia_duster_widebody_highpoly | 1.96 × 1.44 × 4.34 | 0.9437 | 171 / 213 | 2.10% |
| import_escapamento_carro_da_barbie_1956 | 1.93 × 1.30 × 4.40 | 0.9565 | 162 / 204 | 4.29% |
| import_fiat_500_x_outlaw | 1.91 × 1.79 × 3.57 | 0.7763 | 162 / 204 | 4.50% |
| import_future_car | 2.00 × 1.21 × 3.82 | 0.5962 | 168 / 211 | 2.93% |
| import_hiluxbf | 2.33 × 1.85 × 5.32 | 1.1565 | 164 / 207 | 5.31% |
| import_mclaren_f1_1993_by_alex_ka | 1.94 × 1.15 × 4.29 | 0.8460 | 169 / 213 | 2.21% |
| import_pininfarina_h2_speed | 1.98 × 1.11 × 4.73 | 1.0018 | 169 / 213 | 2.23% |
| import_toyota_kijang_innova_zenix_2023_highpoly | 2.09 × 1.76 × 4.75 | 1.0009 | 164 / 207 | 5.44% |
| import_toyota_landcruiser_v8_2022 | 2.20 × 1.86 × 4.98 | 1.0826 | 164 / 207 | 5.34% |
| import_valentines_day_car | 2.00 × 1.10 × 4.17 | 0.8484 | 162 / 204 | 4.33% |
| mclaren | 2.27 × 1.82 × 4.37 | 1.0000 | 166 / 210 | 2.91% |
| pink | 2.00 × 1.17 × 3.12 | 0.7435 | 164 / 205 | 3.83% |
| pony | 1.94 × 1.80 × 3.20 | 0.8608 | 161 / 203 | 4.50% |
| race_bus | 1.67 × 1.80 × 3.14 | 0.7332 | 157 / 201 | 8.97% |
| race_tuk | 1.77 × 1.80 × 3.46 | 0.8571 | 158 / 202 | 5.05% |
| roadster_gold | 2.00 × 1.34 × 3.58 | 0.8767 | 169 / 212 | 2.42% |
