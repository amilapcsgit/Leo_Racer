# Offline Sri Lankan Track Kit

Use `Track Kit.cmd` (or `trackkit.ps1 -Target edit-course`). Godot 4.7.2, native authoring plugins, Python and locked Earth2Road generator dependencies are included. Nothing installs or downloads at first launch. Internet is never required for the archived Kandy example.

Workflow: select the KandyAuthoring root in `kandy.tscn`. Use its five inspector buttons: Import Geography, Edit Course, Dress Scenery, Validate, Export. Edit the Route Path3D curve handles, then refresh Edit Course. Keep its closed curve and smooth grade transitions. Save your authoring scene under a different filename and set its track ID, display name, data folder and export destination. The CLI accepts `-Scene res://your_course.tscn`.

Equivalent targets:

```
Track Kit.cmd -Target import-geography
Track Kit.cmd -Target edit-course
Track Kit.cmd -Target dress-scenery
Track Kit.cmd -Target validate
Track Kit.cmd -Target export -Output exported
```

Import Geography validates a cached Earth2Road world, reads OSM lake/building geometry and archived DEM tiles. It preserves course.json if it already exists. The supplied adapter selects Kandy Lake; for another district, author its geography/course data separately using the same documented JSON structure. The editor and exporter work with a new ID/data folder without game source edits. Road Generator produces the actual road meshes and its Terrain3D connector is available under RoadAuthoring. TerrainAuthoring is hidden after baking; show it and hide Resident to sculpt. Save edited terrain regions to `data/<course>/authored-terrain`. Rebuild scenery to bake those regions. Imported geography, authored course and terrain corrections remain separate.

To regenerate the archived foundation itself, run locally (a NEW output folder is required):

```
author-python\python.exe -m akadem_maps build --config inputs/world/inputs/config.json --inputs inputs/world/inputs --offline --output rebuilt-world
author-python\python.exe -m akadem_maps validate --target world --input rebuilt-world
```

The source snapshot is Earth2Road fec38c79441585e5ff719dd37fa516db809eef9b, generator 0.1.0b1, world format 2; see licenses/earth2road/requirements.lock and dependency-hashes.json. Road Generator is 0.9.5; Terrain3D is 1.0.2. This kit does not import traffic or gameplay systems.

Exported folders contain API3 metadata, uniform 3D route samples, resident road/collision, 200 m detail cells, a deduplicated namespaced PCK, preview, provenance, checksums and licenses. The PCK has no GDScript, .NET or native extension. Static terrain has its own runtime shader; editor Terrain3D materials are not assumed to bake automatically. Required core: 2.3.0. Older API1/2 tracks still work. Custom content stays unranked.

Widths default to 18m; minimum 14m. Grade limit 6%, minimum vertical radius 1000m. Banking, jumps, tunnels and stacked roads are unsupported. Use the west-side grid, eight ordered recovery/checkpoint sectors and verify six racers. Do not put decorative collision in streamed cells. Both player cameras drive the existing streamer's demand set. Detailed authoring meshes/materials are shared; no complete city collection is repeated.

Copy only `exported/<id>` into LeoRacer/GameAssets/tracks, then refresh content. Keep `.bake-*`, authoring assets and the SDK outside the installed track folder. Replacing a compatible folder requires no executable export. Increment course revision for route changes. Existing official fingerprints cannot be self-declared by a manifest.

Map-derived data is ODbL, © OpenStreetMap contributors. The archived source and exported geography.json are provided for provenance and share-alike obligations. Source building authors remain credited in licenses/colombo-buildings.txt. Original Kandy material atlas generation prompt is in art/provenance.json. Noto Sinhala/Tamil fonts retain SIL OFL notices. Generated textures contain no lettering or Street View screenshots.

Keep hand-placed scenery under the root SceneryCorrections node: Dressing replaces only generated Details/Resident groups, and exports your correction nodes into the same streamed cells. Add polygon arrays under `exclude_buildings` in data/<course>/corrections.json to reserve authored parcels. Geography import never writes this file. The root Procedural Seed field is saved in bake provenance. Keep a saved authoring scene and increment course revision when moving the route.
