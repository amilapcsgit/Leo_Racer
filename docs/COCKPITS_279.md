# Reviewed cockpit presentation — 2.7.9

Bigster, Duster 2024, and Duster My 2014 use their left-hand-drive seat positions. The 2014 Duster retains its own dashboard, analog gauges, steering wheel and fixed stalks. Its original speed/RPM needles are animated from vehicle telemetry; a fitted navigation display occupies the radio area. Bigster and Duster 2024 retain the shared modern interior, with the digital instruments arranged above the neutral horn pad. In-car instruments supplement the original race HUD.

## Coordinates and ownership

`assets/config/cockpit-profiles-v279.json` is reviewed core presentation data. It defines exact wheel nodes, the authored hub/shaft/rest transform, instrument bindings and display surfaces. Forward is **−Z**; the clearance offset is **+Z toward the driver**. Modern wheels have a 0.14 m offset; the 2014 wheel has 0.05 m. A single rigid pivot rotates each complete wheel through ±135°. Fixed stalks/dashboard meshes never join that pivot.

Camera eyes continue to use the existing `camera_views` interface in `assets/config/camera-views-v1.json`. No public vehicle format or physics change is required. Other unreviewed vehicles retain Chase/Ghost. Cockpit mirrors and screens belong to the local player; mirror cameras exclude mirror surfaces to prevent recursion. Visible mirrors target 30 Hz with frustum gating, staggered deadlines and interpolated camera poses; side views additionally require relevant head-look. Textures are 128 × 64 solo and 64 × 32 in split screen. See [the mirror report](MIRRORS_279.md) for behavior and rendered validation. Screen rendering is capped at 12.5 Hz; analog needles use the existing speed/RPM telemetry.

## Additive assets

`tools/build_cockpits279.py` copies each original GLB into the build directory and compiles an additive `content/ultra/cockpit279-{id}.pck` with a `res://cockpit279/{id}/model.scn` resource. Source hashes are checked before/after compilation. Original vehicle packages and source files remain unchanged. The compiler preserves wheel, needle, dashboard, stalk, ceiling/mirror, lighting and interaction bindings rather than merging them into static geometry.

The 2014 rear mirror binds to its authored glass material inside the ceiling mesh. Navigation and mirrors conform to actual source surfaces where available; the 2014 navigation screen uses a fitted bezel. Unshaded overlays contain only positions, indices and their own UVs, avoiding inherited custom-array format flags.

## Verification

Use the bundled Blender Python executable for the Python tools (it supplies NumPy), and `tools/run_godot.ps1` for Godot:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/4.5/python/bin/python.exe' tools/build_cockpits279.py
& ./tools/run_godot.ps1 --headless --script res://tools/check_cockpit279.gd --drive-test --geometry-only --qa-output=build/qa279/cockpit-geometry
& ./tools/run_godot.ps1 --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tools/check_cockpit279.gd --drive-test --qa-output=build/qa279/cockpit-compatibility
& ./tools/run_godot.ps1 --rendering-method forward_plus --script res://tools/check_cockpit279.gd --drive-test --qa-output=build/qa279/cockpit-forward
& 'C:/Program Files/Blender Foundation/Blender 4.5/4.5/python/bin/python.exe' tools/validate_cockpit_clearance279.py build/qa279/cockpit-forward --update-manifests
```

The native check captures complete cabins at −135°, −90°, −45°, 0°, +45°, +90° and +135°, plus the driver-eye/night views and live 120 km/h instruments. The fixed-magenta/rotating-cyan diagnostic preserves the surrounding cabin. It checks exact wheel bindings, steering response/return, independent 2014 needles and actual changed speed pixels in the rendered viewport textures.

The exported geometry includes runtime instrument/navigation surfaces. `validate_cockpit_clearance279.py` encloses the full continuous wheel rotation in conservative 2.5 mm radial bands. Exact projected triangle radial bounds and conservative axial bounds produce a lower bound on separation from every nearby fixed triangle, scaled by the minimum singular value of the model normalization. A result of at least **0.015 m** certifies the entire sweep, including angles between captures. An inconclusive lower bound fails; it is not called an intersection or silently ignored. No cabin geometry or shaft connection is exempted from the measurement.

Native Compatibility shutdown in the previous 2.7.8 baseline reported two 349,524-byte GL texture warnings. Keep shutdown diagnostics separate from functional/rendering errors; do not claim those pre-existing renderer warnings are resolved without a controlled passing run.
