# Colombo development setup

Windows x64 uses **Godot 4.7.2 .NET**, **.NET SDK 8.0.426**, and the matching .NET Windows export templates. The game remains GDScript; `RaceFeedbackBridge.cs` adapts Rokojori actions to presentation callbacks. Playing the exported ZIP requires neither the editor nor the SDK.

## First setup

Obtain these original archives from the linked publishers and place them in one folder:

| Archive | Publisher / license |
| --- | --- |
| `rokojori_action_library-v0.6.zip` | [Rokojori Action Library](https://store.godotengine.org/asset/rokojori/rokojori-action-library/), Public Indie License |
| `Terrain3D_v1.0.2-stable-2.zip` | [Terrain3D](https://store.godotengine.org/asset/tokisangames/terrain3d/), MIT |
| `addons.zip` | [EZ Tree Godot port](https://store.godotengine.org/asset/leomclaughlin4/ez-tree-godot-port/), MIT |

Run from the project directory:

```powershell
.\Setup Colombo.cmd -AssetArchives "C:\assets\AI"
```

The PowerShell setup verifies archive SHA-256 hashes, installs addons, downloads the pinned portable toolchain when needed, builds the solution, and imports the project. It requires no administrator installation. This workstation can also reuse the shared toolchain two directories above the checkout. `toolchain-lock.json`, `dependency-lock.json`, and `asset-lock.json` record inputs.

Terrain3D and EZ Tree are included under their existing licenses. Rokojori sources are ignored by Git and obtained separately. Its compiled code ships as part of the game under the [Public Indie License](https://rokojori.com/en/labs/rokojori-action-library/license).

The installer applies two integration fixes: Terrain3D's local `Baker` script alias becomes `Terrain3DBaker` to avoid the C# type collision, and EZ Tree paths match its actual directory case. Rokojori runtime actions are active; its optional editor toolbar plugin is disabled. Terrain3D and EZ Tree authoring plugins are enabled.

## Editing and exporting

- Open `Open Colombo in Godot.cmd` to use the .NET editor.
- Edit `assets/config/colombo.tres` and its `LeoArtProfile` defaults for lighting, city palette, landmark placement, and camera envelopes.
- Existing track JSON, wheel pivots, physics equations, AI, and core GLBs are preserved. New scenery is authored independently.
- Export the `Windows Desktop` preset. Templates live in ignored `.tools/templates/`; the resulting game goes in `build/Colombo/`.
- Distribute the **whole output folder**, including `data_LeoRacer_windows_x86_64` and the Terrain3D DLL. The EXE alone is insufficient for a .NET build.

## Rebuilding scenery

The checked-in GLBs and `.res` resources work without rebuilding. Blender 4.5.1 LTS was used for the custom props. To restore the eight CC0 Quaternius source models:

```powershell
python tools/import_nature_sources.py "C:\assets\AI\Stylized_Nature_MegaKitStandard.zip"
& "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" --background --python blender/build_colombo.py
```

`tools/bake_environment.gd`, run with the .NET Godot editor executable using `--headless --path . --script res://tools/bake_environment.gd`, regenerates Terrain3D coastal maps, square packed shore textures, and three EZ Tree meshes. Terrain is decorative and has collision disabled. Original AmbientCG maps and generated mipmap/import settings are included.

## Verification

Use `-- --drive-test` with diagnostic scripts to avoid reading or writing the personal settings profile. Run the wheel, driving, visual, and presentation scripts under `tests/`; `--smoke-test` and `--race-test` are built-in game arguments. `tests/capture_colombo.gd` records all screens and districts; `tests/render_profile.gd` measures a complete warmed-up race with six racers at the requested window resolution.

Settings retain the existing `leo_racer.cfg` format and add `display/reduced_motion=false`. No previous selections, audio preferences, or best times are reset.
