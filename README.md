# Leo Racer — Colombo 2026

A local Windows arcade kart racer set around a stylized Colombo coast, Fort streets, tropical gardens, and the Lotus Tower. **Version 1.4.0 / branch `astra`** expands the circuit to 1.9 km with Port City esses, harbor hairpin, lagoon causeway, sculpted dunes and garden hills. Five drivers and nine vehicles include Shaven Leo, two Formula racers, Lion GT, Racing Tuk-Tuk and Party Bus. Luminous advertising, generated road paint, arcade audio, launch boosts and slipstream rewards bring the coast to life.

![Colombo gameplay](docs/qa-astra/captures/05-coast.png)

## Play

Extract the entire **LeoRacer-Windows-v1.4-Astra.zip** folder and run **Play Leo Racer.cmd** or **Leo Racer.exe**. Keep the accompanying `.NET` data directory and Terrain3D DLL beside the executable. Neither Godot nor a .NET installation is required to play.

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

Race three laps against five opponents. Tap accelerate on the final countdown beat for a launch boost. Recharge nitro through drifting and by slipstreaming behind another moving racer. Hold drift through steering corrections, then release a charged drift for a mini-turbo; longer charges earn SUPER DRIFT. Eight boost pads reward a flowing racing line. Recovery preserves ordered checkpoints, and a kart stuck under throttle resets safely after three seconds. All five drivers can drive all nine vehicles.

**Reduced Motion** in Settings disables camera kicks, roll, shake, and recovery distortion while retaining useful visual feedback. Existing preferences are preserved. Astra uses a separate best-time record for its longer route.

## Develop

This is a **Godot 4.7.2 .NET** project using **GDScript gameplay** and a small C# presentation bridge. Run `Setup Colombo.cmd -AssetArchives "C:\assets\AI"` with the original addon archives, then `Open Colombo in Godot.cmd`. Setup instructions and pinned dependency details are in [COLOMBO_SETUP.md](docs/COLOMBO_SETUP.md).

- [Astra build, model and circuit pipeline](docs/ASTRA_SETUP.md)
- [Art pipeline and asset provenance](docs/COLOMBO_ASSETS.md)
- [Validation and performance](docs/ASTRA_VALIDATION.md)
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
