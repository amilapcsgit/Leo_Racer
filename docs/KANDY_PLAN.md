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

## Verified progress (2026-10-25)

- Checkpoint 1, `869c00e`: new loose Bigster, opt-in lighting sources and 128
  validation checks. 413,864 triangles retained, scale 1.3 and cabin fits intact.
- Checkpoint 2, `bd601d6`: Track API3, slope-aware arcade core and per-track
  ruleset. Synthetic elevation/reverse/recovery/boost test passes; local ranking
  tests pass (26 checks), original independently exported API2 example passes.
- Checkpoint 3: offline SDK exports actual Road Generator meshes (32 segments),
  Terrain3D static meshes, shared script-free resources and 200m cells. Bundled
  Python successfully rebuilt all 55 Earth2Road world tiles from archived inputs
  with `--offline` (77 verified files, 4,516 lanes). No dependency installation or
  network access is required by the delivered tools.
- Kandy source route: 2,852m; editable Curve3D bake: **2,827.525m**, clockwise,
  18m road, eight checkpoint/recovery sectors. Gentle height profile is below
  1% grade. The loop is race-adapted geography, not a reconstruction of 2014.
- Kandy scenery: 299 complete modular assemblies, lake/island, lakeside wall,
  promenade, original texture atlas, vector/font Sinhala/Tamil/English lettering,
  streamed hills/trees and cheap resident terrain silhouette. 256 detail cells.
- Mount audit: all Kandy PCK resources stay in its content namespace; no scripts,
  native extensions or references to authoring libraries/addons are required.
- Source six-racer three-lap races pass in single and split screen. Source
  streaming test: 62 checks, stable node counts and no sustained memory growth.
  Final exported-build, packaging and final art/performance validation follow.

## Rebuild / verification commands

```
python tools/stage_track_sdk.py --bundle
build/TrackSDK/author-python/python.exe -m akadem_maps build --config build/TrackSDK/inputs/world/inputs/config.json --inputs build/TrackSDK/inputs/world/inputs --offline --output <NEW_WORLD_FOLDER>
```

Use SDK `Track Kit.cmd -Target export` for content-only export. This never invokes
an executable/core export. `Track Kit.cmd -Target edit-course` opens the bundled
Godot editor. See sdk/track-kit/README.md for all five controls and CLI targets.

Game diagnostics (isolated profile; never use real records for these runs):

```
LeoRacer.exe --headless -- --drive-test --verify-content
LeoRacer.exe --headless -- --drive-test --track-check=split --track=kandy_lake
LeoRacer.exe -- --drive-test --track-check=performance --track=kandy_lake
```

`--track-check=single` runs the single-player regression. `--qa-output=<absolute
folder>` selects report output; otherwise reports go to user://track-check.
Routine QA uses `--vehicles=<folder containing Bigster and Duster>`; installed
community cars remain untouched. No driver content is regenerated.
