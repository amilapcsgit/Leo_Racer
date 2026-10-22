# Leo Racer — Colombo 2026

A local Windows arcade kart racer set around a stylized Colombo coast, Fort streets, tropical gardens, and the Lotus Tower. **Version 1.7.0** adds vertical local split-screen racing, configurable player controls, named offline rankings and all six drivers seated inside both Dacias. Six drivers, sixteen vehicles, the garage and player-targeted Pause → Change Car remain available. The new gray Bigster Extreme uses the repaired Blender body, black panoramic roof, copper details and Tagasan wheels. The 1.9 km circuit retains Port City esses, harbor hairpin, lagoon causeway, sculpted dunes and garden hills.

![Bigster Extreme in the garage](docs/qa-bigster-replacement/garage.png)

## Play

Download **LeoRacer-Setup-1.7.0.exe** or extract the entire **LeoRacer-Windows-1.7.0-Local2Player.zip** folder, then run **Leo Racer Launcher.exe**. Keep the accompanying `.NET` data directory and Terrain3D DLL beside the executable. Neither Godot nor a .NET installation is required to play. [Downloads](https://github.com/amilapcsgit/Leo_Racer/releases/tag/v1.7.0).

Use **Play Compatibility Mode.cmd** if Vulkan is unavailable. Compatibility mode uses simpler effects. The previous Sri Lanka v1.3 and Colombo v1.2 branches/releases remain available for rollback.

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

Choose **2 PLAYER MODE** for P1 left / P2 right, two humans and four AI. Single-player retains five AI opponents. Both modes use three laps. Each human chooses a name, driver, vehicle and input device; the second human continues when the first finishes. Tap accelerate on the final countdown beat for a launch boost. Recharge nitro through drifting and by slipstreaming behind another moving racer. Hold drift through steering corrections, then release a charged drift for a mini-turbo; longer charges earn SUPER DRIFT. Eight boost pads reward a flowing racing line. Recovery preserves ordered checkpoints, and a kart stuck under throttle resets safely after three seconds. Six identities and sixteen vehicles share the catalog; both Dacias display the selected driver in a cabin-specific pose. Pause → Change Car retains race progress; changed races cannot set records.

**Reduced Motion** in Settings disables camera kicks, roll, shake, and recovery distortion while retaining useful visual feedback. Existing preferences are preserved. Named SQLite race/lap records are filtered by mode, performance class and optional vehicle. Old 1.6 bests are shown separately; DNF and modified races cannot enter new rankings.

**CONTROLS** saves per-player remapping and calibration for keyboard, Xbox-style controllers and raw joystick/wheel axes. Only one keyboard player is allowed; each pad or wheel belongs to one human. Identical controllers require owner confirmation. An assigned-device disconnect pauses both players until reassignment or retirement.

Standard vehicles and Duster: **165/198 km/h**; Bigster: **180/225 km/h**. Common acceleration **18 m/s²**, handling **1.0**. Bigster retains 130% game scale, corrected tire centers, electric boost and regeneration. Logitech Formula Force EX physical compatibility is unverified; wheel force feedback is not included.

## Develop

This is a **Godot 4.7.2 .NET** project using **GDScript gameplay** and C# presentation and offline SQLite bridges. Run `Setup Colombo.cmd -AssetArchives "C:\assets\AI"` with the original addon archives, then `Open Colombo in Godot.cmd`. Setup instructions and pinned dependency details are in [COLOMBO_SETUP.md](docs/COLOMBO_SETUP.md).

- [Astra build, model and circuit pipeline](docs/ASTRA_SETUP.md)
- [Art pipeline and asset provenance](docs/COLOMBO_ASSETS.md)
- [1.7 multiplayer validation and performance](docs/LOCAL2PLAYER_VALIDATION.md)
- [1.7 release notes](docs/RELEASE_NOTES.md)
- [Earlier Astra validation](docs/ASTRA_VALIDATION.md)
- [Supplied-asset conversion and setup](docs/SRILANKA_SETUP.md)
- [Visual comparison](docs/ASTRA_COMPARISON.md)
- [Rendered captures](docs/qa-astra/captures/capture-manifest.json)
- [Editable art profile](assets/config/astra.tres)
- [Blender conversion pipeline](blender/import_srilanka.py)

All 34 original model GLBs and the previous circuit remain in the repository. Astra uses a new route dataset and a separate decorative world builder, with flat road collision and continuous protective boundaries. Vehicle wheel animation and ordered checkpoint rules remain shared. Original Blender sources and metadata accompany the new vehicles.

## Dependencies and notices

Kenney's Racing Starter Kit and City Kit remain the foundation. Additions use Rokojori v0.6, Terrain3D v1.0.2, EZ Tree, Quaternius Standard CC0 foliage, and AmbientCG CC0 PBR maps. Third-party components retain their own licenses; see `licenses/` and the addon notices. Rokojori source is obtained separately under its Public Indie License and is not republished as a standalone toolkit.

Sonic-inspired and other character/kart meshes are the existing stylized Blender models. This is an independent project.

Astra original artwork and audio notices: [ASTRA_ASSETS.md](licenses/ASTRA_ASSETS.md). Road-paint generation prompts: `assets/art/astra/prompts.json`.
