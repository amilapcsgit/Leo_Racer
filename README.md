# Leo Racer — Colombo 2026

A local Windows arcade kart racer set around a stylized Colombo coast, Fort streets, tropical gardens, and the Lotus Tower. **Version 1.3.0 / branch `srilanka`** adds supplied textured palms, banana plants, an authentic Lotus Tower, Sri Lankan transport, national flags, eight generated racing campaigns, concrete boundaries, liquid nitro telemetry and speed feedback above 150 km/h.

![Colombo gameplay](docs/qa-srilanka/coast.png)

## Play

Extract the entire **LeoRacer-Windows-v1.3-SriLanka.zip** folder and run **Play Leo Racer.cmd** or **Leo Racer.exe**. Keep the accompanying `.NET` data directory and Terrain3D DLL beside the executable. Neither Godot nor a .NET installation is required to play.

Use **Play Compatibility Mode.cmd** if Vulkan is unavailable. Compatibility mode uses simpler effects. The previous Colombo v1.2 release remains available for rollback.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate / brake / reverse | W / S or arrows | Triggers |
| Steer | A / D or arrows | Left stick |
| Drift | Space | A |
| Nitro | Shift | X |
| Recover | R | Y |
| Pause | Esc or P | Start |
| Hide HUD for photos | F8 | — |

Race three laps against five opponents. Recharge nitro over time and by drifting; release a charged drift for a boost. Ordered checkpoints prevent skipped laps. Recovery preserves checkpoint progress. Four drivers and four karts remain independently selectable.

**Reduced Motion** in Settings disables camera kicks, roll, shake, and recovery distortion while retaining useful visual feedback. Existing audio preferences, selections, and best times are preserved.

## Develop

This is a **Godot 4.7.2 .NET** project using **GDScript gameplay** and a small C# presentation bridge. Run `Setup Colombo.cmd -AssetArchives "C:\assets\AI"` with the original addon archives, then `Open Colombo in Godot.cmd`. Setup instructions and pinned dependency details are in [COLOMBO_SETUP.md](docs/COLOMBO_SETUP.md).

- [Art pipeline and asset provenance](docs/COLOMBO_ASSETS.md)
- [Validation and performance](docs/SRILANKA_VALIDATION.md)
- [Supplied-asset conversion and setup](docs/SRILANKA_SETUP.md)
- [Before/after captures](docs/SRILANKA_COMPARISON.md)
- [Editable art profile](assets/config/srilanka.tres)
- [Blender conversion pipeline](blender/import_srilanka.py)

The layout, driving equations, wheel pivots, AI, checkpoint/lap rules, and all 34 original model GLBs are retained. A truncated published environment asset was restored from the exact working v1.1 source. New props and terrain are separate from the race collision.

## Dependencies and notices

Kenney's Racing Starter Kit and City Kit remain the foundation. Additions use Rokojori v0.6, Terrain3D v1.0.2, EZ Tree, Quaternius Standard CC0 foliage, and AmbientCG CC0 PBR maps. Third-party components retain their own licenses; see `licenses/` and the addon notices. Rokojori source is obtained separately under its Public Indie License and is not republished as a standalone toolkit.

Sonic-inspired and other character/kart meshes are the existing stylized Blender models. This is an independent project.
