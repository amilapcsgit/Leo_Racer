# Installed content contract, API 1

`LeoRacer.exe` and `LeoRacer.pck` sit beside `GameAssets/catalog.json`, category packs and complete track folders. Keep the full installation together. Settings and SQLite rankings remain in the existing Godot user-data directory.

The catalog has `format: 1`, an engine compatibility version, `packs`, `assets` and `overrides`. Packs have stable IDs, relative file paths, byte sizes and SHA-256 content versions. The resolver validates them before mounting, loads selected models through background requests, coalesces duplicate requests and bounds its resource cache. The bootstrap displays animation before validation/loading; scene insertion and warm-up span multiple frames.

Register an optional cosmetic replacement in `overrides`, for example:

```json
{"id":"res://assets/models/colombo_city/building_00.glb","file":"glb/my-building.glb","affects_rules":false}
```

Use an **actual resource ID from the installed catalog**, retaining the intended units, origins, UVs and part arrangement. GLB scenes and PNG/SVG textures load at runtime. Overrides are confined to `GameAssets`; missing files produce a readable error. Mark rule-changing content with `affects_rules: true`. Visual overrides do not change collision or vehicle performance.

A compatible track is a folder under `GameAssets/tracks` containing a `manifest.json`, its route, preview and declared scenery packs. See either installed track for the complete current schema. A manifest supplies `format: 1`, `asset_api: 1`, stable `id`, `name`, positive `course_revision`, route filename, `world_kind`, lighting, resource paths, shared pack `dependencies`, and local `packs` with relative paths/checksums. City tracks also include a `cells.json` index and baked course/backdrop scenes. All resource paths inside a new scenery pack must be unique to that track. Common race geometry is driven by the route; scenery cell demand combines both human views.

The baked route provides length, points, local widths, sectors, boosts and optional grid features. Runtime projection drives AI, barriers, gate progress, recovery and minimaps. The course and essential collision stay loaded. Decorative cells stream independently. No editor plugin or live OSM request is required by the installed game.

Official route hashes are in the core rules registry. Unknown IDs, changed routes and changed rules cannot set official records. Rank queries include both track ID and revision; changing a course requires a new revision. A compatible visual track can be installed without an executable rebuild, but official record eligibility requires a reviewed rules-registry update.

Road Generator 0.9.5 is an MIT editor authoring dependency. Baked runtime resources contain no Road Generator scripts. Building attribution, source transformations, excluded assets and OSM licensing are recorded under `licenses/` and `docs/COLOMBO_CITY_PLAN.md`.
