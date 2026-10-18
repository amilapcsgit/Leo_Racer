# Sri Lanka v1.3.0 source and conversion

Branch: `srilanka`, based on the completed `Colombo` release. Engine and dependency
setup remain pinned to Godot 4.7.2 .NET / SDK 8.0.426; see [COLOMBO_SETUP.md](COLOMBO_SETUP.md).
Run `Setup Colombo.cmd` once, then `Play Sri Lanka.cmd`, or open `project.godot`.
All optimized GLBs, materials and campaign PNGs are committed and ready to import;
Blender is required only to rebuild supplied assets.

Godot's [glTF texture importer](https://docs.godotengine.org/en/stable/classes/class_gltfstate.html)
extracts embedded images beside the new GLBs on first import. Those image copies
are ignored generated files; their complete source bytes are already embedded in
the committed GLBs. Keep the initial import running through its second texture pass.

## Offline source conversion

Install Blender 4.5.1 LTS. Put the supplied `game-assests` directory in
`%USERPROFILE%/Downloads/Leo Racer/`, or set `LEO_SRI_ASSETS` to its absolute path.
Use Python 3 for the preparation helper; it uses only the standard library and
Windows' bundled `tar` for RAR extraction. From the repository root:

```powershell
py tools/prepare_srilanka.py
$blender = 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe'
foreach ($stage in @('tower','tuk','street','banana','palms','bus')) {
    & $blender --background --factory-startup --python blender/import_srilanka.py -- $stage
}
& $blender --background --factory-startup --python tools/split_srilanka_world.py
```

Prepared archives live in ignored `.srilanka-inputs/`. The original downloads and
all 34 Colombo model GLBs are retained. The split world copies original vertex
buffers and removes only selected decorative index triangles; its road geometry
and track hashes are in `qa-srilanka/world-split.json`.

The converted tower is 132 metres tall. Palms have at most 25,000 near triangles
and approximately 4,200 distant triangles. Both tuk-tuk sources and the bus have
separate distant meshes. Source preview scenes, collision helpers and duplicate
plant LODs are not exported. Detailed banana textures are relinked from the
provided texture ZIP; palm maps are converted to PBR inputs and capped at 2K.

## Presentation tuning

`assets/config/srilanka.tres` selects the world, tower, exposure, fog, roughness,
foliage ranges and parked transport positions. It never controls driving physics.
The tower placement follows the approved target-image composition. Both concrete
boundaries retain the original soft collision limits. Curbs alternate every 0.5m.

All eight generated posters are under `assets/art/srilanka/`; exact prompts and
the built-in generation method are recorded in `prompts.json`. They appear on
80 correctly oriented advertising faces. National flags occupy 35 lamp anchors.
The liquid nitro shader reads actual fuel. Speed lines use measured travel speed,
start above 150 km/h and ramp through 180 km/h. Reduced Motion suppresses them.

## Build and rollback

Export the `Windows Desktop` preset to `build/SriLanka/Leo Racer.exe`, then run
`py tools/package_srilanka.py`. The complete runtime/data directory is required.
The previous `LeoRacer-Windows-v1.2-Colombo.zip` and GitHub `Colombo` branch are
retained for rollback. Current verification and caveats are in
[SRILANKA_VALIDATION.md](SRILANKA_VALIDATION.md).
