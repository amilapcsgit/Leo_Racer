# Colombo visuals recovery notes

Base: `neon_ui` / `e20c7ed` (2.0.0). Branch: `colombo-visuals`.
Delivery: unpublished offline development ZIP; do not modify release tags.

## Contract

Bright tropical midday, assembled metre-scale modular buildings, coherent district
blocks, shaped coast/lake and a generated distant Colombo panorama. Preserve UI,
vehicles, wheel pivots, input modes, both circuits, collision and ranking revision.
Keep Galle Face Green, Lotus Tower and pavilion/pool exclusion areas intact.

## Checkpoints

1. Baseline and semantic module inventory; pin MIT terrain source.
2. Twelve complete recipes and representative block/waterfront captures.
3. District placement, bounded terrain, coast and independent ocean/lake water.
4. Generated panorama plus independently authored linear HDR lighting and midday.
5. Render/performance/streaming/gameplay regression and offline development ZIP.

Commit and push each verified checkpoint. Update this document with evidence and
limitations, including failures; no crash exit may be suppressed into a pass.

## Baseline findings

Old importer gives every mesh its own ground origin and multiplies lowrise pieces
by six. Roofs/upper storeys become standalone buildings; short caps/props disappear.
Placement uses single strips with 10 m gaps and one flat ground plane. Both water
bodies use old Astra shoreline coordinates. These are scenery issues, not reasons
to change the race surface.

## Verification

Use bundled Python from `C:/Users/amilapcs/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`.

```powershell
./tools/run_godot.ps1 --script res://tests/colombo_visual_capture.gd -- --drive-test --before
python tools/colombo_baseline.py
python tools/audit_city_course.py
./tools/check_city.ps1
./tools/run_godot.ps1 --script res://tests/colombo_visual_capture.gd -- --drive-test
./tools/run_godot.ps1 --script res://tests/city_render_profile.gd -- --drive-test --separated-players
./tools/run_godot.ps1 -Compatibility --script res://tests/city_render_profile.gd -- --drive-test --separated-players
```

Full-size before/after views belong under ignored `build/colombo-visuals/`; commit
compact reviewed contact sheets and measured reports under `docs/qa-colombo-visuals/`.
