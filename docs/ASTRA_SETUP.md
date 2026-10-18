# Astra v1.4.0 source and asset pipeline

Branch `astra` descends from completed `srilanka`. Previous branches and Windows releases are preserved. Toolchain: Godot 4.7.2 .NET, SDK 8.0.426 and Blender 4.5 LTS. Run pinned setup in [COLOMBO_SETUP.md](COLOMBO_SETUP.md); the historical launcher names still work for this checkout.

## Rebuild authored assets

Run from the repository root:

```powershell
blender --background --factory-startup --python blender/build_astra_vehicles.py
python tools/build_astra_track.py
python tools/make_astra_audio.py
```

The Blender script builds original Formula Blue/Red, Lion GT, racing tuk-tuk, microbus and Shaven Leo. Self-contained GLBs are in `assets/models/astra/`; editable `.blend` files are in `assets/models/astra/source/`. Its `.gdignore` makes runtime imports use the deliberate GLB exports. Cars face -Z, use metre scale, four independent X-axis wheel nodes with identity bases, and 0.49 m wheel radius. The compact tuk-tuk uses closely paired front wheels for the shared wheel contract. `docs/qa-astra/model-audit.json` records triangles, bounds and hashes.

`vehicle-specs.json` provides driver transforms, collider dimensions, wheel radius and exhaust positions. `LeoKart.chassis_path`, `driver_path`, `vehicle_spec` and `seat_driver` are shared by garage and race. Add entries in `main.gd` and matching metadata to extend the system. Original vehicle/driver paths remain supported.

The circuit generator writes `assets/track-astra.json` plus its geometric audit. The original grid location and sampling/projection/checkpoint interface remain. `LeoAstraWorld` builds the new road ribbon and surrounding decorative terrain/water; its art profile is `assets/config/astra.tres`. Original `track.json` and world GLBs remain available. Lagoon footprints are excluded from city building placement. Terrain does not replace driving collision.

Three transparent generated PNGs live in `assets/art/astra/`, with exact prompts. `LeoAstraDecals` places seven alpha-painted meshes oriented with the route. Shared materials and mipmaps support Forward+ and Compatibility. Eight existing billboard campaigns now use shared unshaded HDR emission and luminous frames.

## Verify and export

Set `DOTNET_ROOT` to the pinned SDK and use the pinned Godot .NET console executable (`godot` below). `tools/run_godot.ps1` sets the portable environment. Diagnostic arguments avoid personal preference writes.

```powershell
godot --headless --path . --script tools/astra_vehicle_test.gd -- --drive-test
godot --headless --path . --script tools/astra_route_test.gd -- --drive-test
godot --headless --path . --script tests/astra_playability_test.gd -- --drive-test
godot --headless --path . --script tests/astra_fleet_race.gd -- --drive-test
godot --headless --path . --script tests/astra_drive_test.gd -- --drive-test
godot --headless --path . --script tests/astra_presentation_test.gd -- --drive-test
godot --path . --resolution 1920x1080 --script tests/astra_render_profile.gd -- --drive-test
godot --path . --resolution 1920x1080 --script tools/astra_capture.gd -- --drive-test
godot --headless --path . --export-release "Windows Desktop" "build/Astra/Leo Racer.exe"
python tools/package_astra.py
```

Packaging creates/tests the ZIP and extracts a fresh folder for independent checks. Keep its .NET data directory and native DLLs with the executable.
