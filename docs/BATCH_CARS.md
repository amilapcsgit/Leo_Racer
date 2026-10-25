# Local car-collection import

The batch adapter reuses the existing Workshop converter and texture optimizer.
It does not export the game, modify the core, load driver models or test seats.
User-supplied GLBs and generated content stay local under `build/batch-cars`.

## Recovery

Run `tools/batch_vehicles.py` using the bundled Python, with the input directory
passed through `--source`. Stages are `prepare`, `render`, `sheets`, `optimize`,
`textures`, `validate`, `install`, and `report`. Default output installation is
`build/CustomCars-dev/GameAssets/vehicles`; ordinary development keeps its
Bigster/Duster-only profile. `--only` selects a filename substring.

Each car has a source hash, parameter signature, progress file, logs and isolated
user cache. Completed conversions resume without repeating work. Corrective
orientation, scale, helper-mesh exclusions and guided wheel-region parameters
are stored in `build/batch-cars/profiles.json`. Changed parameters create a new
working revision; existing installed folders are protected.

The supplied collection has 31 GLBs (~465 MB). The first conversion checkpoint
prepares all 31. Two files require dropping non-triangle debug primitives, and
four require excluding supplied display floors/backdrops before normalization.
Original GLBs are untouched. Facing, optimization and final installation are
separate verification checkpoints; a prepared folder is not automatically
considered validated or installed.

Balanced authoring uses installed Blender 4.5, targets approximately 200,000
triangles, retains wheel/caliper node names and limits textures to 2048 pixels.
The original converted GLB is backed up outside the distributable folder before
simplification. DDS sidecars are produced with the existing editor-only texture
authoring tool; the game only reads them. No new runtime dependency is required.

All imported cars use Vehicle API 1, no visible driver, four rotating wheels,
front steering, static calipers and two blue rear boost emitters. They use the
standard custom performance class and remain modded/unranked. Unknown source
licenses are labelled as user-supplied personal imports; no redistribution rights
are invented and no supplied models are uploaded to GitHub.
