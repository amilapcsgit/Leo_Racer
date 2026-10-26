# Leo Racer 2.3.2 — Orbit Camera and Vehicle Features

[![Download latest Windows installer](https://img.shields.io/badge/Download-Latest_Windows_Installer-22a8cf?style=for-the-badge&logo=windows)](https://github.com/amilapcsgit/Leo_Racer/releases/latest/download/LeoRacer-Setup.exe)

[Latest release, portable build and checksums](https://github.com/amilapcsgit/Leo_Racer/releases/latest)

**New in 2.3.2:** automatic reverse camera, held Look Back, mouse/controller orbit, remappable headlights and vehicle actions, and Bigster's sliding sunroof. Bigster 1.2.1 has corrected red Y-shaped rear LEDs, a separate bumper reversing lamp, and working main headlights. Each local player keeps independent camera and vehicle states. See the [vehicle features and controls guide](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/VEHICLE_FEATURES.md).

The offline installer includes **Astra Lotus Coast, Colombo City Grand Prix and Kandy Lake Circuit**, 16 default cars and 32 additional cars. Choose **Complete** for everything, **Standard** for three tracks and 16 cars, or **Custom** to select tracks and additional cars. At least one track is required. Existing user-added cars, settings and records are preserved; modified files replaced during upgrade are backed up.

**Version 2.3.1** improves the 2.83 km Kandy Lake Circuit with a physical start arch, supported local signs, corrected flags, grounded Buddhist landmarks, a 360° daylight environment, distant mountain geometry, and baked landmark lighting. It also repairs corrupted loading punctuation. The release includes three tracks, 16 default cars, and 32 optional offline cars. See [Kandy implementation and verification](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/KANDY_231.md).

**Version 2.2.0** adds loose vehicle folders, automatic content discovery, the in-game vehicle workshop and a contributor track SDK. All sixteen shipped cars are visible under GameAssets/vehicles; the development profile uses only Bigster and Duster. See [modularity checks](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/MODULARITY_VALIDATION.md) and the [contributor SDK](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/sdk/README.md).

**Version 2.1.0** fills the 5.5 km Colombo circuit with complete modular buildings, coherent districts, a shaped coastline, lake shores and bright tropical midday lighting. Lotus Tower, Galle Face Green and custom landmarks remain, alongside the neon UI, all vehicles, multiplayer and existing rankings. See [visual improvements and validation](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/COLOMBO_VISUALS.md).

A local Windows arcade racer with six drivers, sixteen default vehicles, **Astra Lotus Coast** (1.9 km), **Colombo City Grand Prix** (5.5 km), and **Kandy Lake Circuit** (2.83 km). All three tracks support single player and vertical two-player split screen. Existing settings, vehicles, race rules, and offline rankings are retained.

![Colombo City in Leo Racer 2.1](https://raw.githubusercontent.com/amilapcsgit/Leo_Racer/v2.3.2/docs/qa-colombo-visuals/streets-final.jpg)

**New in 2.0:** a dimensional driver carousel, reactive neon buttons, animated car statistics, procedural sound cues, and alternating day/night loading artwork. See [implementation and validation](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/NEON_UI.md).

## Play

Use the **Download** button above for the latest **LeoRacer-Setup.exe**, or download **LeoRacer-2.3.2-win64.zip**, extract the entire folder and run **LeoRacer.exe**. Keep the complete folder together. Godot, a .NET installation, and an internet connection are not required to play. [Downloads and checksums](https://github.com/amilapcsgit/Leo_Racer/releases/latest).

Use **Play Compatibility.cmd** if Vulkan is unavailable. Compatibility mode uses simpler effects. Previous releases remain available for rollback.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate / brake / reverse | W / S or arrows | Triggers |
| Steer | A / D or arrows | Left stick |
| Drift | Space | A |
| Nitro | Shift | X |
| Recover | R | Y |
| Horn | H | B |
| Pause | Esc or P | Start |
| Hide HUD for photos | F8 | — |
| Headlights | L | D-pad left |
| Vehicle Action 1 (Bigster sunroof) | O | D-pad up |
| Vehicle Action 2 | K | D-pad down |
| Look Back (hold) | C | Right-stick click |
| Orbit camera | Right-mouse drag | Right stick |

Choose **Go Race → 2 Players → Start Race** for P1 left / P2 right, two humans and four AI. Single-player retains five AI opponents. Both modes use three laps. Each human chooses a name, driver, vehicle and input device; the second human continues when the first finishes. Tap accelerate on the final countdown beat for a launch boost. Recharge nitro through drifting and by slipstreaming behind another moving racer. Hold drift through steering corrections, then release a charged drift for a mini-turbo; longer charges earn SUPER DRIFT. Eight boost pads reward a flowing racing line. Recovery preserves ordered checkpoints, and a kart stuck under throttle resets safely after three seconds. Six identities and sixteen vehicles share the catalog; both Dacias display the selected driver in a cabin-specific pose. Pause → Change Car retains race progress; changed races cannot set records.

**Reduced Motion** in Settings disables camera kicks, roll, shake, and recovery distortion while retaining useful visual feedback. Existing preferences are preserved. Named SQLite race/lap records are filtered by mode, performance class and optional vehicle. Old 1.6 bests are shown separately; DNF and modified races cannot enter new rankings.

Race Setup → **Controls** saves per-player remapping and calibration for keyboard, Xbox-style controllers and raw joystick/wheel axes. Two players can share one keyboard using complementary WASD/arrow presets; each pad or wheel belongs to one human. Auto chooses the first available mapped controller, then keyboard. Identical controllers require owner confirmation. An assigned-device disconnect pauses both players until reassignment or retirement.

Standard vehicles and Duster: **165/198 km/h**; Bigster: **180/225 km/h**. Common acceleration **18 m/s²**, handling **1.0**. Bigster retains 130% game scale, corrected tire centers, electric boost and regeneration. Logitech Formula Force EX physical compatibility is unverified; wheel force feedback is not included.

## Develop

Source for this release is on branch **orbitcamera** and tag **v2.3.2**. Check out that branch or tag before following the build instructions.

The modular core requires one initial upgrade. After that, compatible vehicle and track folders can be replaced without exporting the executable. The default development profile contains Bigster and Duster; the full profile contains sixteen loose GLBs.

```powershell
./tools/check_modularity.ps1 -Integration
./tools/build_content.ps1 -Target core -Version 2.2.0
./tools/build_content.ps1 -Target vehicle -Id duster
./tools/build_content.ps1 -Target track -Id community_example
./tools/build_content.ps1 -Target distribution -Profile dev -Version 2.2.0
./tools/build_content.ps1 -Target sdk
```

Component builds produce ZIPs and checksums under `dist/content/`. Vehicle/track targets never invoke core export. Use Content → Vehicles to configure a dropped GLB, privately test it and save its portable folder. See [SDK requirements](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/sdk/README.md) before importing third-party models.


This is a **Godot 4.7.2 .NET** project using **GDScript gameplay** and C# presentation and offline SQLite bridges. Run `Setup Colombo.cmd -AssetArchives "C:\assets\AI"` with the original addon archives, then `Open Colombo in Godot.cmd`. Setup instructions and pinned dependency details are in [COLOMBO_SETUP.md](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/COLOMBO_SETUP.md).

- [Astra build, model and circuit pipeline](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/ASTRA_SETUP.md)
- [Art pipeline and asset provenance](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/COLOMBO_ASSETS.md)
- [1.7 multiplayer validation and performance](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/LOCAL2PLAYER_VALIDATION.md)
- [2.1 release notes](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/RELEASE_NOTES.md)
- [Earlier Astra validation](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/ASTRA_VALIDATION.md)
- [Supplied-asset conversion and setup](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/SRILANKA_SETUP.md)
- [Visual comparison](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/ASTRA_COMPARISON.md)
- [Rendered captures](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/docs/qa-astra/captures/capture-manifest.json)
- [Editable art profile](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/assets/config/astra.tres)
- [Blender conversion pipeline](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/blender/import_srilanka.py)

All 34 original model GLBs and the previous circuit remain in the repository. Astra uses a new route dataset and a separate decorative world builder, with flat road collision and continuous protective boundaries. Vehicle wheel animation and ordered checkpoint rules remain shared. Original Blender sources and metadata accompany the new vehicles.

## Dependencies and notices

Kenney's Racing Starter Kit and City Kit remain the foundation. Additions use Rokojori v0.6, Terrain3D v1.0.2, EZ Tree, Quaternius Standard CC0 foliage, and AmbientCG CC0 PBR maps. Third-party components retain their own licenses; see `licenses/` and the addon notices. Rokojori source is obtained separately under its Public Indie License and is not republished as a standalone toolkit.

Sonic-inspired and other character/kart meshes are the existing stylized Blender models. This is an independent project.

Astra original artwork and audio notices: [ASTRA_ASSETS.md](https://github.com/amilapcsgit/Leo_Racer/blob/v2.3.2/licenses/ASTRA_ASSETS.md). Road-paint generation prompts: `assets/art/astra/prompts.json`.
