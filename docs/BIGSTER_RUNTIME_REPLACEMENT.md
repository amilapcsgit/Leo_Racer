# Bigster Extreme — Leo Racer 1.6

The runtime Bigster now uses the repaired Duster-derived v4 Blender master.
Gray paint, black roof, copper grille/mirrors, Tagasan wheels, revised fascias,
quarter glass and the closed panoramic roof are retained. The detailed master
is unchanged and remains a separate editable deliverable.

## Runtime asset

- Self-contained GLB: 4,940,972 bytes; 69,652 triangles; 23 mesh objects;
  19 portable PBR materials; no external textures or required extensions.
- Hidden mechanical detail and dense tyre tread are removed. Visible cabin
  and body are simplified and merged. Four wheels and stationary calipers
  remain separate. The game supplies one helmeted driver.
- Raw model: 4.569087 m long, 1.712023 m high, 2.702 m wheelbase.
  Authored mirror width is 2.042437 m; the 2.069 m reference width has not been
  enforced by stretching the supplied geometry.
- **Approved game size: 130%.** Uniform catalog normalization scales body,
  wheels and glass; driver fit and collision shape follow the same factor.
  In-game wheel radius is 0.4615 m. The raw GLB remains at metre scale.
- Wheel pivots are stored in **unscaled chassis-local coordinates**. Applying
  world-scaled coordinates here scales the pivot twice and produces orbital
  wheel motion. The four local origins are (±0.78, 0.355, ±1.351).
  Calipers steer with the front hubs and never inherit wheel spin. Rear tyre
  spark positions are transformed into the normalized vehicle space.
- Driving presets stay 180 / 225 km/h; acceleration, handling, regeneration
  and vehicle identity remain unchanged. Sunroof animation is omitted from
  the game derivative; the glass is closed.

## Verification

`qa-bigster-replacement/replacement.json` records independent GLB import,
material separation, bounds, 130% game scale, driver assembly, radius and pivot
checks. The final test also measures tyre geometry centers after forward,
reverse, stopped, left-steer, straight and right-steer combinations: **229
checks passed**. The catalog test covers all 96 driver/vehicle combinations.
Driving (11), presentation (24) and garage/pause acceptance (37) checks pass.
The mixed fleet completes three races covering all 16 vehicles.

Actual garage, front/rear/side, three-quarter, driver and race captures are in
`qa-bigster-replacement/`. Both Vulkan Forward+ and OpenGL Compatibility were
rendered on the RTX A1000. Existing engine/addon cleanup diagnostics at shutdown
are not runtime assertion failures; no new performance FPS claim is made from
this visual smoke test. Historical RC package/performance evidence remains
under `qa-bigster/` and must not be read as measurements of this new asset.

## Rebuild

The committed runtime GLB is the shipping input; CI validates and imports it.
`tools/prepare_bigster_assets.py` preserves this finished Bigster revision while
still preparing the other derivatives. To rebuild from the separate master:

```powershell
blender --background --python blender/export_bigster_runtime.py -- --master C:/path/to/bigster_extreme_gray.blend --output build/bigster-runtime
```

The script writes the derivative, report and editable simplified scene into
its output folder. Inspect it before replacing `assets/models/bigster/bigster.glb`.
Source hashes and the runtime palette counts are in `derivative-specs.json`.
The master SHA-256 is
`ee1b8969a4149628e3610df869072e10977510ca8c114b404cd21817af5ecaa5`.
