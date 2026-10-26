# Kandy scenery — 2.3.1

Kandy now uses physical PNG signs, an anchored start truss, correctly attached national flags, three distant mountain layers, and a 4096×2048 daylight panorama paired with a linear half-float EXR. The existing 1024-point route, checkpoint layout, handling and course revision 1 are unchanged (2827.5166 m).

The supplied Tooth Temple replaces the damaged mesh. Mahaweli Seya retains its complete 60 m white silhouette while its dark lower supports are removed. Buddha, jungle temple and CEYPETCO derivatives retain source materials and textures. Ground transitions meet the sampled terrain. The original downloads and synced sources are read-only references.

## Authoring

Use Blender 4.5.1, Godot 4.7.2, and the pinned OpenSKP 0.2.4 importer described in `content/toolchain/kandy231-importer.json`. Provision dependencies under `build/kandy231/dependencies`; do not install into a system Python. Direct temporary/profile directories into `build/kandy231`.

1. Run Blender with `--background --python tools/prepare_kandy231_models.py`. Original filenames are listed in `content/scenery/kandy-supplied-models.json`; outputs go to `build/kandy/supplied-models/runtime`.
2. Run `tools/prepare_kandy231_art.py`, then Godot's `tools/typeset_kandy_sign.gd` to shape the exact Sinhala and Tamil copy. Run Blender with `tools/bake_kandy231_sky.py` for the matching environment assets.
3. Run `tools/stage_track_sdk.py`, then `tools/build_kandy231_track.py`. The latter prepares three native precinct scenes, runs one editor bake per scene, and exports with a real GPU so layered lightmap textures survive serialization. `--export-only` reuses existing bakes for changes outside those precincts.
4. Run `tools/build_release_231.ps1`, followed by `tools/verify_kandy231.py`, `tools/verify_release_231.py races`, and `tools/verify_release_231.py cars`.
5. Capture with `tests/kandy_capture.gd` in Forward+ and Compatibility; `tests/kandy231_closeups.gd` captures all five imported landmarks. `tools/profile_kandy231.py` runs serial 1080p six-racer profiles in both renderers, for single player and separated split-screen.

The sky is authored radiance, including a solar peak above 200 linear units; the generated cloud photograph alone is not presented as HDR. A periodic longitude boundary is baked into both maps and checked after export. Actual mountain geometry supplies translation parallax; the sky does not translate with the player.

## Export and compatibility

API3 lighting accepts paired `sky_visual_path` and `sky_lighting_path` plus `sky_horizon_offset`; resource paths must remain inside the track namespace. `authored_signage` defaults to false. Older tracks retain their default labels and lighting. Kandy 1.0.1 requires core 2.3.1.

Baked precincts remain intact through streaming and bypass generic static batching. The resource baker preserves HDR images, TextureLayered data, mesh bindings and nested resource dependencies. Monotonic serialization names prevent nested resources from overwriting one another. Reconstructing native nodes removes imported scene inheritance that caused the reported `mahaweli2/mahaweli` and `tooth_temple2/tooth_temple` name clashes.

## Evidence and limits

`docs/qa-kandy231/acceptance.json` records the final checks and hardware-specific performance measurements. Contact sheets compare matching lap cameras and show landmark close-ups. Full PNGs and diagnostic logs remain under `build/kandy` and `build/kandy231`.

The native editor can still emit its pre-existing shutdown list/tree warnings. Bake completion, nonempty lightmap textures, runtime bindings and clean exported dependency loading are checked separately. Forward+ and Compatibility are both inspected; performance results are measurements on the recorded GPU, not a promise for all hardware.

The isolated installer upgrade test preserves settings/record file markers, an extra car, a custom car and modified content backups. It does not migrate or alter a real player's live database. Public release publication follows acceptance and artifact checksum verification.
