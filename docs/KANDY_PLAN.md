# Kandy development recovery

Base: customcars `be3156b`. Branch: `kandy`. Public releases are unchanged.

Approved delivery: checkpoint-024 Bigster lighting, elevated Track API 3,
offline Godot authoring kit, a 2.8–3.5 km clockwise Kandy Lake circuit with
bright daylight, and separate offline development/content/SDK packages.

## Checkpoints

1. Integrate the existing opt-in Bigster finish/lighting sources, preserve the
   loose checkpoint-024 model and cabin fits, and establish baselines.
2. Add API 3 and `arcade_elevation_v1`; preserve API 1/2 behavior. Validate
   grades <=6%, vertical radius >=1,000 m, 14 m minimum width and 18 m default.
   Add slope-aware movement, alignment, spawn/recovery, wheel travel and cameras.
3. Extend the standalone authoring kit: cached Earth2Road import, Road Generator
   0.9.5, Terrain3D 1.0.2, script-free baking, independent validated export.
4. Complete Kandy geometry, lake/wall/island, landmark massing, town/hills,
   original generated texture atlas and separately lettered multilingual signs.
5. Verify six racers/three laps in both modes, both previous tracks, split-screen
   streaming, lighting/pivots, records, cold/warm loads, performance, extracted
   packages and modular replacement with unchanged executable/core hashes.

Commit and push after verified checkpoints. Models supplied by the user remain
local. No network systems, first-run downloads, traffic, simulation suspension,
banking, jumps, stacked roads or public release are included.

## Local recovery paths

- `build/Kandy-dev`: independent development installation. The original
  CustomCars-dev installation and community car folders remain untouched.
- `build/kandy/baseline.json`: original executable/core and vehicle hashes.
- `build/kandy/baseline-bigster`: old vehicle outside discovery folders.
- `build/kandy-bigster`: copied QA input/output; original checkpoint untouched.
- `build/kandy/earth2road-upstream`: acquired upstream source before pinning.

## Verification entry points

Use `tools/run_godot.ps1` with `--drive-test` for isolated user data. Run the
checkpoint-024 test with BIGSTER_QA_ROOT pointing at build/kandy-bigster and
LEO_ASSET_ROOT at the new development GameAssets folder. New elevation and kit
checks will be documented with their measured results as they land. Preserve
the detailed Bigster source; measure its cost before proposing simplification.
