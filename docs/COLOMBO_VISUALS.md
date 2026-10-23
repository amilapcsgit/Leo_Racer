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

## Completed checkpoint 1

Pinned MIT terrain reference `71ff8c8`; 41 audited components, twelve baseline
driving views and protected course/vehicle hashes. Baseline split-screen Vulkan:
118.00 FPS, p95 11.44 ms, p99 12.67 ms at 1080p on RTX A1000.

## Completed checkpoint 2

Twelve assembled recipes render correctly in `qa-colombo-visuals/recipes.jpg`;
shop entrances are grounded, upper storeys supported, flat/pitched roofs capped.
Shared module scenes retain source UV/materials. Headless recipe loading and roof
placement checks pass under Godot 4.7.2. District prototype captures follow with
the baked placement checkpoint, using the same reviewed recipes.

## Completed checkpoint 3

1,265 assembled buildings (633 secondary-row), 204 skyline towers, 140 palms
and 180 reused railing pieces. Four district types; minimum footprint-to-road
clearance 7.09 m. Existing Colombo route/course and all protected assets retain
their hashes. Persistent low-detail district hulls cover streamed detail.

Bounded 5 m terrain mesh samples, matching tile-edge normals, shaped shoreline
and lake, separate water materials, seeded short-range grass and batched seawall.
Terrain checks cover 8,250 road/pavement samples and clockwise visible faces.
Both-player streaming: 35 checks pass; 57 cells, 15 initially resident, cache 12.
Three reloads retain 1,363 nodes and approximately 392 MB static allocations;
last two samples differ by 18 KB. Existing engine cleanup warnings persist with
exit 0, as at baseline. Reviewed prototype: districts-prototype.jpg.

## Completed checkpoint 4

Built-in imagegen panorama is native 1774x887 (2:1); full prompt and provenance
are in assets/art/colombo/PROVENANCE.md. It is a visual matte, not measured HDR.
An independent 1024x512 float EXR has peak linear radiance 1801.07. The cubemap
lighting pass uses that map; the visible sky uses the matte with wrap blending.
Explicit world bearings keep ocean west, city inland. Sun is high midday at
(-65,-145,0), restrained bloom, no default SSR or volumetric fog.

The lighting contract passes: 2:1 visual, genuine float values above 100, separate
shader lighting, disabled expensive effects, unchanged official course revision 1.
Three older acceptance expectations predated neon_ui: loading heading, the HUD
update owner, and a removed pause-garage New Race action. Tests now exercise the
current loading state, actual player HUD, and visible Keep Racing button. Product
UI and driving behavior are unchanged. Full regressions and package checks follow.

## Checkpoint 5: source integration verified

`tools/check_colombo_visuals.ps1 -WithGameplay` exits 0: new building/terrain/HDR
contracts plus the complete city, legacy vehicle and neon UI checks pass. Final
Bigster acceptance is 37 checks; source wheel/pivot regressions retain all 229
replacement checks. Three-lap runs finish all six racers in both city modes.

Final 1080p six-racer separated-player measurements (120 FPS cap): Vulkan
119.99 FPS, p95 10.57 / p99 10.78 ms, maximum 22.87 ms, engine peak static
224.88 MB and video allocations 1738.48 MB. Compatibility 119.67 FPS, p95 10.47 /
p99 10.75 ms, maximum 74.74 ms, static 132.38 MB and video 669.22 MB. These are
source/editor-engine measurements, not a claim of maximum uncapped throughput.
An isolated Compatibility frame spike remains; do not hide it behind the average.

Three reloads retain 1,371 nodes, cache 12; final memory samples differ by about
18 KB. Short-range detail remains separate from permanent collision and LODs.
Garden textures and building aprons were corrected after final visual review.

Loading animation: cold-city 185 frames, p95 11.25 ms, largest 135.75 ms. Warm
city p95 13.90 ms / max 136.58 ms; garage preview max 142.87 ms. Insertion spikes
remain visible. Final street and landmark sheets, plus split views at 720p,
1080p and ultrawide, are in qa-colombo-visuals.

Next: rebuild the committed integration, verify extracted portable content with
SDK variables removed, exercise both renderers, and record final package sizes.
Development CI uploads artifacts only and has no publishing job.
