# Lotus Coast city upgrade

The city uses the included `source_assets/kenney_city-kit-commercial_2.1.zip`, Kenney City Kit Commercial 2.1, under CC0. The supplied license is preserved at `licenses/KENNEY_CITY_KIT_COMMERCIAL_CC0.txt`. The source archive is extracted to `source_assets/kenney-city/` when regenerated.

## Assets and materials

`blender/build_city.py` imports the source GLBs through Blender 4.5 and exports 22 normalized assets into `assets/models/city/`:

- Fourteen detailed commercial/shop/apartment buildings.
- Five windowed skyscraper designs.
- Two parasol designs and one awning module.

One source unit is scaled to ten metres. Exported model footprints sit at ground height with Godot +Y up. Kenney's storefront fronts face local -Z; `city.gd` rotates those toward the road while physical shop signs face local +Z. All instance transforms retain positive determinants.

The source palette UV shading is baked separately at each vertex corner. Broad stucco faces use a tintable `City_Wall` surface with a compressed brightness range; modeled frames, cornices and roof details retain cream or dark teal shading. Glass is a separate PBR surface. Sampling each UV corner preserves smooth source shading without diagonal triangle bands. Six shared wall materials supply coral, turquoise, mango, lavender, cream and rose variants. Geometry and materials are reused through MultiMesh batches.

## Streetscape

Create `LeoCity`, add it to the game world and call `setup(circuit)`. The deterministic layout has 62 detailed buildings, 31 skyline towers and 50 physical shop signs. Street dressing includes tiled sidewalks, striped shop awnings, outdoor cafes, parasols, benches, lanterns, flowering planters, broad tropical trees, festival bunting, a beach balustrade and beach umbrellas. These additions use roughly 6,500 prop instances in 87 MultiMesh batches, with small-prop shadows disabled. The racing road, curbs, original palms, Independence pavilion and Lotus garden remain.

Buildings are tested against the whole circuit and against other oriented building footprints. The nearest accepted building corner is 18.63 metres from the centerline, beyond the 9-metre road half-width and 11-metre barrier line. The western coastal view stays open. Original blank-faced generated buildings are removed from `blender/build_assets.py`.

The main terrain now ends at x=-119 and the beach occupies x=-145 to -119, allowing the ocean surface to remain visible beside the promenade.

## Rebuild and check

1. Run Blender with `--background --factory-startup --python LeoRacer/blender/build_city.py` from the parent workspace.
2. To regenerate the coastline without modifying karts, run Blender with `--background --factory-startup --python LeoRacer/blender/build_assets.py -- --world-only`.
3. Run Godot headless editor import, then `--headless --path LeoRacer --script res://tests/city_validation.gd`.
4. `tests/city_visual.gd` is an independent GPU art review scene. It saves four street views and an overview in `docs/city-review/`, which is excluded from resource imports. Its neutral QA lighting is separate from the game's sky and ocean.

Validation checks density, skyline presence, safe building clearance, batch count, and positive transforms for signs/instances. Visual QA also verifies the modeled doors and shop windows face the racing camera.
