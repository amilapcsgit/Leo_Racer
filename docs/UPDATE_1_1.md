# Leo Racer 1.1

This update corrects wheel animation, sign orientation and boost markings, and expands the Colombo streetscape.

## Corrections

* **Tire wobble:** the original controller accumulated X rotation and then overwrote Euler Y for steering. Those rotations interacted as the wheel spun, visibly twisting the axle. Each imported wheel now has a steering pivot and a separate rolling pivot. A bounded scalar angle reconstructs the spin basis without accumulating drift. Wheel movement follows final signed displacement after collision and barrier correction, so pushing a wall no longer spins tires at the commanded speed.
* **Motion cadence:** physics interpolation is enabled. The camera follows `get_global_transform_interpolated()` with its own interpolation disabled, replacing mixed render-rate velocity prediction and raw physics poses. Wheel animation runs per rendered frame and resets after placement/recovery.
* **Mirrored/glitching signs:** labels are single-face, depth-tested and physically sized. The start arch has two separately oriented labels outside their respective beam faces. Giant unsupported track captions have been replaced by mounted boards.
* **Backward boost arrows:** each pad and chevron uses local -Z as forward, aligned with the sampled circuit tangent. Chevron centre tips lead their outer wings. Pads have a dark inset bed, yellow borders and pulsing cyan emission.

## Visual upgrade

Kenney City Kit Commercial 2.1 supplies modeled storefronts, windows, balconies, cornices and skyscrapers. Its palette shading is baked per UV corner, with a separately tintable stucco material. Storefronts face the road; signs face outward. The deterministic layout contains 62 detailed buildings, 31 skyline towers and 50 shop signs, with 6,484 shared scenery instances in 87 batches. The nearest building corner is 18.63 metres from the track centreline, outside the barriers.

Additional dressing includes cafes, parasols, awnings, benches, lanterns, tropical trees, flowerbeds, bunting, beach furniture and balustrade. The original terrain had covered the ocean; the grass and beach extents now expose the water beside the promenade.

The scene uses the generated `assets/art/lotus_coast_sky.png` panorama for its visible sky, ambient lighting and reflections. Warm directional lighting, bloom, clearcoat kart paint, animated surf, world-space exhaust trails, warm drift sparks and restrained screen-edge speed effects provide a brighter finish. Asphalt grain fades with pixel footprint to reduce distant shimmer.

## Verification

* `tests/wheel_test.gd`: 39 checks across all four chassis, including thousands of steer/spin frames, orthonormal axle bases, 30/60/144 FPS consistency, wall contact and reverse motion.
* `tests/drive_test.gd`: 11 driving checks, including acceleration, steering, braking, reverse, drift release, nitro, barriers, recovery, pause and restart.
* `tests/visual_regression.gd`: 22 checks for sign faces, start-beam placement, arrow direction, interpolation and city clearance.
* Full source and exported races verify three laps, all ordered gates and successful finishes by every opponent.
* GPU frame times are measured with `tests/render_profile.gd`; the final machine-specific measurements are in `qa-v2/render-profile.json`.

The old clip has repeated scene frames in its 30 FPS recording; that alone does not establish the original live game frame rate. The new profile measures actual rendered frame pacing on this PC with a 120 FPS cap and VSync disabled. Normal play retains the user's display synchronization.

Fresh in-engine views: `qa-v2/coast.png`, `fort.png`, `lotus.png`, `gardens.png`, `sign-back.png`, and `boost-forward.png`. The sky image and menu background are generated artwork; all city, track, vehicle and effect views are actual Godot renders.
