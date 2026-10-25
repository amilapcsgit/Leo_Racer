# Car collection checkpoint - 2026-10-25

Completed locally in `build/CustomCars-dev/GameAssets/vehicles`: 31 converted cars, the reused prepared BYD U8, and two unchanged stock Dacias (34 entries). New cars are no-driver, modded/unranked Vehicle API 1 folders. Models and ZIP remain local.

- All 31: source hashes, geometry budget, textures, four wheel pivots, front steering, forward/reverse motion, caliper parenting and two boost anchors validated.
- Front/rear contact sheets reviewed for all 31; spare tyres stay on the body.
- Exported private driving passed: Beetle, Atto 2, widebody Duster and Innova. Acceleration, four wheels and two blue jets checked; zero driver combinations.
- Exported Content UI refresh/discovery passed 15 checks with the installed roster.
- Original GLBs, EXE, core and every initial stock file match baseline hashes. Personal settings/rankings were not opened; tests used isolated user data.
- Installation protection, completed-conversion resume, ZIP CRC and 32 portable-folder checks passed. No unresolved imports.

| Size / geometry | Result |
|---|---:|
| Source GLBs (31) | 464.7 MB |
| Prepared GLBs (31) | 409.7 MB |
| Triangles (31) | 7,434,468 to 4,682,008 (37.0% fewer) |
| Installed car pack (32 including U8) | 727.7 MB |
| Compressed car pack | 359.9 MB |

DDS sidecars add installed bytes while providing precompressed runtime textures. Maximum texture dimension is 2048. Lighter geometry remains unchanged. No full-collection FPS benchmark is claimed.

Local artifacts: `dist/LeoRacer-local-car-collection.zip`, `build/batch-cars/batch-report.json`, `build/batch-cars/package.json`, `build/batch-cars/previews/sheet-{1..4}.jpg`.

Archive SHA-256: `d9afa8a0f2d8a0cbe8a115d03208496bfa449ed100e5dc9b548e4c4aee0cf623`.

| Source | Triangles after | GLB MB | Checks |
|---|---:|---:|---|
| 1937_auto_union_type-c_streamliner.glb | 192,958 | 13.2 | PASS |
| 1968_volkswagen_beetle.glb | 84,529 | 5.2 | PASS |
| 1985_delorean_dmc-12_time_machine_bttf.glb | 199,995 | 17.0 | PASS |
| 1989_lamborghini_countach_25th_anniversary.glb | 82,911 | 7.3 | PASS |
| 1999_nissan_skyline_gtr_r34_c-west__2f2f.glb | 200,000 | 12.1 | PASS |
| 2004_porsche_carrera_gt.glb | 199,999 | 13.9 | PASS |
| 2013_chevrolet_corvette_z06.glb | 71,804 | 5.4 | PASS |
| 2013_equipped_jeep_wrangler_unlimited_rubicon.glb | 49,200 | 9.9 | PASS |
| 2019_ford_mustang_rtr_spec5_10th_anniversary.glb | 199,999 | 12.5 | PASS |
| 2020_ferrari_roma.glb | 199,999 | 12.9 | PASS |
| 2020_jeep_gladiator.glb | 199,995 | 16.0 | PASS |
| 2020_lbworks_toyota_supra_a90_ver.2.glb | 199,999 | 12.2 | PASS |
| 2021_pininfarina_teorema_concept.glb | 81,993 | 10.4 | PASS |
| 2022_bmw_g82_m4_adro_carbon_fiber_widebody_kit.glb | 199,999 | 12.6 | PASS |
| 2022_mclaren_765lt.glb | 199,999 | 12.5 | PASS |
| 2023_ferrari_sf90_xx_stradale.glb | 199,998 | 13.4 | PASS |
| 2024_byd_atto_2.glb | 199,999 | 10.1 | PASS |
| 2024_byd_atto_3.glb | 144,375 | 31.6 | PASS |
| 2024_byd_seal.glb | 136,426 | 29.8 | PASS |
| chevrolet_cruze_ltz.glb | 199,999 | 7.5 | PASS |
| dacia_duster_low_poly.glb | 31,082 | 20.7 | PASS |
| dacia_duster_widebody_-_highpoly.glb | 199,997 | 14.9 | PASS |
| escapamento_carro_da_barbie_1956.glb | 93,675 | 11.1 | PASS |
| fiat_500_x_outlaw.glb | 199,995 | 35.4 | PASS |
| future_car.glb | 130,624 | 11.1 | PASS |
| hiluxbf.glb | 199,999 | 9.8 | PASS |
| mclaren_f1_1993_by_alex.ka.glb | 78,385 | 8.8 | PASS |
| pininfarina_h2_speed.glb | 30,571 | 3.5 | PASS |
| toyota_kijang_innova_zenix_2023_highpoly.glb | 199,995 | 11.7 | PASS |
| toyota_landcruiser_v8_2022.glb | 160,334 | 6.1 | PASS |
| valentines_day_car.glb | 113,175 | 11.1 | PASS |
