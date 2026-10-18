# Leo Racer

A local, single-player Godot 4 arcade kart racer set on **Lotus Coast**, a stylized 758-metre Colombo circuit. Three laps, six racers, a seaside promenade, pastel Fort-inspired streets, Independence-inspired gardens and a custom Lotus Tower.

## Version 1.1 â€” city and motion update

The wheel glitch, mirrored track text and backward boost chevrons are fixed. Wheels now use separate steering and rolling pivots, follow actual travel, and animate smoothly between physics ticks. The camera follows the interpolated kart pose. The start arch has distinct readable front and rear faces; track captions are mounted on physical boards.

The supplied **Kenney City Kit Commercial 2.1** now dresses the circuit with 62 detailed buildings, 31 skyline towers, 50 storefront signs, cafes, balconies, awnings, tiled sidewalks, flowerbeds, festival flags and beach furniture. Shared geometry uses 87 MultiMesh batches. The coastline terrain has been corrected so the ocean remains visible beside the promenade.

A generated panoramic sky, warmer lighting, clearcoat paint, animated coastal surf, fading exhaust, drift sparks and subtle boost speed effects bring the game closer to the menu artwork. The procedural asphalt filters distant grain to reduce shimmer. Personal settings, selections and best times remain compatible.

See [the update report](docs/UPDATE_1_1.md), [city asset pipeline](docs/CITY_ASSETS.md) and [sky artwork prompt](docs/SKY_ART.md). Fresh gameplay views are in `docs/qa-v2/`.

## Play from source

Install Godot 4.7.2, import `project.godot`, and press F5 to run. All runtime assets are included. Install matching Windows export templates and use the Windows Desktop export preset to create a standalone build. Windows executables are not tracked in this source repository.

Choose **Let's Race** for the flagship Sonic-inspired blue kart, or **Garage & Racers** to independently combine four drivers with four kart bodies. Kart choices have distinct speed, acceleration and handling. A full race takes roughly 75â€“100 seconds depending on driving and boosts. After you finish, the remaining racers cross the line before results appear.

| Control | Keyboard | Controller |
|---|---|---|
| Accelerate | W / Up | RT |
| Brake, then reverse | S / Down | LT |
| Steer | A D / Left Right | Left stick |
| Drift | Space + steering | A + stick |
| Nitro | Left Shift, when meter is full | X |
| Recover | R | Y |
| Pause | Escape / P | Start |
| Hide race HUD | F8 | â€” |

Hold a drift until the cyan sparks charge, then release Space for a mini-turbo. Cyan chevrons on the road are boost pads. Braking cancels boost. Nitro replenishes over time and faster during a drift. Ordered checkpoints prevent cutting the circuit or driving backward to gain laps. Recovery returns you to the last validated checkpoint.

Settings, selected driver/kart and the best race time save in Godot's local user data directory, normally `%APPDATA%/Godot/app_userdata/Leo Racer/leo_racer.cfg`. Settings include volume, music and fullscreen. Automated tests do not write scores or selections.

## Edit

Import `project.godot` in Godot **4.7.2**. Install the matching standard Windows export templates to build an executable. All gameplay is GDScript, with no external runtime plugins.

* `scripts/main.gd`: scene assembly, game states, input, audio, camera and persistence.
* `scripts/kart.gd`: arcade movement, constrained barriers, drifting, boost, AI and ordered checkpoints.
* `scripts/circuit.gd`: shared arc-length centreline sampling and projection.
* `scripts/city.gd`: deterministic batched Kenney city streetscape and park/promenade dressing.
* `scripts/race_visuals.gd`: forward boost chevrons, mounted single-face signs and kart paint polish.
* `scripts/hud.gd`: menus, modular garage, HUD/minimap, pause, settings and results.
* `assets/models/`: optimized GLB exports with PBR materials and UVs.
* `blender/`: editable Blender files and reproducible asset scripts. This folder is excluded from Godot import.
* `foundation/kenney/`: the original MIT starter scripts and documentation for reference.
* `licenses/`: third-party notices and font licenses.

The controller extends Kenney's speed-sensitive steering, independent wheel motion, body lean and audio response. It uses `CharacterBody3D` with a chassis collision box, a floor collider and continuous mathematical track barriers, replacing the starter's rolling sphere. AI uses look-ahead steering along the same centreline as the track. Every racer must cross eight ordered gates per lap; the start gate plus three laps totals 25 crossings. This is a deliberately closed circuit without jumps or off-road shortcuts.

Driver scenes and chassis scenes are independent. Add a new entry to `ROSTER` or `KARTS` in `scripts/main.gd`, export a GLB from Blender, and keep the documented coordinate convention. Chassis wheel nodes are `wheel-front-left`, `wheel-front-right`, `wheel-back-left`, `wheel-back-right`. Their origins are at the axle centres. All meshes use metre scale, +Y up and forward along -Z in Godot.

## Rebuild assets and executable

From this project folder in PowerShell, with Blender 4.5 installed:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' --background --factory-startup --python blender/build_assets.py
godot --headless --editor --import --quit --path .
godot --headless --path . --export-release 'Windows Desktop'
```

The export preset uses standard Godot export templates. `blender/build_city.py` extracts the included CC0 city source archive automatically; `blender/import_city_car.py` uses `source_assets/rgsdev/Taxi.fbx`. Run either script with Blender's `--background --factory-startup --python` options. `blender/make_audio.py` regenerates original audio using Python's standard library. Exported GLB assets are already included; Blender is only required to change or regenerate them.

## Validation

The delivered project was imported by Godot, rendered locally and exercised through actual physics and input actions. The 1.1 update report records the verification results. Automated checks are in `tests/`. Screenshots in `docs/` are actual Godot renders. The menu background is generated illustration; the circuit and garage screenshots show the playable 3D assets.

The local v1 includes one circuit, four modular drivers, four kart bodies, five AI opponents, drifting, boost pads, rechargeable nitro, ordered laps, placement, a live minimap, countdown, finish classification, restart, pause, engine/skid/impact/boost audio, an original looping soundtrack and saved settings. It does not include online play, split-screen, weapons or a championship series. The visual treatment is stylized low-poly 3D; the supplied commercial-game images served as art direction.

## Asset sources

* [Kenney Racing Starter Kit](https://github.com/KenneyNL/Starter-Kit-Racing): MIT controller foundation; CC0 engine, skid and impact sounds and modular pit tents.
* Kenney City Kit Commercial 2.1, included in `source_assets/`: CC0 building, skyscraper, awning and parasol models, normalized and shaded through Blender. See `licenses/KENNEY_CITY_KIT_COMMERCIAL_CC0.txt`.
* [RGS_Dev Free Low Poly Vehicles Pack on Itch.io](https://rgsdev.itch.io/free-low-poly-vehicles-pack): CC0 parked Colombo taxis, imported and normalized through Blender.
* Custom Blender circuit, architecture, Lotus Tower, foliage, karts and drivers generated by `blender/build_assets.py`.
* Rajdhani Bold and Barlow Medium from [Google Fonts](https://github.com/google/fonts), under their included SIL Open Font Licenses.
* Original synthesized soundtrack and interface/boost sounds, generated by `blender/make_audio.py`.
* Main-menu illustration: built-in imagegen, saved at `assets/art/menu.png`. The exact generation prompt is in **docs/IMAGE_PROMPT.md**.
* Panoramic sky: built-in imagegen, saved at `assets/art/lotus_coast_sky.png`. The exact generation prompt is in **docs/SKY_ART.md**.

The Sonic-inspired flagship is a fan-themed local prototype; Sonic is associated with SEGA. No official game models, textures, logos or music were extracted. User reference images were used for visual direction and are not shipped as in-game assets. Original project code is available under `licenses/LeoRacer-MIT.txt`; third-party terms remain in their respective license files.

## Repository license

The repository retains its existing AGPL-3.0 license in `LICENSE`. Original project code also carries the MIT grant in `licenses/LeoRacer-MIT.txt`; third-party assets retain their included licenses.
