# Leo Racer contributor SDK

Requires Godot 4.7.2 for authoring. Players need only the modular Leo Racer build (core API 2.2.0); no editor, SDK or network is needed to play your content.

## Vehicles

1. Export a self-contained GLB 2.0 from Blender. Keep wheels separate from the body, retain materials/UVs and embed images. The setup tool can bind arbitrary node names; it cannot split a combined wheel/body mesh.
2. Put the GLB directly in `LeoRacer/GameAssets/vehicles`, open **Content → Set Up Vehicle**, and confirm orientation, size and grounding.
3. Add one wheel per rolling group. Bind rotating mesh/groups and optional stationary calipers. Set its model-space pivot, unit axle and world rolling radius; mark steering wheels. Spin/steer the preview to check it.
4. Fit collision, choose driver policy, inspect all six driver fits, and set the preview camera. Drag the 3D preview to orbit; use its mouse wheel to zoom. Distances are metres; UI speeds are km/h.
5. Validate, use **Private Test Drive**, drive at least a metre, then finish the test and save. **Back → Refresh Content** discovers the complete folder. Share that folder or ZIP it under `GameAssets/vehicles/<id>/`.

Keep IDs stable and unique. Increment `version` for updates. `vehicle.json` follows Vehicle API 1 (`schemas/vehicle-v1.schema.json`). Stock vehicles retain their official resolved performance; new vehicles default to 165/198 km/h, 18 m/s² acceleration and handling 1.0. Custom tuning/content cannot enter official rankings. Retain original licenses and provide your own attribution/redistribution terms.

For textured models, optionally run the editor-only `vehicle-tools/optimize_vehicle.gd` script with `--vehicle-folder=<absolute-folder>` and `--max-texture=2048`. The packaged SDK includes a standalone vehicle-tools project: run `godot --headless --path vehicle-tools --script res://optimize_vehicle.gd -- --vehicle-folder=<folder>`. In the source repository the same script lives under tools/. It writes optional `optimized-textures.json` and GPU-compressed DDS sidecars, preserving the original GLB and UVs. Include the sidecars when sharing. Runtime never needs the compressor. Re-run optimization after changing the GLB.

The installed game's `LeoRacer.console.exe --headless -- --validate-vehicles` checks discovery, wheel bindings, fingerprints and imports. It reports cache use and compressed material counts. Vehicle API 1 sources remain loose; Vehicle API 2 assets live in namespaced PCKs. Disposable import caches live in the existing Godot user-data directory. Deleting caches is safe.

## Track kit

Open `track-kit/project.godot` and `example.tscn`. Select the root node. Its initial example is a closed 754 m circuit; **Route** is an editable Path3D. Use the inspector's **Refresh grid, checkpoints and recovery helpers** after changing it.

- Track API 2 currently supports flat circuits at Y=0, three laps and eight ordered sectors. Minimum road width is 12 m. Keep curves smooth and corridors apart; the exporter rejects sharp corners and near-overlaps.
- Put permanent scenery and essential collision under **Scenery**. Put decorative mesh groups under **Details**; these are grouped into 200 m streaming cells. Decorative collision and gameplay scripts are rejected.
- The exporter bakes race surface, road collision, continuous barriers, route, grid and recovery data. Existing gameplay derives AI guidance, minimaps and progression from that route.
- Use **Validate and export track folder**. Headless equivalent: `godot --headless --path track-kit --script res://export.gd -- --output=<destination>`.
- Copy the complete output folder into `GameAssets/tracks/` while Leo Racer is closed. Launch or refresh content to discover a newly installed ID. The executable is unchanged. Restart after replacing an already mounted track pack.
- Change the stable ID for a different course; increment `course_revision` for route/collision changes and `content_version` for updates. Supply a license for all added assets. Custom tracks are modded/unranked.

The original API 1 Astra/Colombo folders remain compatible. Original published records are preserved. There is no online workshop, executable mod scripting, vehicle part swapping or force-feedback extension in this SDK.

## Vehicle API 2 (core 2.6)

Use `vehicle-tools/Compile Vehicle.ps1 -VehicleFolder <validated-api1-folder> -Output <new-output-folder> -Godot <godot-console.exe>`. The source is preserved. The output contains `vehicle.pck`, API 2 `vehicle.json`, and copied thumbnails, presets and credits. Distribute under `GameAssets/vehicles/<id>/`. Loose Vehicle API 1 remains supported.

The compiler prepares materials, generates mesh LODs, compresses desktop textures with mipmaps, and records model-local presentation bounds. Model and preview scenes live under `res://leo_vehicles/<id>/`; all dependencies must stay there. Runtime mounts without replacing existing resources. Packs with conflicting paths, invalid hashes, executable file entries or external dependencies are rejected. Restart the game after replacing a mounted pack. Custom packs remain unranked.

`preview_scene` may name a separate compiled preview within that namespace. `compiled_bounds` contains three-element `position` and `size` arrays before the manifest normalization transform. `estimated_bytes` is a conservative cache estimate, not a measured VRAM figure. Original Blender masters belong outside the installed discovery folder. Color presets are documentation for future garage customization.

The optional `shader_warmup_scene` is a small compiler-generated scene with representative materials and 1-pixel textures. Compatibility draws these behind the initial loading screen to avoid first-use shader compilation in the garage; it does not load full vehicles or consume a preview-cache slot. Keep it in the same vehicle namespace.

Custom compiled packs must use uncompressed binary scene/resource containers as emitted by this compiler (their texture payloads remain compressed). Embedded CPU scripts, native extensions, scene signal wiring and method/audio animation tracks are rejected. Model scenes use basic spatial, mesh, skeleton, animation-player and particle nodes.
